import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/order_model.dart';
import '../models/product_model.dart';
import 'inventory_service.dart';
import 'sales_service.dart';

/// This is the bridge between the customer app and the admin app.
///
/// Both sides read/write the SAME Firestore collection, `orders`:
///   - Customers call [placeOrder] when they check out — this writes one
///     document per order with the items, total, branch, and starting
///     status ("processing").
///   - The customer's Order History screen calls [fetchMyOrders], which
///     filters that same collection down to `where('uid', isEqualTo: ...)`.
///   - The ADMIN app's Dashboard/Analytics screens query the exact same
///     `orders` collection with no uid filter (or filtered by branchId
///     instead) — so "Total Orders", "Revenue", and "Monthly Sales" are
///     just aggregations over the documents customers create here.
///   - When an employee updates an order's status (e.g. marks it
///     "delivered"), they write back to the same document — which is why
///     [fetchMyOrders] on the customer side will show that status change
///     next time it reads.
///
/// No separate sync step is needed — it's the same collection, read two
/// different ways depending on who's asking.
class OrderService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final InventoryService _inventoryService = InventoryService();
  final SalesService _salesService = SalesService();

  CollectionReference<Map<String, dynamic>> get _orders => _firestore.collection('orders');

  /// Called from the Cart page's checkout/order-confirmation flow. Writes
  /// one order document containing every item currently in the cart, each
  /// with its own quantity from the +/- stepper, then decrements stock in
  /// the `inventory` collection to match.
  Future<void> placeOrder({
    required List<CartItem> items,
    required String branchId,
    required String branchName,
    String? recipientName,
    String? deliveryAddress,
    String? paymentMethod,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('You must be signed in to place an order.');

    final total = items.fold<double>(0, (acc, item) => acc + item.lineTotal);

    // Firestore doesn't store custom classes directly — each cart item is
    // turned into a plain map here, keyed by the same SKU the admin's
    // Inventory screen uses, so stock levels can be decremented by SKU
    // when an order comes in.
    final itemMaps = items
        .map((c) => {
              'sku': c.product.sku,
              'name': c.product.name,
              'price': c.product.price,
              'qty': c.quantity,
            })
        .toList();

    final docRef = await _orders.add({
      'uid': uid,
      'branchId': branchId,
      'branchName': branchName,
      'items': itemMaps,
      'total': total,
      'status': OrderStatus.processing.name,
      'date': FieldValue.serverTimestamp(),
      if (recipientName != null && recipientName.isNotEmpty) 'recipientName': recipientName,
      if (deliveryAddress != null && deliveryAddress.isNotEmpty) 'deliveryAddress': deliveryAddress,
      if (paymentMethod != null && paymentMethod.isNotEmpty) 'paymentMethod': paymentMethod,
    });

    // Mirrors this order into the `sales` collection — the finance-facing
    // record SalesService/AnalyticsService expect. Considered final at
    // checkout (not e.g. delayed until "delivered"); wrapped in try/catch
    // so a `sales` write hiccup never blocks an order that already went
    // through, same pattern as the stock decrement below.
    try {
      await _salesService.recordSale(
        orderId: docRef.id,
        amount: total,
        paymentMethod: (paymentMethod != null && paymentMethod.isNotEmpty) ? paymentMethod : 'Cash on Delivery',
      );
    } catch (_) {
      // Non-fatal — the order itself already went through.
    }

    // Decrement stock for each item ordered. This is done client-side for
    // simplicity (a Cloud Function trigger on order creation would be the
    // safer place in production, so stock can't be bypassed by a client
    // skipping this call) — wrapped in try/catch so a stock-update hiccup
    // never blocks an order that already succeeded. Note this only finds
    // a match if the `inventory` collection has real Firestore documents
    // for these SKU/branch combos — see InventoryService.seedSampleInventory
    // if the admin Inventory screen is still only showing fallback sample
    // data (that data doesn't exist in Firestore yet, so there'd be
    // nothing here to decrement).
    for (final item in items) {
      try {
        await _inventoryService.decrementStock(
          sku: item.product.sku,
          branchId: branchId,
          by: item.quantity,
        );
      } catch (_) {
        // Non-fatal — the order itself already went through.
      }
    }
  }

  /// Order History screen (customer side) — only this user's orders.
  ///
  /// Sorted client-side rather than with a server-side `orderBy` chained
  /// after the `where('uid', ...)` filter — that combination needs a
  /// composite Firestore index, and until that index exists the query
  /// throws, which is a common reason a customer's own orders silently
  /// fail to appear. Sorting here avoids needing that index at all.
  Future<List<OrderModel>> fetchMyOrders() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return [];

    final snap = await _orders.where('uid', isEqualTo: uid).get();
    final orders = snap.docs.map((d) => OrderModel.fromMap(d.id, d.data())).toList();
    orders.sort((a, b) => b.date.compareTo(a.date));
    return orders;
  }

  /// Realtime version of [fetchMyOrders].
  ///
  /// The Order History tab lives inside an `IndexedStack` on the home
  /// screen (see home_dashboard_page.dart), which keeps its State alive
  /// across tab switches. A one-shot `Future` fetched in `initState` only
  /// ever runs once — placing a new order afterwards never shows up until
  /// the app restarts or the user manually pulls to refresh, because that
  /// State is never recreated. `snapshots()` fixes this at the source: it
  /// stays subscribed and pushes every new/changed document (including
  /// the one [placeOrder] just wrote) with no manual refresh needed.
  Stream<List<OrderModel>> streamMyOrders() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value([]);

    return _orders.where('uid', isEqualTo: uid).snapshots().map((snap) {
      final orders = snap.docs.map((d) => OrderModel.fromMap(d.id, d.data())).toList();
      orders.sort((a, b) => b.date.compareTo(a.date));
      return orders;
    });
  }

  /// Admin side — every order across all customers, optionally filtered to
  /// one branch. Used by the admin Dashboard/Analytics/Inventory screens.
  /// Same client-side sort as [fetchMyOrders], for the same reason.
  Future<List<OrderModel>> fetchAllOrders({String? branchId}) async {
    Query<Map<String, dynamic>> query = _orders;
    if (branchId != null) {
      query = query.where('branchId', isEqualTo: branchId);
    }
    final snap = await query.get();
    final orders = snap.docs.map((d) => OrderModel.fromMap(d.id, d.data())).toList();
    orders.sort((a, b) => b.date.compareTo(a.date));
    return orders;
  }

  /// Realtime version of [fetchAllOrders] — the admin Deliveries tab uses
  /// this so a newly-placed order (or a status change made from another
  /// device) shows up immediately with no manual refresh.
  Stream<List<OrderModel>> streamAllOrders({String? branchId}) {
    Query<Map<String, dynamic>> query = _orders;
    if (branchId != null) {
      query = query.where('branchId', isEqualTo: branchId);
    }
    return query.snapshots().map((snap) {
      final orders = snap.docs.map((d) => OrderModel.fromMap(d.id, d.data())).toList();
      orders.sort((a, b) => b.date.compareTo(a.date));
      return orders;
    });
  }

  /// Admin marking an order's status (Processing -> Shipped -> ... ).
  /// Writing here is what the customer's Order History will see on its
  /// next fetch — that's the whole "employee updates it, customer sees it"
  /// loop.
  Future<void> updateOrderStatus(String orderId, OrderStatus status) {
    return _orders.doc(orderId).update({'status': status.name});
  }

  /// Writes demo orders backdated across the last 6 months, purely so the
  /// Analytics "Monthly Sales" line chart has more than one point to plot.
  ///
  /// [AnalyticsService.computeSummary] groups every real order by the
  /// month in `order.date` — with only today's test orders in Firestore,
  /// that's a single month, which renders as one dot instead of a line.
  /// These seeded orders use a real Firestore `Timestamp` (not
  /// `FieldValue.serverTimestamp()`, which always resolves to "now") so
  /// each one lands in a different past month. Marked with
  /// `isSampleData: true` so they're easy to tell apart from real orders
  /// later if you want to clear them out. Safe to tap more than once —
  /// no-ops if sample orders already exist.
  Future<bool> seedSampleOrders() async {
    final existing = await _orders.where('isSampleData', isEqualTo: true).limit(1).get();
    if (existing.docs.isNotEmpty) return false;

    final uid = _auth.currentUser?.uid ?? 'sample-customer';
    final now = DateTime.now();
    final sampleMonths = [
      (monthsAgo: 5, total: 4200.0, branchName: 'Main Branch', branchId: 'main'),
      (monthsAgo: 4, total: 5600.0, branchName: 'North Branch', branchId: 'north'),
      (monthsAgo: 3, total: 3800.0, branchName: 'Main Branch', branchId: 'main'),
      (monthsAgo: 2, total: 7100.0, branchName: 'North Branch', branchId: 'north'),
      (monthsAgo: 1, total: 6300.0, branchName: 'Main Branch', branchId: 'main'),
    ];

    final batch = _firestore.batch();
    for (final m in sampleMonths) {
      final date = DateTime(now.year, now.month - m.monthsAgo, 15);
      batch.set(_orders.doc(), {
        'uid': uid,
        'branchId': m.branchId,
        'branchName': m.branchName,
        'items': [
          {'sku': 'ITM-002', 'name': 'Ice Tube – Medium', 'price': 65, 'qty': (m.total / 65).round()},
        ],
        'total': m.total,
        'status': OrderStatus.delivered.name,
        'date': Timestamp.fromDate(date),
        'isSampleData': true,
      });
    }
    await batch.commit();
    return true;
  }
}
