import '../models/order_model.dart';
import 'order_service.dart';

/// Simple stats bundle for the admin Dashboard/Analytics screens.
class AnalyticsSummary {
  final int totalOrders;
  final double revenue;
  final int deliveries; // orders marked delivered
  final int customerCount; // distinct customers who've ordered
  final Map<String, double> monthlySales; // "Jan" -> total ₱ that month
  final Map<String, int> productCounts; // product name -> units sold

  const AnalyticsSummary({
    required this.totalOrders,
    required this.revenue,
    required this.deliveries,
    required this.customerCount,
    required this.monthlySales,
    required this.productCounts,
  });
}

/// Computes admin-facing stats by aggregating the SAME `orders` documents
/// that customers create at checkout (via OrderService.placeOrder). There's
/// no separate "analytics" data source — this is just math over real orders.
///
/// This does the aggregation client-side for simplicity. At real scale
/// you'd move this into a Cloud Function that maintains running totals
/// (e.g. incrementing a `stats/summary` doc on every order write) instead
/// of re-reading every order on every dashboard load — but reading it
/// straight from `orders` is the correct starting point and is exactly
/// how the numbers stay truthful to what customers actually ordered.
class AnalyticsService {
  final OrderService _orderService = OrderService();

  static const _monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  Future<AnalyticsSummary> computeSummary({String? branchId}) async {
    final orders = await _orderService.fetchAllOrders(branchId: branchId);

    double revenue = 0;
    int deliveries = 0;
    final monthlySales = <String, double>{};
    final productCounts = <String, int>{};
    final customerUids = <String>{};

    for (final order in orders) {
      if (order.status == OrderStatus.cancelled) continue;

      revenue += order.total;
      if (order.status == OrderStatus.delivered) deliveries++;
      if (order.uid.isNotEmpty) customerUids.add(order.uid);

      final monthLabel = _monthNames[order.date.month - 1];
      monthlySales[monthLabel] = (monthlySales[monthLabel] ?? 0) + order.total;

      for (final item in order.items) {
        productCounts[item.name] = (productCounts[item.name] ?? 0) + item.quantity;
      }
    }

    return AnalyticsSummary(
      totalOrders: orders.where((o) => o.status != OrderStatus.cancelled).length,
      revenue: revenue,
      deliveries: deliveries,
      customerCount: customerUids.length,
      monthlySales: monthlySales,
      productCounts: productCounts,
    );
  }
}
