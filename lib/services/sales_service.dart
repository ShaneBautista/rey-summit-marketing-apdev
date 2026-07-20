import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/sale_model.dart';

/// Reads/writes the `sales` Firestore collection — one document per
/// payment collected for an order.
///
/// HOW THIS CONNECTS TO ORDERS:
/// [orderId] is the same document ID OrderService uses in `orders`, and
/// this doc's `amount` mirrors that order's `total` at the moment of
/// payment. Recording it as its own document (rather than only reading
/// `orders.total`) means a payment-method breakdown, a refund/partial
/// payment later, or a finance export can all be built from `sales`
/// without re-touching order documents.
///
/// WHERE TO CALL THIS FROM:
/// Call [recordSale] once per order — either right after
/// `OrderService.placeOrder()` succeeds (if you consider a sale final at
/// checkout), or when the order is marked delivered/paid, depending on
/// your business rule. Don't call it in both places or you'll double it.
class SalesService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _sales => _firestore.collection('sales');

  /// Uses [orderId] as the sale doc's own ID so there's one sale per
  /// order and it's trivial to check "has this order already been
  /// recorded as a sale?" without a query.
  Future<void> recordSale({
    required String orderId,
    required double amount,
    required String paymentMethod,
  }) {
    return _sales.doc(orderId).set({
      'orderId': orderId,
      'amount': amount,
      'paymentMethod': paymentMethod,
      'saleDate': FieldValue.serverTimestamp(),
    });
  }

  /// Admin Sales/Analytics screens — optionally scoped to a date range.
  Future<List<SaleModel>> fetchSales({DateTime? from, DateTime? to}) async {
    Query<Map<String, dynamic>> query = _sales;
    if (from != null) query = query.where('saleDate', isGreaterThanOrEqualTo: Timestamp.fromDate(from));
    if (to != null) query = query.where('saleDate', isLessThanOrEqualTo: Timestamp.fromDate(to));
    final snap = await query.get();
    final sales = snap.docs.map((d) => SaleModel.fromMap(d.id, d.data())).toList();
    sales.sort((a, b) => b.saleDate.compareTo(a.saleDate));
    return sales;
  }

  Stream<List<SaleModel>> streamSales() {
    return _sales.snapshots().map((snap) {
      final sales = snap.docs.map((d) => SaleModel.fromMap(d.id, d.data())).toList();
      sales.sort((a, b) => b.saleDate.compareTo(a.saleDate));
      return sales;
    });
  }
}
