import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Stages an order moves through. Order matters — index is used to
/// compute progress in the tracker UI.
enum OrderStatus {
  processing,
  shipped,
  outForDelivery,
  delivered,
  cancelled,
}

extension OrderStatusX on OrderStatus {
  String get label {
    switch (this) {
      case OrderStatus.processing:
        return 'Processing';
      case OrderStatus.shipped:
        return 'Shipped';
      case OrderStatus.outForDelivery:
        return 'Out for delivery';
      case OrderStatus.delivered:
        return 'Delivered';
      case OrderStatus.cancelled:
        return 'Cancelled';
    }
  }

  IconData get icon {
    switch (this) {
      case OrderStatus.processing:
        return Icons.hourglass_top_outlined;
      case OrderStatus.shipped:
        return Icons.local_shipping_outlined;
      case OrderStatus.outForDelivery:
        return Icons.directions_run_outlined;
      case OrderStatus.delivered:
        return Icons.check_circle_outline;
      case OrderStatus.cancelled:
        return Icons.cancel_outlined;
    }
  }
}

class OrderItem {
  final String sku;
  final String name;
  final int quantity;
  final double price;

  const OrderItem({
    required this.sku,
    required this.name,
    required this.quantity,
    required this.price,
  });

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      sku: map['sku'] as String? ?? '',
      name: map['name'] as String? ?? '',
      quantity: (map['qty'] as num?)?.toInt() ?? 1,
      price: (map['price'] as num?)?.toDouble() ?? 0,
    );
  }
}

class OrderModel {
  final String id;
  final String uid;
  final String branchId;
  final String branchName;
  final DateTime date;
  final List<OrderItem> items;
  final double total;
  final OrderStatus status;
  final String? recipientName;
  final String? deliveryAddress;
  final String? paymentMethod;

  const OrderModel({
    required this.id,
    required this.uid,
    required this.branchId,
    required this.branchName,
    required this.date,
    required this.items,
    required this.total,
    required this.status,
    this.recipientName,
    this.deliveryAddress,
    this.paymentMethod,
  });

  factory OrderModel.fromMap(String id, Map<String, dynamic> map) {
    final rawItems = (map['items'] as List<dynamic>? ?? [])
        .map((e) => OrderItem.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();

    final rawDate = map['date'];
    final date = rawDate is Timestamp ? rawDate.toDate() : DateTime.now();

    return OrderModel(
      id: id,
      uid: map['uid'] as String? ?? '',
      branchId: map['branchId'] as String? ?? '',
      branchName: map['branchName'] as String? ?? '',
      date: date,
      items: rawItems,
      total: (map['total'] as num?)?.toDouble() ?? 0,
      status: OrderStatus.values.firstWhere(
        (s) => s.name == (map['status'] as String? ?? OrderStatus.processing.name),
        orElse: () => OrderStatus.processing,
      ),
      deliveryAddress: map['deliveryAddress'] as String?,
      paymentMethod: map['paymentMethod'] as String?,
      recipientName: map['recipientName'] as String?,
    );
  }
}
