import 'package:flutter/material.dart';

import '../../features/car/presentation/car_app_shell.dart';
import '../../features/customers/presentation/customers_page.dart';
import '../../features/products/presentation/products_page.dart';
import '../../features/sales/presentation/invoices_page.dart';
import '../data/demo_data_seeder.dart';
import '../storage/app_database.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../ui/app_bottom_nav.dart';
import '../ui/dialogs.dart';
import 'dashboard_page.dart';
import 'settings_page.dart';

/// The primary Sales ERP shell.
class AppShell extends StatefulWidget {
  final AppThemeController themeController;
  final VoidCallback onLock;
  final int initialIndex;

  const AppShell({
    super.key,
    required this.themeController,
    required this.onLock,
    this.initialIndex = 0,
  });

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late int _index;
  late final List<Widget> _pages;

  static const _items = [
    AppNavItem(icon: Icons.space_dashboard_outlined, selectedIcon: Icons.space_dashboard_rounded, label: 'Home'),
    AppNavItem(icon: Icons.receipt_long_outlined, selectedIcon: Icons.receipt_long_rounded, label: 'Sales'),
    AppNavItem(icon: Icons.inventory_2_outlined, selectedIcon: Icons.inventory_2_rounded, label: 'Products'),
    AppNavItem(icon: Icons.people_outline_rounded, selectedIcon: Icons.people_rounded, label: 'Customers'),
    AppNavItem(icon: Icons.more_horiz_rounded, selectedIcon: Icons.tune_rounded, label: 'More'),
  ];

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _pages = [
      DashboardPage(onNavigateTo: _goToTab, themeController: widget.themeController),
      const InvoicesPage(),
      const ProductsPage(),
      const CustomersPage(),
      SettingsPage(
        themeController: widget.themeController,
        onLock: widget.onLock,
        onReset: _resetDeviceData,
        onOpenCarApp: _openCarApp,
      ),
    ];
  }

  void _goToTab(int index) => setState(() => _index = index);

  Future<void> _openCarApp() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CarAppShell(themeController: widget.themeController),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _resetDeviceData() async {
    final confirmed = await showConfirmDialog(
      context: context,
      title: 'Reset device data?',
      message: 'This deletes all local records and re-seeds the demo dataset. This cannot be undone.',
      confirmLabel: 'Reset',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    await AppDatabase.resetDatabase();
    await DemoDataSeeder().seedIfNeeded();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Local data reset & demo data re-seeded.')),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isWide = MediaQuery.sizeOf(context).width >= 840;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom >= 120;

    if (isWide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _index,
              onDestinationSelected: _goToTab,
              backgroundColor: colors.surfaceMuted,
              indicatorColor: colors.primaryContainer,
              labelType: NavigationRailLabelType.selected,
              destinations: [
                for (final item in _items)
                  NavigationRailDestination(
                    icon: Icon(item.icon),
                    selectedIcon: Icon(item.selectedIcon),
                    label: Text(item.label),
                  ),
              ],
            ),
            Expanded(child: IndexedStack(index: _index, children: _pages)),
          ],
        ),
        backgroundColor: colors.background,
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(index: _index, children: _pages),
          if (!keyboardOpen)
            Positioned(
              left: 16,
              right: 16,
              bottom: 0,
              child: SafeArea(
                minimum: const EdgeInsets.only(bottom: 12),
                child: AppBottomNav(index: _index, items: _items, onChanged: _goToTab),
              ),
            ),
        ],
      ),
      backgroundColor: colors.background,
    );
  }
}
