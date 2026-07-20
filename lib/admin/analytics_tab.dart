import 'package:flutter/material.dart';

import '../services/analytics_service.dart';
import '../services/order_service.dart';
import 'admin_colors.dart';
import 'widgets/donut_chart.dart';
import 'widgets/mini_line_chart.dart';
import 'widgets/stat_card.dart';

class AnalyticsTab extends StatefulWidget {
  const AnalyticsTab({super.key});

  @override
  State<AnalyticsTab> createState() => _AnalyticsTabState();
}

class _AnalyticsTabState extends State<AnalyticsTab> {
  final AnalyticsService _analyticsService = AnalyticsService();
  final OrderService _orderService = OrderService();
  late Future<AnalyticsSummary> _future;

  static const _monthOrder = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  static const _donutColors = [kAdminBlue, Color(0xFF6FA48C), Color(0xFFA8CFC0), kAdminGreen, kAdminAmber];

  @override
  void initState() {
    super.initState();
    _future = _analyticsService.computeSummary();
  }

  Future<void> _refresh() async {
    setState(() => _future = _analyticsService.computeSummary());
    await _future;
  }

  Future<void> _seedSampleOrders() async {
    final seeded = await _orderService.seedSampleOrders();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(seeded
            ? 'Added 5 months of sample orders — Monthly Sales should show a line now.'
            : 'Sample orders already exist — nothing to add.'),
      ),
    );
    if (seeded) await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: kAdminBlue,
      onRefresh: _refresh,
      child: FutureBuilder<AnalyticsSummary>(
        future: _future,
        builder: (context, snapshot) {
          final summary = snapshot.data;
          final sales = summary?.monthlySales ?? {};
          final labels = _monthOrder.where((m) => sales.containsKey(m)).toList();
          final values = labels.map((m) => sales[m]!).toList();
          final displayLabels = labels.isEmpty ? _monthOrder.sublist(0, 6) : labels;
          final displayValues = values.isEmpty ? List<double>.filled(6, 0) : values;

          final productEntries = (summary?.productCounts.entries.toList() ?? [])
            ..sort((a, b) => b.value.compareTo(a.value));
          final topProducts = productEntries.take(5).toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              Row(
                children: [
                  const Text('Analytics', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kAdminDarkBlue)),
                  const Spacer(),
                  IconButton(
                    onPressed: _seedSampleOrders,
                    icon: const Icon(Icons.cloud_upload_outlined, color: kAdminBlue),
                    tooltip: 'Seed sample orders (for Monthly Sales demo)',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.5,
                children: [
                  StatCard(
                    icon: Icons.inventory_2_outlined,
                    iconColor: kAdminBlue,
                    value: '${summary?.totalOrders ?? 0}',
                    label: 'Total Orders',
                    deltaLabel: '+12%',
                  ),
                  StatCard(
                    icon: Icons.attach_money,
                    iconColor: kAdminGreen,
                    value: '₱${_formatCompact(summary?.revenue ?? 0)}',
                    label: 'Revenue',
                    deltaLabel: '+18%',
                  ),
                  StatCard(
                    icon: Icons.local_shipping_outlined,
                    iconColor: kAdminBlue,
                    value: '${summary?.deliveries ?? 0}',
                    label: 'Delivered',
                    deltaLabel: '+9%',
                  ),
                  StatCard(
                    icon: Icons.pending_actions_outlined,
                    iconColor: kAdminAmber,
                    value: '${summary?.pendingDeliveries ?? 0}',
                    label: 'Awaiting Delivery',
                  ),
                  StatCard(
                    icon: Icons.people_outline,
                    iconColor: kAdminCardGrey,
                    value: '${summary?.customerCount ?? 0}',
                    label: 'Customers',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _SectionCard(
                title: 'Monthly Sales',
                trailing: const Icon(Icons.trending_up, color: kAdminGreen, size: 20),
                child: MiniLineChart(labels: displayLabels, values: displayValues),
              ),
              const SizedBox(height: 16),
              _SectionCard(
                title: 'Popular Products',
                child: topProducts.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('No orders yet — place a test order to see this fill in.',
                            style: TextStyle(color: kAdminCardGrey)),
                      )
                    : DonutChart(
                        slices: List.generate(
                          topProducts.length,
                          (i) => DonutSlice(
                            label: topProducts[i].key,
                            value: topProducts[i].value.toDouble(),
                            color: _donutColors[i % _donutColors.length],
                          ),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatCompact(double value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(0)}K';
    return value.toStringAsFixed(0);
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;
  const _SectionCard({required this.title, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: kAdminShadow, blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kAdminDarkBlue)),
              ?trailing,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
