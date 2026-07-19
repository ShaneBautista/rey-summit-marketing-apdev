enum StockStatus { inStock, lowStock, outOfStock }

extension StockStatusX on StockStatus {
  String get label {
    switch (this) {
      case StockStatus.inStock:
        return 'In Stock';
      case StockStatus.lowStock:
        return 'Low Stock';
      case StockStatus.outOfStock:
        return 'Out of Stock';
    }
  }

  /// Derives status from a raw quantity — used when writing/reading so the
  /// label always matches the number instead of being set by hand.
  static StockStatus fromQty(int qty, {int lowThreshold = 20}) {
    if (qty <= 0) return StockStatus.outOfStock;
    if (qty <= lowThreshold) return StockStatus.lowStock;
    return StockStatus.inStock;
  }
}

/// One SKU at one branch. E.g. "Ice Tube – Small" at "Main Branch".
class InventoryItem {
  final String id;
  final String sku;
  final String name;
  final int qty;
  final double price; // in PHP (₱)
  final String branchId;
  final String branchName;
  final DateTime restocked;

  const InventoryItem({
    required this.id,
    required this.sku,
    required this.name,
    required this.qty,
    required this.price,
    required this.branchId,
    required this.branchName,
    required this.restocked,
  });

  StockStatus get status => StockStatusX.fromQty(qty);

  Map<String, dynamic> toMap() => {
        'sku': sku,
        'name': name,
        'qty': qty,
        'price': price,
        'branchId': branchId,
        'branchName': branchName,
        'restocked': restocked.toIso8601String(),
      };

  factory InventoryItem.fromMap(String id, Map<String, dynamic> map) {
    return InventoryItem(
      id: id,
      sku: map['sku'] as String? ?? '',
      name: map['name'] as String? ?? '',
      qty: (map['qty'] as num?)?.toInt() ?? 0,
      price: (map['price'] as num?)?.toDouble() ?? 0,
      branchId: map['branchId'] as String? ?? '',
      branchName: map['branchName'] as String? ?? '',
      restocked: DateTime.tryParse(map['restocked'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
