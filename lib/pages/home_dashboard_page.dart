import 'package:flutter/material.dart';

import '../models/product_model.dart';
import '../theme/colors.dart';
import '../widgets/animated_button.dart';
import 'order_history_page.dart';
import 'cart_page.dart';
import 'account_page.dart';

/// The main screen shown after a user logs in (and is verified).
/// Hosts the four-tab bottom navigation: Home, Order History, Cart, Account.
class HomeDashboardPage extends StatefulWidget {
  const HomeDashboardPage({super.key});

  @override
  State<HomeDashboardPage> createState() => _HomeDashboardPageState();
}

class _HomeDashboardPageState extends State<HomeDashboardPage> {
  int _tabIndex = 0;

  // In-memory cart — swap for a real CartService/Firestore cart later.
  final List<CartItem> _cartItems = [];

  // Tapping "Add to cart" on a product already in the cart bumps its
  // quantity instead of adding a duplicate row.
  void _addToCart(Product product) {
    setState(() {
      final existingIndex = _cartItems.indexWhere((c) => c.product.sku == product.sku);
      if (existingIndex != -1) {
        _cartItems[existingIndex] = _cartItems[existingIndex].copyWith(
          quantity: _cartItems[existingIndex].quantity + 1,
        );
      } else {
        _cartItems.add(CartItem(product: product, quantity: 1));
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added ${product.name} to cart'),
        action: SnackBarAction(
          label: 'View',
          onPressed: () => setState(() => _tabIndex = 2),
        ),
      ),
    );
  }

  void _removeFromCart(int index) {
    setState(() => _cartItems.removeAt(index));
  }

  // Used by the +/- stepper on the Cart tab. Quantity can't go below 1 —
  // use the remove (swipe/close) action to take an item out entirely.
  void _updateQuantity(int index, int newQuantity) {
    setState(() {
      if (newQuantity <= 0) {
        _cartItems.removeAt(index);
      } else {
        _cartItems[index] = _cartItems[index].copyWith(quantity: newQuantity);
      }
    });
  }

  void _clearCart() {
    setState(() => _cartItems.clear());
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      _HomeTab(onAddToCart: _addToCart),
      const OrderHistoryPage(),
      CartPage(
        items: _cartItems,
        onRemove: _removeFromCart,
        onQuantityChanged: _updateQuantity,
        onOrderPlaced: _clearCart,
      ),
      const AccountPage(),
    ];

    return Scaffold(
      backgroundColor: kLightMint,
      body: SafeArea(child: IndexedStack(index: _tabIndex, children: tabs)),
      bottomNavigationBar: _BottomNav(
        currentIndex: _tabIndex,
        cartCount: _cartItems.fold(0, (sum, c) => sum + c.quantity),
        onTap: (i) => setState(() => _tabIndex = i),
      ),
    );
  }
}

/// -------- Home tab content --------

