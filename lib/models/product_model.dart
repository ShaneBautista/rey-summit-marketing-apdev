import 'package:flutter/material.dart';

/// A product as shown to customers in the ordering app.
///
/// [sku] intentionally matches the SKU used in the admin's Inventory
/// collection (e.g. "ITS-001" for Ice Tube – Small) — that's the link
/// between "customer places an order" and "admin sees stock go down".
/// See OrderService.placeOrder() for how that connection is used.
class Product {
  final String sku;
  final String name;
  final double price; // in PHP (₱)
  final IconData icon;
  final Color bgColor;

  const Product({
    required this.sku,
    required this.name,
    required this.price,
    required this.icon,
    required this.bgColor,
  });
}

/// The full Ice Tube catalog — matches the SKUs in the admin Inventory
/// screen (ITS-001, ITM-002, ITL-003) so an order placed here maps
/// directly onto a real stock item on the admin side.
const List<Product> iceTubeCatalog = [
  Product(
    sku: 'ITS-001',
    name: 'Ice Tube – Small',
    price: 45,
    icon: Icons.icecream_outlined,
    bgColor: Color(0xFFE6F2FB),
  ),
  Product(
    sku: 'ITM-002',
    name: 'Ice Tube – Medium',
    price: 65,
    icon: Icons.icecream_outlined,
    bgColor: Color(0xFFEAF6FF),
  ),
  Product(
    sku: 'ITL-003',
    name: 'Ice Tube – Large',
    price: 85,
    icon: Icons.icecream_outlined,
    bgColor: Color(0xFFE1EFFB),
  ),
  Product(
    sku: 'ITB-004',
    name: 'Bulk Ice',
    price: 120,
    icon: Icons.view_in_ar_outlined, // reads as a cube outline — ice cube
    bgColor: Color(0xFFF0F6FC),
  ),
  Product(
    sku: 'ITX-005',
    name: 'Extra Large',
    price: 150,
    icon: Icons.view_in_ar_outlined, // reads as a cube outline — ice cube
    bgColor: Color(0xFFE8F3FD),
  ),
  Product(
    sku: 'ITC-006',
    name: 'Crushed Ice',
    price: 55,
    icon: Icons.grain_outlined,
    bgColor: Color(0xFFECF5FC),
  ),
];

/// Convenience slices used on the home page — first 3 as "Top Deals",
/// last 2 as "Best Sellers". Swap these for real Firestore-driven
/// featured/best-seller queries once you have order history to rank by.
List<Product> get dummyTopDeals => iceTubeCatalog.sublist(0, 3);
List<Product> get dummyBestSellers => iceTubeCatalog.sublist(3, 5);

/// A line in the cart — a [Product] plus how many the customer wants.
/// Repeated "Add to cart" taps on the same product bump [quantity]
/// instead of creating duplicate rows (see HomeDashboardPage._addToCart).
class CartItem {
  final Product product;
  final int quantity;

  const CartItem({required this.product, required this.quantity});

  double get lineTotal => product.price * quantity;

  CartItem copyWith({int? quantity}) =>
      CartItem(product: product, quantity: quantity ?? this.quantity);
}
