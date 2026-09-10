import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/repositories/app_services.dart';
import '../../../core/ui/app_bottom_nav.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/featured_card_theme.dart';
import '../../../core/storage/app_database.dart';
import '../../../core/ui/dialogs.dart';
import '../../../core/presentation/settings_page.dart';
import '../../products/presentation/products_page.dart';
import 'car_daily_dashboard_page.dart';
import 'car_payments_page.dart';
import 'car_reports_page.dart';
import 'car_trips_page.dart';

/// Car application navigation shell.
///
/// It can be embedded in the full application or run as the root of the
/// standalone Car flavor. Standalone mode intentionally has no route back to
/// the full Sales ERP shell.
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
  late int _selectedTabIndex;
  late final StreamSubscription<int> _tripDeletions;
  int _contentRevision = 0;

  static const _navigationItems = [
    AppNavItem(
      icon: Icons.space_dashboard_outlined,
      selectedIcon: Icons.space_dashboard_rounded,
      label: 'Today',
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
      label: 'Overview',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _selectedTabIndex = 0;
    _tripDeletions =
        AppServices.instance.carTripEvents.deletionStream.listen(_onTripDeleted);
  }

  @override
  void dispose() {
    _tripDeletions.cancel();
    super.dispose();
  }

  void _onTripDeleted(int _) {
    if (!mounted) return;
    setState(() => _contentRevision++);
  }

  void _goToTab(int index) {
    if (!mounted || index < 0 || index >= _navigationItems.length) return;
    setState(() => _selectedTabIndex = index);
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
      message:
          'This deletes all local records used by the Car app. This cannot be undone.',
      confirmLabel: 'Reset',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    await AppDatabase.resetDatabase();
    if (!mounted) return;
    setState(() => _contentRevision++);
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

  Widget _buildSelectedPage() {
    switch (_selectedTabIndex) {
      case 0:
        return Theme(
          data: Theme.of(context).copyWith(
            extensions: [
              ...Theme.of(context).extensions.values.where(
                    (extension) => extension is! FeaturedCardTheme,
                  ),
              const FeaturedCardTheme(enabled: true),
            ],
          ),
          child: CarDailyDashboardPage(onNavigate: _goToTab),
        );
      case 1:
        return const CarTripsPage();
      case 2:
        return const CarPaymentsPage();
      case 3:
        return ProductsPage(carMode: true);
      case 4:
        return const CarReportsPage();
      default:
        return CarDailyDashboardPage(onNavigate: _goToTab);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isWide = MediaQuery.sizeOf(context).width >= 840;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom >= 120;
    final page = KeyedSubtree(
      key: ValueKey('car-page-$_selectedTabIndex-$_contentRevision'),
      child: _buildSelectedPage(),
    );

    final content = isWide
        ? Row(
            children: [
              NavigationRail(
                selectedIndex: _selectedTabIndex,
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
              Expanded(child: page),
            ],
          )
        : page;

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
              child: AppBottomNav(
                index: _selectedTabIndex,
                items: _navigationItems,
                onChanged: _goToTab,
              ),
            )
          : null,
    );
  }
}
