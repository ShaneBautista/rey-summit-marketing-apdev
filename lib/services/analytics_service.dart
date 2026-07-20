import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/order_model.dart';
import 'inventory_service.dart';
import 'order_service.dart';

/// Stats bundle for the admin Analytics screen, computed entirely from
/// the `orders` collection — the one collection every part of the app
/// (checkout, order history, delivery status updates) actually writes
/// to. See [computeSummary] for why this used to read from `sales` and
/// `deliveries` instead, and why that was a bug.
class AnalyticsSummary {
  final int totalOrders;
  final double totalSales; // renamed from "revenue" to match the `analytics` schema
  final int totalDeliveries;
  final int pendingDeliveries;
  final int totalCustomers;
  final int totalProducts;
  final Map<String, double> monthlySales;
  final Map<String, int> productCounts;

  const AnalyticsSummary({
    required this.totalOrders,
    required this.totalSales,
    required this.totalDeliveries,
    required this.pendingDeliveries,
    required this.totalCustomers,
    required this.totalProducts,
    required this.monthlySales,
    required this.productCounts,
  });

  // Aliases matching the field names your existing analytics_tab.dart
  // already calls, so that screen doesn't need to change.
  double get revenue => totalSales;
  int get deliveries => totalDeliveries;
  int get customerCount => totalCustomers;

  Map<String, dynamic> toSummaryMap() => {
        'totalSales': totalSales,
        'totalOrders': totalOrders,
        'totalDeliveries': totalDeliveries,
        'pendingDeliveries': pendingDeliveries,
        'totalCustomers': totalCustomers,
        'totalProducts': totalProducts,
      };
}

/// Computes admin-facing stats.
///
/// HOW THIS FEEDS FROM `orders`:
///  - totalOrders, monthlySales, productCounts, customer count -> every
///    non-cancelled order
///  - totalSales (Revenue) -> sum of `order.total` over every
///    non-cancelled order. This USED to sum a separate `sales`
///    collection instead, on the idea that a "sale" is only final once
///    a payment is separately recorded — but nothing in the app ever
///    calls SalesService.recordSale(), so that collection stays empty
///    forever and Revenue always showed ₱0 even with real orders. Until
///    something actually writes to `sales`, deriving revenue from
///    `orders` is the only way this number reflects reality.
///  - totalDeliveries (Deliveries) -> count of orders with
///    status == delivered. This USED to count docs in a separate
///    `deliveries` collection, which had the same problem: nothing
///    created a doc there unless you manually tapped "seed sample
///    data" on the old Deliveries tab. The Deliveries tab now updates
///    `status` directly on the order document, so counting it from
///    `orders` here keeps this number in sync with what that tab shows.
///  - totalProducts -> count of distinct SKUs in `inventory`. This USED
///    to query a separate `products` collection instead — but nothing
///    in the app ever calls ProductService.seedFromLocalCatalog() or
///    addProduct(), so that collection is always empty and this stat
///    always read 0 regardless of how many items you actually stock.
///    `inventory` is the collection every other screen (Dashboard,
///    Inventory tab, stock decrements from orders) already treats as
///    the real catalog, so counting distinct SKUs there is what
///    actually reflects your product count.
///
/// [computeSummary] still does the aggregation client-side, same as
/// before — fine at small scale. [pushSummaryToFirestore] additionally
/// writes the result into `analytics/summary`, so that collection has a
/// real cached document instead of staying empty, and other clients (or
/// a future Cloud Function) can read a pre-computed summary instead of
/// re-aggregating every collection on every screen load.
class AnalyticsService {
  final OrderService _orderService = OrderService();
  final InventoryService _inventoryService = InventoryService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const _monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  DocumentReference<Map<String, dynamic>> get _summaryDoc => _firestore.collection('analytics').doc('summary');

  Future<AnalyticsSummary> computeSummary({String? branchId}) async {
    // Each read is independent and swallows its own error — so if
    // Firestore security rules don't allow an `inventory` read yet, the
    // orders-derived stats (Total Orders, Revenue, Deliveries, Monthly
    // Sales, Popular Products, Customers) still render correctly instead
    // of the whole summary silently falling back to all-zero.
    final orders = await _safe(() => _orderService.fetchAllOrders(branchId: branchId), <OrderModel>[]);
    final productsCount = await _safe(
      () async => (await _inventoryService.fetchInventory(branchId: branchId)).map((i) => i.sku).toSet().length,
      0,
    );

    final monthlySales = <String, double>{};
    final productCounts = <String, int>{};
    final customerUids = <String>{};
    double totalSales = 0;

    for (final order in orders) {
      if (order.status == OrderStatus.cancelled) continue;
      if (order.uid.isNotEmpty) customerUids.add(order.uid);

      totalSales += order.total;

      final monthLabel = _monthNames[order.date.month - 1];
      monthlySales[monthLabel] = (monthlySales[monthLabel] ?? 0) + order.total;

      for (final item in order.items) {
        productCounts[item.name] = (productCounts[item.name] ?? 0) + item.quantity;
      }
    }

    final totalDeliveries = orders.where((o) => o.status == OrderStatus.delivered).length;
    // Orders that still need to go out: everything not yet delivered and
    // not cancelled (processing, shipped, or out for delivery). This is
    // the number that used to be missing from Analytics — "Deliveries"
    // only ever counted what was *already* delivered, with nothing
    // showing how many were still in the pipeline.
    final pendingDeliveries = orders
        .where((o) => o.status != OrderStatus.delivered && o.status != OrderStatus.cancelled)
        .length;

    final summary = AnalyticsSummary(
      totalOrders: orders.where((o) => o.status != OrderStatus.cancelled).length,
      totalSales: totalSales,
      totalDeliveries: totalDeliveries,
      pendingDeliveries: pendingDeliveries,
      totalCustomers: customerUids.length,
      totalProducts: productsCount,
      monthlySales: monthlySales,
      productCounts: productCounts,
    );

    // Caches this computed summary into `analytics/summary` — this is
    // what actually populates that collection, since nothing else in the
    // app writes to it. Fire-and-forget: the screen that called
    // computeSummary() already has its live numbers and shouldn't wait
    // on this secondary write.
    unawaited(pushSummaryToFirestore(summary).catchError((e) {
      // ignore: avoid_print
      print('AnalyticsService: failed to cache summary. $e');
    }));

    return summary;
  }

  /// Runs [action]; on any error (e.g. permission-denied because
  /// Firestore rules don't cover a new collection yet), logs it and
  /// returns [fallback] instead of letting it bubble up and cancel the
  /// rest of the summary.
  Future<T> _safe<T>(Future<T> Function() action, T fallback) async {
    try {
      return await action();
    } catch (e) {
      // ignore: avoid_print
      print('AnalyticsService: a collection read failed, using fallback. $e');
      return fallback;
    }
  }

  /// Call this after computeSummary() — e.g. on a "Refresh analytics"
  /// button, or after seeding sample data — to cache the result into
  /// `analytics/summary`. Purely a snapshot for other readers; the admin
  /// screens themselves should keep calling computeSummary() directly so
  /// they always show live numbers.
  Future<void> pushSummaryToFirestore(AnalyticsSummary summary) {
    return _summaryDoc.set(summary.toSummaryMap());
  }
}
