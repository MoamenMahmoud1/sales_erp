import 'package:flutter/material.dart';

import '../../../core/ui/app_bottom_nav.dart';
import '../../../core/ui/dialogs.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../products/presentation/products_page.dart';
import 'car_dashboard_page.dart';
import 'car_payments_page.dart';
import 'car_reports_page.dart';
import 'car_trips_page.dart';

/// Standalone Car application shell. It shares the app's design system but
/// keeps navigation independent from normal customer sales/invoices.
class CarAppShell extends StatefulWidget {
  final AppThemeController? themeController;

  const CarAppShell({super.key, this.themeController});

  @override
  State<CarAppShell> createState() => _CarAppShellState();
}

class _CarAppShellState extends State<CarAppShell> {
  late int _index;
  late final List<Widget> _pages;

  static const _items = [
    AppNavItem(
      icon: Icons.space_dashboard_outlined,
      selectedIcon: Icons.space_dashboard_rounded,
      label: 'Home',
    ),
    AppNavItem(
      icon: Icons.local_shipping_outlined,
      selectedIcon: Icons.local_shipping_rounded,
      label: 'Trips',
    ),
    AppNavItem(
      icon: Icons.payments_outlined,
      selectedIcon: Icons.payments_rounded,
      label: 'Payments',
    ),
    AppNavItem(
      icon: Icons.inventory_2_outlined,
      selectedIcon: Icons.inventory_2_rounded,
      label: 'Products',
    ),
    AppNavItem(
      icon: Icons.analytics_outlined,
      selectedIcon: Icons.analytics_rounded,
      label: 'Reports',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _index = 0;
    _pages = [
      CarDashboardPage(onNavigate: _goTo),
      const CarTripsPage(),
      const CarPaymentsPage(),
      const ProductsPage(),
      const CarReportsPage(),
    ];
  }

  void _goTo(int index) {
    if (!mounted) return;
    setState(() => _index = index);
  }

  Future<void> _close() async {
    final confirmed = await showConfirmDialog(
      context: context,
      title: 'Leave Car App?',
      message: 'Return to the main Sales ERP application.',
      confirmLabel: 'Leave',
    );
    if (confirmed && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isWide = MediaQuery.sizeOf(context).width >= 840;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom >= 120;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Car Sales'),
        leading: IconButton(
          tooltip: 'Back to Sales ERP',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: _close,
        ),
      ),
      body: isWide
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: _index,
                  onDestinationSelected: _goTo,
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
                Expanded(
                  child: IndexedStack(index: _index, children: _pages),
                ),
              ],
            )
          : IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: !isWide && !keyboardOpen
          ? SafeArea(
              minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: AppBottomNav(
                index: _index,
                items: _items,
                onChanged: _goTo,
              ),
            )
          : null,
    );
  }
}
