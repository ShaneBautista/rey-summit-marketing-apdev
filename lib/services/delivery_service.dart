import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/delivery_model.dart';
import '../models/order_model.dart';
import 'order_service.dart';

/// Reads/writes the `deliveries` Firestore collection — one document per
/// order once it's handed off for delivery, tracking WHO is delivering it
/// (deliveryStaffId) and a delivery-specific status, kept separate from
/// the order's own `status` field (see OrderModel/OrderService).
///
/// HOW THIS CONNECTS TO ORDERS:
/// [orderId] is the same Firestore document ID OrderService already uses
/// for the `orders` collection — that's the join key between the two.
/// A delivery doc doesn't duplicate order data (items, total, branch);
/// it only adds what's delivery-specific.
///
/// WHERE TO CALL THIS FROM:
/// In your admin Orders screen, right after you call
/// `OrderService().updateOrderStatus(orderId, OrderStatus.shipped)` and
/// have picked a rider, call [createDelivery] with that same orderId.
/// As the rider updates progress, call [updateDeliveryStatus].
class DeliveryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _deliveries => _firestore.collection('deliveries');

  /// Uses [orderId] as the delivery doc's own ID (via .doc(orderId) instead
  /// of .add()) so there's exactly one delivery record per order and no
  /// query is ever needed to find it — you already have the orderId.
  Future<void> createDelivery({
    required String orderId,
    required String deliveryStaffId,
  }) {
    return _deliveries.doc(orderId).set({
      'orderId': orderId,
      'deliveryStaffId': deliveryStaffId,
      'status': DeliveryStatus.pending.name,
      'deliveryDate': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateDeliveryStatus(String orderId, DeliveryStatus status) {
    return _deliveries.doc(orderId).update({'status': status.name});
  }

  /// Keeps `deliveries` in sync whenever an order's status moves through
  /// the delivery pipeline (shipped and beyond). Called from the admin
  /// Deliveries tab right after `OrderService.updateOrderStatus()`
  /// succeeds — that's what actually populates this collection instead
  /// of it staying empty. Uses `SetOptions(merge: true)` so it works
  /// whether or not a doc already exists for this order yet, with no
  /// separate "has this order been assigned a delivery doc?" check
  /// needed. `deliveryStaffId` isn't touched here — there's no rider
  /// assignment UI yet, so it's left for a future "assign rider" feature
  /// to fill in; existing values (if any) are preserved by the merge.
  Future<void> syncFromOrderStatus(String orderId, OrderStatus orderStatus) {
    final deliveryStatus = _deliveryStatusFor(orderStatus);
    if (deliveryStatus == null) return Future.value();
    return _deliveries.doc(orderId).set({
      'orderId': orderId,
      'status': deliveryStatus.name,
      'deliveryDate': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  DeliveryStatus? _deliveryStatusFor(OrderStatus orderStatus) {
    switch (orderStatus) {
      case OrderStatus.processing:
        return null; // not handed off for delivery yet — no doc needed
      case OrderStatus.shipped:
        return DeliveryStatus.pending;
      case OrderStatus.outForDelivery:
        return DeliveryStatus.outForDelivery;
      case OrderStatus.delivered:
        return DeliveryStatus.delivered;
      case OrderStatus.cancelled:
        return DeliveryStatus.failed;
    }
  }

  /// Admin "Deliveries" screen — every delivery, or just one rider's queue.
  Future<List<DeliveryModel>> fetchDeliveries({String? deliveryStaffId}) async {
    Query<Map<String, dynamic>> query = _deliveries;
    if (deliveryStaffId != null) {
      query = query.where('deliveryStaffId', isEqualTo: deliveryStaffId);
    }
    final snap = await query.get();
    return snap.docs.map((d) => DeliveryModel.fromMap(d.id, d.data())).toList();
  }

  /// Realtime version — a rider's own "My Deliveries" screen should use
  /// this so a newly-assigned delivery shows up without a manual refresh.
  Stream<List<DeliveryModel>> streamDeliveries({String? deliveryStaffId}) {
    Query<Map<String, dynamic>> query = _deliveries;
    if (deliveryStaffId != null) {
      query = query.where('deliveryStaffId', isEqualTo: deliveryStaffId);
    }
    return query.snapshots().map(
          (snap) => snap.docs.map((d) => DeliveryModel.fromMap(d.id, d.data())).toList(),
        );
  }

  /// Look up the single delivery record for one order (e.g. to show
  /// "assigned to: (rider)" on the customer's order tracking screen).
  Future<DeliveryModel?> fetchForOrder(String orderId) async {
    final doc = await _deliveries.doc(orderId).get();
    if (!doc.exists) return null;
    return DeliveryModel.fromMap(doc.id, doc.data()!);
  }

  /// Populates `deliveries` with real Firestore documents, one per
  /// existing order that's shipped/out-for-delivery/delivered — same
  /// idea as InventoryService.seedSampleInventory() and
  /// OrderService.seedSampleOrders(), but this one deliberately reuses
  /// REAL order ids already in your `orders` collection (via
  /// OrderService.fetchAllOrders()) instead of inventing fake ones, so
  /// every delivery doc this creates actually joins to a real order.
  ///
  /// If you have no orders yet (or none past "processing"), run
  /// OrderService().seedSampleOrders() first — those seeded orders are
  /// marked delivered, so this will pick them up.
  ///
  /// Safe to call more than once — skips orders that already have a
  /// delivery doc.
  Future<int> seedSampleDeliveries() async {
    final orders = await OrderService().fetchAllOrders();
    final relevant = orders.where((o) =>
        o.status == OrderStatus.shipped ||
        o.status == OrderStatus.outForDelivery ||
        o.status == OrderStatus.delivered);

    const sampleRiders = ['rider_001', 'rider_002', 'rider_003'];
    int created = 0;
    var i = 0;

    for (final order in relevant) {
      final existing = await _deliveries.doc(order.id).get();
      if (existing.exists) continue;

      final status = order.status == OrderStatus.delivered
          ? DeliveryStatus.delivered
          : order.status == OrderStatus.outForDelivery
              ? DeliveryStatus.outForDelivery
              : DeliveryStatus.pending;

      await _deliveries.doc(order.id).set({
        'orderId': order.id,
        'deliveryStaffId': sampleRiders[i % sampleRiders.length],
        'status': status.name,
        'deliveryDate': Timestamp.fromDate(order.date),
      });
      i++;
      created++;
    }
    return created;
  }
}
