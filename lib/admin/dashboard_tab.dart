import 'package:flutter/material.dart';

import '../models/inventory_item_model.dart';
import '../services/analytics_service.dart';
import '../services/inventory_service.dart';
import 'admin_colors.dart';
import 'widgets/mini_line_chart.dart';
import 'widgets/stat_card.dart';

class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  final InventoryService _inventoryService = InventoryService();
  final AnalyticsService _analyticsService = AnalyticsService();

  late Future<List<InventoryItem>> _inventoryFuture;
  late Future<AnalyticsSummary> _summaryFuture;

  @override
  void initState() {
    super.initState();
    _inventoryFuture = _inventoryService.fetchInventory();
    _summaryFuture = _analyticsService.computeSummary();
  }

  Future<void> _refresh() async {
    setState(() {
      _inventoryFuture = _inventoryService.fetchInventory();
      _summaryFuture = _analyticsService.computeSummary();
    });
    await Future.wait([_inventoryFuture, _summaryFuture]);
  }

  static const _monthOrder = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: kAdminBlue,
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [kAdminBlue, Color(0xFF3D7A68)]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text('INVENTORY DASHBOARD',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 0.5, fontSize: 13)),
          ),
          const SizedBox(height: 16),
          FutureBuilder<List<InventoryItem>>(
            future: _inventoryFuture,
            builder: (context, snapshot) {
              final items = snapshot.data ?? [];
              final totalStock = items.fold<int>(0, (sum, i) => sum + i.qty);
              final lowStock = items.where((i) => i.status == StockStatus.lowStock).length;
              final outOfStock = items.where((i) => i.status == StockStatus.outOfStock).length;
              final totalProducts = items.map((i) => i.sku).toSet().length;

              return GridView.count(
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
                    value: '$totalStock',
                    label: 'Total Stock\nunits',
                  ),
                  StatCard(
                    icon: Icons.warning_amber_rounded,
                    iconColor: kAdminAmber,
                    value: '$lowStock',
                    label: 'Low Stock\nitems',
                  ),
                  StatCard(
                    icon: Icons.error_outline,
                    iconColor: kAdminRed,
                    value: '$outOfStock',
                    label: 'Out of Stock\nitems',
                  ),
                  StatCard(
                    icon: Icons.category_outlined,
                    iconColor: kAdminGreen,
                    value: '$totalProducts',
                    label: 'Total Products\nSKUs',
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          _SectionCard(
            title: 'Recent Stock Activity',
            child: FutureBuilder<List<InventoryItem>>(
              future: _inventoryFuture,
              builder: (context, snapshot) {
                final items = (snapshot.data ?? [])..sort((a, b) => b.restocked.compareTo(a.restocked));
                if (items.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('No stock activity yet.', style: TextStyle(color: kAdminCardGrey)),
                  );
                }
                return Column(
                  children: items.take(3).map((item) => _StockActivityRow(item: item)).toList(),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Monthly Sales',
            child: FutureBuilder<AnalyticsSummary>(
              future: _summaryFuture,
              builder: (context, snapshot) {
                final sales = snapshot.data?.monthlySales ?? {};
                final labels = _monthOrder.where((m) => sales.containsKey(m)).toList();
                final values = labels.map((m) => sales[m]!).toList();
                // Fall back to a friendly empty chart if there's no order
                // data in Firestore yet, so the dashboard isn't blank on a
                // fresh project.
                final displayLabels = labels.isEmpty ? _monthOrder.sublist(0, 6) : labels;
                final displayValues = values.isEmpty ? List<double>.filled(6, 0) : values;
                return MiniLineChart(labels: displayLabels, values: displayValues);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

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
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kAdminDarkBlue)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _StockActivityRow extends StatelessWidget {
  final InventoryItem item;
  const _StockActivityRow({required this.item});

  Color get _statusColor {
    switch (item.status) {
      case StockStatus.inStock:
        return kAdminGreen;
      case StockStatus.lowStock:
        return kAdminAmber;
      case StockStatus.outOfStock:
        return kAdminRed;
    }
  }

  String _formatDate(DateTime d) {
    return '${d.month}/${d.day}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(color: kAdminBlue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.inventory_2_outlined, color: kAdminBlue, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600, color: kAdminDarkBlue, fontSize: 13)),
                Text('${item.branchName} · ${_formatDate(item.restocked)}',
                    style: const TextStyle(color: kAdminCardGrey, fontSize: 11)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${item.qty}', style: const TextStyle(fontWeight: FontWeight.bold, color: kAdminDarkBlue)),
              Container(
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: _statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                child: Text(item.status.label, style: TextStyle(fontSize: 10, color: _statusColor, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
