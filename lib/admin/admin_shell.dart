import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../pages/welcome_page.dart';
import 'admin_colors.dart';
import 'dashboard_tab.dart';
import 'inventory_tab.dart';
import 'analytics_tab.dart';
import 'branches_tab.dart';

/// The employee/admin app — shown instead of HomeDashboardPage when a
/// signed-in user's profile role is `employee`. See homepage.dart's login
/// flow for where that routing decision happens.
class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _tabIndex = 0;

  final _tabs = const [
    DashboardTab(),
    InventoryTab(),
    AnalyticsTab(),
    BranchesTab(),
  ];

  Future<void> _signOut() async {
    await AuthService().signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WelcomePage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kAdminBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: Image.asset(
                'assets/images/logo.png',
                height: 34,
                width: 34,
                fit: BoxFit.contain,
                // Falls back to the old icon instead of Flutter's red error
                // box if assets/logo.png hasn't been registered in
                // pubspec.yaml yet, or the app hasn't been fully restarted
                // since it was added.
                errorBuilder: (context, error, stackTrace) => Container(
                  color: kAdminBlue,
                  alignment: Alignment.center,
                  child: const Icon(Icons.ac_unit, color: Colors.white, size: 18),
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('IceTube Admin',
                    style: TextStyle(color: kAdminDarkBlue, fontSize: 15, fontWeight: FontWeight.bold)),
                Text('Company Portal', style: TextStyle(color: kAdminCardGrey, fontSize: 11)),
              ],
            ),
          ],
        ),
        actions: [
          const Icon(Icons.notifications_none, color: kAdminCardGrey),
          const SizedBox(width: 16),
          PopupMenuButton<String>(
            offset: const Offset(0, 44),
            onSelected: (v) {
              if (v == 'signout') _signOut();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'signout', child: Text('Sign Out')),
            ],
            child: Container(
              height: 30,
              width: 30,
              decoration: const BoxDecoration(color: kAdminBlue, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: const Text('A', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SafeArea(top: false, child: IndexedStack(index: _tabIndex, children: _tabs)),
      bottomNavigationBar: _AdminBottomNav(
        currentIndex: _tabIndex,
        onTap: (i) => setState(() => _tabIndex = i),
      ),
    );
  }
}

class _AdminBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _AdminBottomNav({required this.currentIndex, required this.onTap});

  static const _items = [
    (icon: Icons.grid_view_outlined, label: 'Dashboard'),
    (icon: Icons.layers_outlined, label: 'Inventory'),
    (icon: Icons.bar_chart_outlined, label: 'Analytics'),
    (icon: Icons.apartment_outlined, label: 'Branches'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: kAdminShadow, blurRadius: 12, offset: Offset(0, -2))],
      ),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(_items.length, (i) {
            final selected = currentIndex == i;
            final color = selected ? kAdminBlue : kAdminCardGrey;
            return GestureDetector(
              onTap: () => onTap(i),
              behavior: HitTestBehavior.opaque,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: selected ? kAdminBlue.withValues(alpha: 0.12) : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(_items[i].icon, color: color, size: 22),
                  ),
                  const SizedBox(height: 4),
                  Text(_items[i].label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }
}
