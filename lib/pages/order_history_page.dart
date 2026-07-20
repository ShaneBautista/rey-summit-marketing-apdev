import 'package:flutter/material.dart';

import '../models/order_model.dart';
import '../services/order_service.dart';
import '../theme/colors.dart';

/// Shows the signed-in user's past orders with a visual progress tracker
/// for each one (Processing -> Shipped -> Out for delivery -> Delivered).
///
/// Pulls from the same Firestore `orders` collection the admin app reads —
/// see order_service.dart for how that connection works.
class OrderHistoryPage extends StatefulWidget {
  const OrderHistoryPage({super.key});

  @override
  State<OrderHistoryPage> createState() => _OrderHistoryPageState();
}

class _OrderHistoryPageState extends State<OrderHistoryPage> {
  final OrderService _orderService = OrderService();
  late Stream<List<OrderModel>> _ordersStream;

  @override
  void initState() {
    super.initState();
    _ordersStream = _orderService.streamMyOrders();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, 4),
          child: Text('Order History',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: kDarkGreen)),
        ),
        Expanded(
          child: StreamBuilder<List<OrderModel>>(
            stream: _ordersStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: kDarkGreen));
              }
              if (snapshot.hasError) {
                return const Center(
                  child: Text('Could not load orders — check your connection.', style: TextStyle(color: kFieldGrey)),
                );
              }
              final orders = snapshot.data ?? [];
              if (orders.isEmpty) {
                return const Center(
                  child: Text("You haven't placed any orders yet.", style: TextStyle(color: kFieldGrey)),
                );
              }
              // A real-time stream already keeps this list current, but the
              // ListView is still wrapped in a RefreshIndicator so a
              // pull-down gesture has a familiar response instead of doing
              // nothing.
              return RefreshIndicator(
                color: kDarkGreen,
                onRefresh: () async {
                  setState(() => _ordersStream = _orderService.streamMyOrders());
                  await _ordersStream.first;
                },
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  itemCount: orders.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 14),
                  itemBuilder: (_, i) => _OrderCard(order: orders[i]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _OrderCard extends StatelessWidget {
  final OrderModel order;
  const _OrderCard({required this.order});

  String _formatDate(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: kShadowColor, blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('#${order.id.substring(0, order.id.length.clamp(0, 8))}',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: kDarkGreen, fontSize: 14)),
              Text(_formatDate(order.date), style: const TextStyle(color: kFieldGrey, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 4),
          Text(order.branchName, style: const TextStyle(color: kFieldGrey, fontSize: 12)),
          const SizedBox(height: 10),
          ...order.items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  const Icon(Icons.view_in_ar_outlined, size: 16, color: kFieldGrey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('${item.name}  x${item.quantity}',
                        style: const TextStyle(fontSize: 13, color: kDarkGreen)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total: ₱${order.total.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: kDarkGreen)),
              _StatusChip(status: order.status),
            ],
          ),
          if (order.status != OrderStatus.cancelled) ...[
            const SizedBox(height: 14),
            _StatusTracker(status: order.status),
          ],
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final OrderStatus status;
  const _StatusChip({required this.status});

  Color get _color {
    switch (status) {
      case OrderStatus.delivered:
        return kDarkGreen;
      case OrderStatus.cancelled:
        return Colors.redAccent;
      default:
        return kHeaderGreen;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: _color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, size: 13, color: _color),
          const SizedBox(width: 4),
          Text(status.label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _color)),
        ],
      ),
    );
  }
}

/// Horizontal step tracker: Processing -> Shipped -> Out for delivery -> Delivered.
class _StatusTracker extends StatelessWidget {
  final OrderStatus status;
  const _StatusTracker({required this.status});

  static const _steps = [
    OrderStatus.processing,
    OrderStatus.shipped,
    OrderStatus.outForDelivery,
    OrderStatus.delivered,
  ];

  @override
  Widget build(BuildContext context) {
    final currentIndex = _steps.indexOf(status);
    return Row(
      children: List.generate(_steps.length, (i) {
        final bool reached = i <= currentIndex;
        final bool isLast = i == _steps.length - 1;
        return Expanded(
          child: Row(
            children: [
              Container(
                height: 10,
                width: 10,
                decoration: BoxDecoration(shape: BoxShape.circle, color: reached ? kDarkGreen : kBorderGrey),
              ),
              if (!isLast)
                Expanded(child: Container(height: 2, color: i < currentIndex ? kDarkGreen : kBorderGrey)),
            ],
          ),
        );
      }),
    );
  }
}
