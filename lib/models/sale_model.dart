import 'package:cloud_firestore/cloud_firestore.dart';

/// Mirrors the `sales` Firestore collection:
///   orderId: String, amount: Number, paymentMethod: String, saleDate: Timestamp
///
/// A "sale" is the finance-facing record of money collected for an order
/// — kept separate from the `orders` document itself so Analytics/Sales
/// screens can query payments without pulling every item/branch/status
/// field an order carries.
class SaleModel {
  final String id;
  final String orderId;
  final double amount;
  final String paymentMethod;
  final DateTime saleDate;

  const SaleModel({
    required this.id,
    required this.orderId,
    required this.amount,
    required this.paymentMethod,
    required this.saleDate,
  });

  factory SaleModel.fromMap(String id, Map<String, dynamic> map) {
    final rawDate = map['saleDate'];
    return SaleModel(
      id: id,
      orderId: map['orderId'] as String? ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      paymentMethod: map['paymentMethod'] as String? ?? '',
      saleDate: rawDate is Timestamp ? rawDate.toDate() : DateTime.now(),
    );
  }
}
