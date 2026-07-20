/// Mirrors the `products` Firestore collection:
///   productName: String, price: Number, category: String, status: String
///
/// This is separate from the `Product` class in models/product_model.dart
/// on purpose — that class also carries IconData/Color for the customer
/// UI, and Firestore can't store those. [ProductDoc] is the admin-facing,
/// Firestore-backed record; the existing local `iceTubeCatalog` is what
/// renders the icons.
///
/// [sku] is used as the Firestore document ID — the SAME sku already
/// used by InventoryService, OrderService (OrderItem.sku), and the local
/// Product catalog. That shared key is what ties a `products` document,
/// an `inventory` row, and a line item in an `orders` document together
/// as "the same product".
class ProductDoc {
  final String sku; // Firestore doc id
  final String productName;
  final double price;
  final String category;
  final String status; // e.g. "active" / "inactive" / "discontinued"

  const ProductDoc({
    required this.sku,
    required this.productName,
    required this.price,
    required this.category,
    this.status = 'active',
  });

  Map<String, dynamic> toMap() => {
        'productName': productName,
        'price': price,
        'category': category,
        'status': status,
      };

  factory ProductDoc.fromMap(String sku, Map<String, dynamic> map) {
    return ProductDoc(
      sku: sku,
      productName: map['productName'] as String? ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0,
      category: map['category'] as String? ?? '',
      status: map['status'] as String? ?? 'active',
    );
  }

  ProductDoc copyWith({String? productName, double? price, String? category, String? status}) {
    return ProductDoc(
      sku: sku,
      productName: productName ?? this.productName,
      price: price ?? this.price,
      category: category ?? this.category,
      status: status ?? this.status,
    );
  }
}
