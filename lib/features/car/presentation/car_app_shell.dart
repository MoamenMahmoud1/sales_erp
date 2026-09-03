import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/repositories/app_services.dart';
import '../../../core/storage/app_database.dart';
import '../../../core/ui/app_bottom_nav.dart';
import '../../../core/ui/dialogs.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/presentation/settings_page.dart';
import '../../products/presentation/products_page.dart';
import 'car_daily_dashboard_page.dart';
import 'car_payments_page.dart';
import 'car_reports_page.dart';
import 'car_trips_page.dart';

/// Car application shell.
///
/// It can be embedded in the full application or run as the root of the
/// standalone Car flavor. The standalone mode intentionally has no route back
/// to the full Sales ERP shell.
class CarAppShell extends StatefulWidget {
  final AppThemeController themeController;
  final VoidCallback? onLock;
  final VoidCallback? onReset;
  final bool standalone;

  const CarAppShell({
    super.key,
    required this.themeController,
    this.onLock,
    this.onReset,
    this.standalone = false,
  });

  @override
  State<CarAppShell> createState() => _CarAppShellState();
}

class _CarAppShellState extends State<CarAppShell> {
  late int _index;
  late final List<Widget> _pages;
  late final StreamSubscription<int> _tripDeletions;
  int _contentEpoch = 0;

  static const _items = [
    AppNavItem(icon: Icons.space_dashboard_outlined, selectedIcon: Icons.space_dashboard_rounded, label: 'Today'),
    AppNavItem(icon: Icons.local_shipping_outlined, selectedIcon: Icons.local_shipping_rounded, label: 'Trips'),
    AppNavItem(icon: Icons.payments_outlined, selectedIcon: Icons.payments_rounded, label: 'Payments'),
    AppNavItem(icon: Icons.inventory_2_outlined, selectedIcon: Icons.inventory_2_rounded, label: 'Products'),
    AppNavItem(icon: Icons.analytics_outlined, selectedIcon: Icons.analytics_rounded, label: 'Overview'),
  ];

  @override
  void initState() {
    super.initState();
    _index = 0;
    _pages = [
      CarDailyDashboardPage(onNavigate: _goTo),
      const CarTripsPage(),
      const CarPaymentsPage(),
      ProductsPage(carMode: true),
      const CarReportsPage(),
    ];
    _tripDeletions = AppServices.instance.carTripEvents.deletionStream.listen(_onTripDeleted);
  }

  @override
  void dispose() {
    _tripDeletions.cancel();
    super.dispose();
  }

  void _onTripDeleted(int _) {
    if (!mounted) return;
    setState(() => _contentEpoch++);
  }

  void _goTo(int index) {
    if (!mounted) return;
    setState(() => _index = index);
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SettingsPage(
          themeController: widget.themeController,
          onLock: widget.onLock,
          onReset: widget.onReset ?? _resetCarData,
          showOperations: false,
          resetSubtitle: 'Clear local Car app data',
        ),
      ),
    );
  }

  Future<void> _resetCarData() async {
    final confirmed = await showConfirmDialog(
      context: context,
      title: 'Reset Car data?',
      message: 'This deletes all local records used by the Car app. This cannot be undone.',
      confirmLabel: 'Reset',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    await AppDatabase.resetDatabase();
    if (!mounted) return;
    setState(() => _contentEpoch++);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Car local data reset.')),
    );
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

    final content = isWide
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
                child: IndexedStack(
                  key: ValueKey(_contentEpoch),
                  index: _index,
                  children: _pages,
                ),
              ),
            ],
          )
        : IndexedStack(
            key: ValueKey(_contentEpoch),
            index: _index,
            children: _pages,
          );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Car Sales'),
        leading: widget.standalone
            ? null
            : IconButton(
                tooltip: 'Back to Sales ERP',
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: _close,
              ),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_rounded),
            onPressed: _openSettings,
          ),
        ],
      ),
      body: content,
      bottomNavigationBar: !isWide && !keyboardOpen
          ? SafeArea(
              minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: AppBottomNav(index: _index, items: _items, onChanged: _goTo),
            )
          : null,
    );
  }
}
