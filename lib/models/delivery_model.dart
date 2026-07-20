import 'package:cloud_firestore/cloud_firestore.dart';

/// Delivery-specific stage, separate from OrderStatus (order_model.dart).
/// An order can be "shipped" while its delivery is still "pending" if no
/// rider has been assigned yet.
enum DeliveryStatus { pending, outForDelivery, delivered, failed }

extension DeliveryStatusX on DeliveryStatus {
  String get label {
    switch (this) {
      case DeliveryStatus.pending:
        return 'Pending';
      case DeliveryStatus.outForDelivery:
        return 'Out for delivery';
      case DeliveryStatus.delivered:
        return 'Delivered';
      case DeliveryStatus.failed:
        return 'Failed';
    }
  }
}

/// Mirrors the `deliveries` Firestore collection:
///   orderId: String, deliveryStaffId: String, status: String, deliveryDate: Timestamp
///
/// [id] is the Firestore document id — DeliveryService uses the same
/// value as [orderId] for this, so an order and its delivery record
/// share one id and there's never a lookup query needed to join them.
class DeliveryModel {
  final String id;
  final String orderId;
  final String deliveryStaffId;
  final DeliveryStatus status;
  final DateTime deliveryDate;

  const DeliveryModel({
    required this.id,
    required this.orderId,
    required this.deliveryStaffId,
    required this.status,
    required this.deliveryDate,
  });

  factory DeliveryModel.fromMap(String id, Map<String, dynamic> map) {
    final rawDate = map['deliveryDate'];
    return DeliveryModel(
      id: id,
      orderId: map['orderId'] as String? ?? '',
      deliveryStaffId: map['deliveryStaffId'] as String? ?? '',
      status: DeliveryStatus.values.firstWhere(
        (s) => s.name == (map['status'] as String? ?? DeliveryStatus.pending.name),
        orElse: () => DeliveryStatus.pending,
      ),
      deliveryDate: rawDate is Timestamp ? rawDate.toDate() : DateTime.now(),
    );
  }
}
