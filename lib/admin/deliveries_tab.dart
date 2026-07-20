import 'package:flutter/material.dart';

import '../models/order_model.dart';
import '../services/order_service.dart';
import '../services/delivery_service.dart';
import 'admin_colors.dart';

/// Admin "Deliveries" screen.
///
/// Reads straight from the same `orders` collection every other part of
/// the app uses (see OrderService's class doc) — so every order a
/// customer places shows up here immediately, with no separate
/// "deliveries" record to create or seed first. Tapping the status pill
/// on a card lets the admin set that order's status directly to any
/// stage: Processing, Shipped, Out for delivery, Delivered, or
/// Cancelled. Because it's the same `orders` document the customer's
/// Order History screen reads, a status change made here shows up there
/// right away too.
class DeliveriesTab extends StatefulWidget {
  const DeliveriesTab({super.key});

  @override
  State<DeliveriesTab> createState() => _DeliveriesTabState();
}

class _DeliveriesTabState extends State<DeliveriesTab> {
  final OrderService _orderService = OrderService();
  final DeliveryService _deliveryService = DeliveryService();
  late Stream<List<OrderModel>> _ordersStream;

  String _statusFilter = 'All Status';

  @override
  void initState() {
    super.initState();
    _ordersStream = _orderService.streamAllOrders();
  }

