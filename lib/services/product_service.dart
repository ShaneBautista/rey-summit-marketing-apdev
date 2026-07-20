import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/product_doc_model.dart';
import '../models/product_model.dart' show iceTubeCatalog;

/// Reads/writes the `products` Firestore collection. Used by:
///  - an admin "Manage Products" screen (add/edit/deactivate items)
///  - anywhere you want the catalog to be editable without shipping a new
///    app build, instead of the hardcoded `iceTubeCatalog` list.
///
/// HOW THIS CONNECTS TO THE REST OF THE APP:
/// [ProductDoc.sku] uses the exact same sku strings as `iceTubeCatalog`
/// (ITS-001, ITM-002, ...), `InventoryItem.sku`, and `OrderItem.sku`. So
/// once this collection is seeded, a single sku lets you look up: the
/// catalog entry, its stock across branches (InventoryService), and every
/// order line that ever referenced it (OrderService) — all from one key.
class ProductService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _products => _firestore.collection('products');

  /// One-shot fetch. Optionally filter by category or to active items only
  /// (e.g. for the customer-facing catalog, which shouldn't show
  /// discontinued products).
  Future<List<ProductDoc>> fetchProducts({String? category, bool activeOnly = false}) async {
    Query<Map<String, dynamic>> query = _products;
    if (category != null) query = query.where('category', isEqualTo: category);
    if (activeOnly) query = query.where('status', isEqualTo: 'active');
    final snap = await query.get();
    return snap.docs.map((d) => ProductDoc.fromMap(d.id, d.data())).toList();
  }

  /// Realtime version — use this on the admin Manage Products screen so
  /// edits (price changes, deactivating an item) show up immediately,
  /// the same way InventoryService.streamInventory() does for stock.
  Stream<List<ProductDoc>> streamProducts() {
    return _products.snapshots().map(
          (snap) => snap.docs.map((d) => ProductDoc.fromMap(d.id, d.data())).toList(),
        );
  }

  /// sku is the doc ID, so this both creates a new product and lets you
  /// re-run it to overwrite an existing one with the same sku.
  Future<void> addProduct(ProductDoc product) => _products.doc(product.sku).set(product.toMap());

  Future<void> updateProduct(ProductDoc product) => _products.doc(product.sku).update(product.toMap());

  /// Quick toggle for "discontinue this product" without a full edit form.
  Future<void> setStatus(String sku, String status) => _products.doc(sku).update({'status': status});

  Future<void> deleteProduct(String sku) => _products.doc(sku).delete();

  /// Writes the existing local `iceTubeCatalog` into the `products`
  /// collection for real, once — same pattern as
  /// InventoryService.seedSampleInventory() and BranchService.seedSampleBranches().
  /// Safe to call more than once: no-ops if the collection already has data.
  Future<bool> seedFromLocalCatalog() async {
    final existing = await _products.limit(1).get();
    if (existing.docs.isNotEmpty) return false;

    final batch = _firestore.batch();
    for (final p in iceTubeCatalog) {
      final doc = ProductDoc(
        sku: p.sku,
        productName: p.name,
        price: p.price,
        category: 'Ice',
        status: 'active',
      );
      batch.set(_products.doc(doc.sku), doc.toMap());
    }
    await batch.commit();
    return true;
  }
}
