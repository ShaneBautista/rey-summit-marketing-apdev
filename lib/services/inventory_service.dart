import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/inventory_item_model.dart';

/// Reads/writes the `inventory` Firestore collection — one document per
/// SKU per branch (e.g. "Ice Tube – Small" at "Alangilan" is its own
/// document, separate from "Ice Tube – Small" at "Sta. Teresita").
///
/// HOW THIS CONNECTS TO CUSTOMER ORDERS:
/// When a customer places an order (OrderService.placeOrder), each cart
/// item carries the same `sku` used here. To have stock actually decrease
/// when someone orders, call [decrementStock] for each item right after
/// the order document is created — e.g. from a Cloud Function trigger on
/// `orders/{orderId}` being created, or directly in placeOrder() once you
/// want that behavior:
///
/// ```dart
/// for (final item in itemMaps) {
///   await InventoryService().decrementStock(
///     sku: item['sku'], branchId: branchId, by: item['qty'],
///   );
/// }
/// ```
/// A Cloud Function trigger is the safer place for this in production
/// (so stock can't be bypassed by a client skipping the call), but doing
/// it client-side is fine to get the flow working first.
class InventoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _inventory => _firestore.collection('inventory');

  Future<List<InventoryItem>> fetchInventory({String? branchId}) async {
    Query<Map<String, dynamic>> query = _inventory;
    if (branchId != null) {
      query = query.where('branchId', isEqualTo: branchId);
    }
    final snap = await query.get();
    if (snap.docs.isEmpty) return _seedInventory;
    return snap.docs.map((d) => InventoryItem.fromMap(d.id, d.data())).toList();
  }

  /// Real-time, Firestore-backed replacement for [fetchInventory].
  ///
  /// [fetchInventory] only reads once and falls back to the local
  /// [_seedInventory] list when the collection is empty — that list was
  /// never a real Firestore document, so restocking it, decrementing it
  /// from a customer order, or any other write had nothing to attach to.
  /// This stream instead: (1) seeds the sample catalog into real Firestore
  /// documents the first time it's empty, then (2) stays subscribed via
  /// `snapshots()`, so every restock, order-triggered decrement, or manual
  /// Firestore edit shows up on the Inventory screen immediately — the
  /// same fix already applied to Order History via streamMyOrders().
  ///
  /// Wrapped in `.asBroadcastStream()` (see [streamInventory]) because the
  /// Dashboard tab listens to the *same* Stream instance from two separate
  /// StreamBuilders at once (stat cards + Recent Stock Activity). An
  /// `async*` generator produces a single-subscription stream by default,
  /// so the second `.listen()` call throws `Bad state: Stream has already
  /// been listened to.` — that's the red error screen replacing the
  /// Recent Stock Activity card, and it's also why nothing (including a
  /// restock) appeared to update after that: the whole tab was stuck on
  /// the crashed frame.
  Stream<List<InventoryItem>> _streamInventoryImpl({String? branchId}) async* {
    final existing = await _inventory.limit(1).get();
    if (existing.docs.isEmpty) {
      await seedSampleInventory();
    }

    Query<Map<String, dynamic>> query = _inventory;
    if (branchId != null) {
      query = query.where('branchId', isEqualTo: branchId);
    }
    yield* query.snapshots().map(
          (snap) => snap.docs.map((d) => InventoryItem.fromMap(d.id, d.data())).toList(),
        );
  }

  Stream<List<InventoryItem>> streamInventory({String? branchId}) {
    return _streamInventoryImpl(branchId: branchId).asBroadcastStream();
  }

  Future<void> decrementStock({required String sku, required String branchId, required int by}) async {
    final match = await _inventory
        .where('sku', isEqualTo: sku)
        .where('branchId', isEqualTo: branchId)
        .limit(1)
        .get();
    if (match.docs.isEmpty) return;
    await match.docs.first.reference.update({'qty': FieldValue.increment(-by)});
  }

  /// Adds stock for one inventory document (the "Restock" action on the
  /// admin Inventory screen) and bumps its `restocked` date to now.
  ///
  /// [docId] must be a real Firestore document id from the `inventory`
  /// collection — not one of the client-side [_seedInventory] fallback
  /// rows (those have ids like `seed-1` and don't exist in Firestore yet).
  /// If the Inventory screen is still showing fallback data, run "Seed
  /// sample data" first so there's a real document to update.
  Future<void> restockItem({required String docId, required int addQty}) async {
    await _inventory.doc(docId).update({
      'qty': FieldValue.increment(addQty),
      'restocked': DateTime.now().toIso8601String(),
    });
  }

  /// [fetchInventory] falls back to [_seedInventory] purely client-side
  /// when the Firestore `inventory` collection is empty — that's why the
  /// admin Inventory screen can show sample rows even on a brand-new
  /// project, but also why [decrementStock] silently does nothing: those
  /// rows don't actually exist as documents yet, so there's nothing to
  /// match and update.
  ///
  /// Call this once (e.g. from an admin "Seed Sample Data" button) to
  /// write [_seedInventory] into Firestore for real. Safe to call more
  /// than once — it checks for existing documents first and no-ops if
  /// the collection already has data, so it won't create duplicates.
  Future<bool> seedSampleInventory() async {
    final existing = await _inventory.limit(1).get();
    if (existing.docs.isNotEmpty) return false;
    final batch = _firestore.batch();
    for (final item in _seedInventory) {
      batch.set(_inventory.doc('${item.sku}_${item.branchId}'), item.toMap());
    }
    await batch.commit();
    return true;
  }

  static final List<InventoryItem> _seedInventory = [
    InventoryItem(
      id: 'seed-1',
      sku: 'ITS-001',
      name: 'Ice Tube – Small',
      qty: 150,
      price: 45,
      branchId: 'alangilan',
      branchName: 'Alangilan',
      restocked: DateTime(2025, 6, 8),
    ),
    InventoryItem(
      id: 'seed-2',
      sku: 'ITM-002',
      name: 'Ice Tube – Medium',
      qty: 200,
      price: 65,
      branchId: 'alangilan',
      branchName: 'Alangilan',
      restocked: DateTime(2025, 6, 5),
    ),
    InventoryItem(
      id: 'seed-3',
      sku: 'ITL-003',
      name: 'Ice Tube – Large',
      qty: 12,
      price: 85,
      branchId: 'sta_teresita',
      branchName: 'Sta. Teresita',
      restocked: DateTime(2025, 5, 28),
    ),
    InventoryItem(
      id: 'seed-4',
      sku: 'ITB-004',
      name: 'Bulk Ice',
      qty: 80,
      price: 120,
      branchId: 'san_luis',
      branchName: 'San Luis',
      restocked: DateTime(2025, 6, 1),
    ),
    InventoryItem(
      id: 'seed-5',
      sku: 'ITX-005',
      name: 'Extra Large',
      qty: 0,
      price: 150,
      branchId: 'mabini',
      branchName: 'Mabini',
      restocked: DateTime(2025, 5, 20),
    ),
    InventoryItem(
      id: 'seed-6',
      sku: 'ITC-006',
      name: 'Crushed Ice',
      qty: 65,
      price: 55,
      branchId: 'alangilan',
      branchName: 'Alangilan',
      restocked: DateTime(2025, 6, 10),
    ),
  ];
}
