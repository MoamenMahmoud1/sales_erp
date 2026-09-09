import 'package:flutter/material.dart';

import '../../features/car/presentation/car_app_shell.dart';
import '../../features/customers/presentation/customers_page.dart';
import '../../features/dashboard/presentation/dashboard_controller.dart';
import '../../features/dashboard/presentation/dashboard_page.dart';
import '../../features/products/presentation/products_page.dart';
import '../../features/sales/presentation/invoices_page.dart';
import '../data/demo_data_seeder.dart';
import '../repositories/app_services.dart';
import '../storage/app_database.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../ui/app_bottom_nav.dart';
import '../ui/dialogs.dart';
import 'settings_page.dart';

/// Primary Sales ERP navigation shell.
///
/// It owns navigation and app-level actions only. Feature screens receive
/// their required controllers/repositories instead of reaching into storage.
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
  late final DashboardController _dashboardController;
  late final List<Widget> _pages;

  static const _navigationItems = [
    AppNavItem(
      icon: Icons.space_dashboard_outlined,
      selectedIcon: Icons.space_dashboard_rounded,
      label: 'Home',
    ),
    AppNavItem(
      icon: Icons.receipt_long_outlined,
      selectedIcon: Icons.receipt_long_rounded,
      label: 'Sales',
    ),
    AppNavItem(
      icon: Icons.inventory_2_outlined,
      selectedIcon: Icons.inventory_2_rounded,
      label: 'Products',
    ),
    AppNavItem(
      icon: Icons.people_outline_rounded,
      selectedIcon: Icons.people_rounded,
      label: 'Customers',
    ),
    AppNavItem(
      icon: Icons.more_horiz_rounded,
      selectedIcon: Icons.tune_rounded,
      label: 'More',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _dashboardController = DashboardController(
      repository: AppServices.instance.dashboardRepository,
    );
    _pages = [
      DashboardPage(
        onNavigateTo: _goToTab,
        controller: _dashboardController,
      ),
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

  @override
  void dispose() {
    _dashboardController.dispose();
    super.dispose();
  }

  void _goToTab(int index) => setState(() => _index = index);

  Future<void> _openCarApp() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CarAppShell(
          themeController: widget.themeController,
          onLock: widget.onLock,
          onReset: _resetDeviceData,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _resetDeviceData() async {
    final confirmed = await showConfirmDialog(
      context: context,
      title: 'Reset device data?',
      message:
          'This deletes all local records and re-seeds the demo dataset. This cannot be undone.',
      confirmLabel: 'Reset',
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    await AppDatabase.resetDatabase();
    await DemoDataSeeder().seedIfNeeded();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Local data reset and demo data re-seeded.')),
    );
    _dashboardController.load();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isWide = MediaQuery.sizeOf(context).width >= 840;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom >= 120;

    if (isWide) {
      return Scaffold(
        backgroundColor: colors.background,
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _index,
              onDestinationSelected: _goToTab,
              backgroundColor: colors.surfaceMuted,
              indicatorColor: colors.primaryContainer,
              labelType: NavigationRailLabelType.selected,
              destinations: [
                for (final item in _navigationItems)
                  NavigationRailDestination(
                    icon: Icon(item.icon),
                    selectedIcon: Icon(item.selectedIcon),
                    label: Text(item.label),
                  ),
              ],
            ),
            Expanded(
              child: IndexedStack(index: _index, children: _pages),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: colors.background,
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
                child: AppBottomNav(
                  index: _index,
                  items: _navigationItems,
                  onChanged: _goToTab,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