  Future<void> _seedSampleOrders() async {
    final created = await _orderService.seedSampleOrders();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(created
            ? 'Added sample orders you can practice updating.'
            : 'Sample orders already exist — nothing new to add.'),
      ),
    );
  }

  Future<void> _setStatus(OrderModel order, OrderStatus status) async {
    if (status == order.status) return;
    try {
      await _orderService.updateOrderStatus(order.id, status);
      // Mirrors the change into `deliveries` too — this is what actually
      // populates that collection, since nothing else in the app writes
      // to it. Kept non-fatal: the order's own status already updated
      // successfully even if this secondary write hiccups.
      try {
        await _deliveryService.syncFromOrderStatus(order.id, status);
      } catch (_) {}
      // No manual refresh — streamAllOrders() picks up the write.
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update order: $e')),
      );
    }
  }

  List<OrderModel> _applyFilter(List<OrderModel> orders) {
    if (_statusFilter == 'All Status') return orders;
    return orders.where((o) => o.status.label == _statusFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<OrderModel>>(
      stream: _ordersStream,
      builder: (context, snapshot) {
        final all = snapshot.data ?? [];
        final filtered = _applyFilter(all);
        final outCount = all.where((o) => o.status == OrderStatus.outForDelivery).length;
        // Everything not yet delivered/cancelled — processing, shipped, or
        // out for delivery — so the admin can see the full backlog still
        // waiting to go out, not just the ones currently en route.
        final pendingCount = all
            .where((o) => o.status != OrderStatus.delivered && o.status != OrderStatus.cancelled)
            .length;

        return RefreshIndicator(
          color: kAdminBlue,
          onRefresh: () async {
            setState(() => _ordersStream = _orderService.streamAllOrders());
            await _ordersStream.first;
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              Row(
                children: [
                  const Text('Deliveries',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kAdminDarkBlue)),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Seed sample orders',
                    onPressed: _seedSampleOrders,
                    icon: const Icon(Icons.cloud_download_outlined, color: kAdminBlue),
                  ),
                  IconButton(
                    onPressed: () => setState(() => _ordersStream = _orderService.streamAllOrders()),
                    icon: const Icon(Icons.refresh, color: kAdminBlue),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              if (pendingCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                      color: kAdminAmber.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      const Icon(Icons.pending_actions_outlined, color: kAdminAmber, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('$pendingCount order${pendingCount == 1 ? '' : 's'} still need to be delivered',
                            style: const TextStyle(color: kAdminAmber, fontWeight: FontWeight.w600, fontSize: 13)),
                      ),
                    ],
                  ),
                ),
              if (pendingCount > 0) const SizedBox(height: 8),
              if (outCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                      color: kAdminBlue.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      const Icon(Icons.local_shipping_outlined, color: kAdminBlue, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('$outCount out for delivery right now',
                            style: const TextStyle(color: kAdminBlue, fontWeight: FontWeight.w600, fontSize: 13)),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              _FilterDropdown(
                value: _statusFilter,
                options: const [
                  'All Status',
                  'Processing',
                  'Shipped',
                  'Out for delivery',
                  'Delivered',
                  'Cancelled',
                ],
                onChanged: (v) => setState(() => _statusFilter = v!),
              ),
              const SizedBox(height: 16),
              Text('Deliveries (${filtered.length})',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: kAdminDarkBlue, fontSize: 14)),
              const SizedBox(height: 10),
              if (filtered.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                        all.isEmpty
                            ? 'No orders yet. Tap the download icon above to seed sample orders,\nor place one from the customer app.'
                            : 'No orders match this filter.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: kAdminCardGrey)),
                  ),
                )
              else
                ...filtered.map((o) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _OrderDeliveryCard(
                        order: o,
                        onSetStatus: (status) => _setStatus(o, status),
                      ),
                    )),
            ],
          ),
        );
      },
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  final String value;
  final List<String> options;
  final ValueChanged<String?> onChanged;
  const _FilterDropdown({required this.value, required this.options, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kAdminBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: options.contains(value) ? value : options.first,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, color: kAdminCardGrey, size: 18),
          style: const TextStyle(color: kAdminDarkBlue, fontSize: 13),
          items: options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _OrderDeliveryCard extends StatelessWidget {
  final OrderModel order;
  final ValueChanged<OrderStatus> onSetStatus;
  const _OrderDeliveryCard({required this.order, required this.onSetStatus});

  Color _statusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.processing:
        return kAdminCardGrey;
      case OrderStatus.shipped:
        return kAdminBlue;
      case OrderStatus.outForDelivery:
        return kAdminAmber;
      case OrderStatus.delivered:
        return kAdminGreen;
      case OrderStatus.cancelled:
        return kAdminRed;
    }
  }

  String _formatDate(DateTime d) => '${d.month}/${d.day}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(order.status);
    final itemCount = order.items.fold<int>(0, (acc, i) => acc + i.quantity);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showOrderDetails(context),
        child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: kAdminShadow, blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 40,
                width: 40,
                decoration:
                    BoxDecoration(color: kAdminBlue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: Icon(order.status.icon, color: kAdminBlue, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Order #${order.id.substring(0, order.id.length.clamp(0, 8))}',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: kAdminDarkBlue, fontSize: 14)),
                    Text(
                      order.recipientName?.isNotEmpty == true
                          ? '${order.recipientName} · ${order.branchName}'
                          : order.branchName,
                      style: const TextStyle(color: kAdminCardGrey, fontSize: 11),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<OrderStatus>(
                tooltip: 'Change status',
                onSelected: onSetStatus,
                itemBuilder: (context) => OrderStatus.values
                    .map((s) => PopupMenuItem(
                          value: s,
                          child: Row(
                            children: [
                              Icon(s.icon, size: 16, color: _statusColor(s)),
                              const SizedBox(width: 8),
                              Text(s.label),
                              if (s == order.status) ...[
                                const Spacer(),
                                const Icon(Icons.check, size: 16, color: kAdminGreen),
                              ],
                            ],
                          ),
                        ))
                    .toList(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(order.status.label,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
                      const SizedBox(width: 2),
                      Icon(Icons.arrow_drop_down, size: 16, color: color),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.event_outlined, size: 13, color: kAdminCardGrey),
              const SizedBox(width: 4),
              Text(_formatDate(order.date), style: const TextStyle(fontSize: 12, color: kAdminCardGrey)),
              const SizedBox(width: 12),
              const Icon(Icons.inventory_2_outlined, size: 13, color: kAdminCardGrey),
              const SizedBox(width: 4),
              Text('$itemCount item${itemCount == 1 ? '' : 's'}',
                  style: const TextStyle(fontSize: 12, color: kAdminCardGrey)),
              const Spacer(),
              Text('₱${order.total.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: kAdminDarkBlue)),
            ],
          ),
          if (order.deliveryAddress?.isNotEmpty == true) ...[
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on_outlined, size: 13, color: kAdminCardGrey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(order.deliveryAddress!,
                      style: const TextStyle(fontSize: 12, color: kAdminCardGrey)),
                ),
              ],
            ),
          ],
        ],
      ),
        ),
      ),
    );
  }

  /// Tapping anywhere on the card (outside the status pill) opens this —
  /// previously nothing happened on tap, which read as the card being
  /// unresponsive / "not showing" the order's data. This surfaces every
  /// field the order document actually has: full item list, recipient,
  /// payment method, and address, not just the summary shown on the card.
  void _showOrderDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Order #${order.id.substring(0, order.id.length.clamp(0, 8))}',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: kAdminDarkBlue, fontSize: 16)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                        color: _statusColor(order.status).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20)),
                    child: Text(order.status.label,
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.bold, color: _statusColor(order.status))),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(_formatDate(order.date), style: const TextStyle(color: kAdminCardGrey, fontSize: 12)),
              const Divider(height: 24),
              if (order.recipientName?.isNotEmpty == true) ...[
                _DetailRow(icon: Icons.person_outline, label: 'Recipient', value: order.recipientName!),
                const SizedBox(height: 10),
              ],
              _DetailRow(icon: Icons.storefront_outlined, label: 'Branch', value: order.branchName),
              const SizedBox(height: 10),
              if (order.deliveryAddress?.isNotEmpty == true) ...[
                _DetailRow(icon: Icons.location_on_outlined, label: 'Address', value: order.deliveryAddress!),
                const SizedBox(height: 10),
              ],
              if (order.paymentMethod?.isNotEmpty == true) ...[
                _DetailRow(icon: Icons.payments_outlined, label: 'Payment', value: order.paymentMethod!),
                const SizedBox(height: 10),
              ],
              const SizedBox(height: 6),
              const Text('Items', style: TextStyle(fontWeight: FontWeight.bold, color: kAdminDarkBlue, fontSize: 13)),
              const SizedBox(height: 8),
              ...order.items.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text('${item.quantity}× ${item.name}',
                              style: const TextStyle(color: kAdminDarkBlue, fontSize: 13)),
                        ),
                        Text('₱${(item.price * item.quantity).toStringAsFixed(2)}',
                            style: const TextStyle(color: kAdminCardGrey, fontSize: 13)),
                      ],
                    ),
                  )),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total', style: TextStyle(fontWeight: FontWeight.bold, color: kAdminDarkBlue)),
                  Text('₱${order.total.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: kAdminDarkBlue, fontSize: 16)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _DetailRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: kAdminCardGrey),
        const SizedBox(width: 8),
        SizedBox(
          width: 70,
          child: Text(label, style: const TextStyle(fontSize: 12, color: kAdminCardGrey)),
        ),
        Expanded(
          child: Text(value, style: const TextStyle(fontSize: 12, color: kAdminDarkBlue, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}