class _HomeTab extends StatelessWidget {
  final ValueChanged<Product> onAddToCart;
  const _HomeTab({required this.onAddToCart});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _HomeHeader(),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: _BannerCarousel(),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: const Text('Top Deals',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kDarkGreen)),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 190,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: dummyTopDeals.length,
              separatorBuilder: (_, _) => const SizedBox(width: 14),
              itemBuilder: (_, i) => SizedBox(
                width: 150,
                child: _ProductCard(
                  product: dummyTopDeals[i],
                  onTap: () => onAddToCart(dummyTopDeals[i]),
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: const Text('Best Sellers',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kDarkGreen)),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 190,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: dummyBestSellers.length,
              separatorBuilder: (_, _) => const SizedBox(width: 14),
              itemBuilder: (_, i) => SizedBox(
                width: 150,
                child: _ProductCard(
                  product: dummyBestSellers[i],
                  onTap: () => onAddToCart(dummyBestSellers[i]),
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),
        ],
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        height: 36,
        child: Center(
          child: SizedBox(
            height: 32,
            child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}

class _BannerCarousel extends StatefulWidget {
  const _BannerCarousel();

  @override
  State<_BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<_BannerCarousel> {
  final PageController _controller = PageController();
  int _page = 0;

  final List<_BannerData> _banners = const [
    _BannerData(
      eyebrow: 'Stay Cool',
      title: 'Fresh Ice Tubes\nDelivered Fast',
      cta: 'Order Now',
      color: kHeaderGreen,
    ),
    _BannerData(
      eyebrow: 'Bulk Orders',
      title: 'Save More on\nLarge & Bulk Ice',
      cta: 'Order Now',
      color: kDarkGreen,
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 190,
          child: PageView.builder(
            controller: _controller,
            onPageChanged: (i) => setState(() => _page = i),
            itemCount: _banners.length,
            itemBuilder: (_, i) => _BannerCard(data: _banners[i]),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            _banners.length,
            (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              height: 6,
              width: i == _page ? 18 : 6,
              decoration: BoxDecoration(
                color: i == _page ? kDarkGreen : kBorderGrey,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BannerData {
  final String eyebrow;
  final String title;
  final String cta;
  final Color color;
  const _BannerData({required this.eyebrow, required this.title, required this.cta, required this.color});
}

class _BannerCard extends StatelessWidget {
  final _BannerData data;
  const _BannerCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: data.color.withValues(alpha: 0.15),
        boxShadow: const [BoxShadow(color: kShadowColor, blurRadius: 12, offset: Offset(0, 4))],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(data.eyebrow, style: const TextStyle(color: kFieldGrey, fontSize: 12)),
          const SizedBox(height: 6),
          Text(data.title,
              style: const TextStyle(color: kDarkGreen, fontSize: 20, fontWeight: FontWeight.bold, height: 1.2)),
          const SizedBox(height: 14),
          AnimatedButton(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Opening ${data.title.split('\n').first}...')),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(color: kDarkGreen, borderRadius: BorderRadius.circular(10)),
              child: Text(data.cta,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;
  const _ProductCard({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AnimatedButton(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [BoxShadow(color: kShadowColor, blurRadius: 10, offset: Offset(0, 4))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 110,
              width: double.infinity,
              color: product.bgColor,
              child: Icon(product.icon, color: kDarkGreen, size: 40),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kDarkGreen)),
                  const SizedBox(height: 4),
                  Text('₱${product.price.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: kDarkGreen)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// -------- Bottom navigation --------

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final int cartCount;
  final ValueChanged<int> onTap;

  const _BottomNav({required this.currentIndex, required this.cartCount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: const [BoxShadow(color: kShadowColor, blurRadius: 12, offset: Offset(0, -2))],
      ),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navItem(icon: Icons.home_outlined, label: 'Home', index: 0),
            // "Category" replaced with "Order History" per request.
            _navItem(icon: Icons.receipt_long_outlined, label: 'Order History', index: 1),
            _navItem(
              icon: Icons.shopping_cart_outlined,
              label: 'Cart',
              index: 2,
              badgeCount: cartCount,
              animateBadge: true,
            ),
            _navItem(icon: Icons.person_outline, label: 'My Account', index: 3),
          ],
        ),
      ),
    );
  }

  Widget _navItem({
    required IconData icon,
    required String label,
    required int index,
    int badgeCount = 0,
    bool animateBadge = false,
  }) {
    final bool selected = currentIndex == index;
    final Color color = selected ? kDarkGreen : kFieldGrey;

    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          animateBadge
              ? _AnimatedBadgeIcon(icon: icon, color: color, count: badgeCount)
              : _StaticBadgeIcon(icon: icon, color: color, count: badgeCount),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
          if (selected) ...[
            const SizedBox(height: 2),
            Container(height: 2, width: 18, color: kDarkGreen),
          ],
        ],
      ),
    );
  }
}

/// Plain icon + badge, no animation — used for nav items that don't need it.
class _StaticBadgeIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final int count;
  const _StaticBadgeIcon({required this.icon, required this.color, required this.count});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon, color: color, size: 24),
        if (count > 0)
          Positioned(
            right: -8,
            top: -4,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                '$count',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ),
      ],
    );
  }
}

/// Cart icon that bounces whenever [count] goes up, with the badge number
/// scale-transitioning in — visual confirmation that "Add to cart" worked.
class _AnimatedBadgeIcon extends StatefulWidget {
  final IconData icon;
  final Color color;
  final int count;
  const _AnimatedBadgeIcon({required this.icon, required this.color, required this.count});

  @override
  State<_AnimatedBadgeIcon> createState() => _AnimatedBadgeIconState();
}

class _AnimatedBadgeIconState extends State<_AnimatedBadgeIcon> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
  );
  late final Animation<double> _bounce =
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut);

  @override
  void didUpdateWidget(covariant _AnimatedBadgeIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.count > oldWidget.count) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _bounce,
      builder: (context, child) => Transform.scale(scale: 1.0 + (_bounce.value * 0.35), child: child),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(widget.icon, color: widget.color, size: 24),
          if (widget.count > 0)
            Positioned(
              right: -8,
              top: -4,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                child: Container(
                  key: ValueKey<int>(widget.count),
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text(
                    '${widget.count}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
