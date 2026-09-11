import 'package:flutter/material.dart';

import '../../app/navigation/app_navigation_config.dart';
import '../../features/approvals/presentation/approval_center_controller.dart';
import '../../features/approvals/presentation/approval_center_page.dart';
import '../../features/auth/domain/entities/auth_user.dart';
import '../../features/customers/presentation/customers_page.dart';
import '../../features/dashboard/presentation/dashboard_controller.dart';
import '../../features/dashboard/presentation/dashboard_page.dart';
import '../../features/notifications/presentation/notifications_controller.dart';
import '../../features/notifications/presentation/notifications_page.dart';
import '../../features/products/presentation/products_page.dart';
import '../../features/representative/presentation/representative_vehicle_page.dart';
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
/// Navigation destinations are filtered from the authenticated user's RBAC
/// payload while preserving the existing navigation widgets and styling.
class AppShell extends StatefulWidget {
  final AuthUser user;
  final AppThemeController themeController;
  final VoidCallback onLock;
  final int initialIndex;

  const AppShell({
    super.key,
    required this.user,
    required this.themeController,
    required this.onLock,
    this.initialIndex = 0,
  });

  @override
  State<AppShell> createState() => _AppShellState();
}

class _NavigationEntry {
  final AppNavigationDestination destination;
  final Widget page;

  const _NavigationEntry({
    required this.destination,
    required this.page,
  });
}

class _AppShellState extends State<AppShell> {
  late int _selectedTabIndex;
  late final DashboardController _dashboardController;
  late final NotificationsController _notificationsController;
  late final ApprovalCenterController _approvalCenterController;
  late final List<_NavigationEntry> _navigationEntries;

  bool get _canOpenApprovalCenter {
    return widget.user.isSuperuser ||
        widget.user.hasPermission('inventory.approve_stock_transfer') ||
        widget.user.hasPermission('invoices.change_invoice') ||
        widget.user.hasPermission('invoices.delete_invoice');
  }

  @override
  void initState() {
    super.initState();
    _dashboardController = DashboardController(
      repository: AppServices.instance.dashboardRepository,
    );
    _notificationsController = NotificationsController(
      repository: AppServices.instance.notificationRepository,
    );
    _approvalCenterController = ApprovalCenterController(
      repository: AppServices.instance.approvalRepository,
    );

    final homeDestination = _destinationFor(AppNavigationId.home);
    final salesDestination = _destinationFor(AppNavigationId.sales);
    final vehicleDestination = _destinationFor(AppNavigationId.vehicle);
    final productsDestination = _destinationFor(AppNavigationId.products);
    final customersDestination = _destinationFor(AppNavigationId.customers);
    final moreDestination = _destinationFor(AppNavigationId.more);

    final allEntries = [
      _NavigationEntry(
        destination: homeDestination,
        page: DashboardPage(
          onNavigateTo: _goToLegacyNavigationIndex,
          canNavigateTo: _canNavigateToLegacyNavigationIndex,
          controller: _dashboardController,
        ),
      ),
      _NavigationEntry(
        destination: salesDestination,
        page: const InvoicesPage(),
      ),
      _NavigationEntry(
        destination: vehicleDestination,
        page: RepresentativeVehiclePage(
          canSell: widget.user.hasPermission('invoices.add_invoice') &&
              widget.user.hasPermission('invoices.confirm_invoice'),
        ),
      ),
      _NavigationEntry(
        destination: productsDestination,
        page: const ProductsPage(),
      ),
      _NavigationEntry(
        destination: customersDestination,
        page: const CustomersPage(),
      ),
      _NavigationEntry(
        destination: moreDestination,
        page: SettingsPage(
          themeController: widget.themeController,
          onLock: widget.onLock,
          onReset: _resetDeviceData,
          onOpenNotifications: _openNotifications,
          onOpenApprovals: _canOpenApprovalCenter ? _openApprovalCenter : null,
          showOperations: false,
          showApprovalCenter: _canOpenApprovalCenter,
        ),
      ),
    ];

    final visibleIds = AppNavigationConfig.visibleFor(widget.user)
        .map((destination) => destination.id)
        .toSet();

    _navigationEntries = [
      for (final entry in allEntries)
        if (visibleIds.contains(entry.destination.id)) entry,
    ];

    final boundedInitialIndex = widget.initialIndex < 0
        ? 0
        : widget.initialIndex >= AppNavigationId.values.length
            ? AppNavigationId.values.length - 1
            : widget.initialIndex;
    final initialDestination = AppNavigationId.values[boundedInitialIndex];
    final initialVisibleIndex = _navigationEntries.indexWhere(
      (entry) => entry.destination.id == initialDestination,
    );
    _selectedTabIndex = initialVisibleIndex >= 0 ? initialVisibleIndex : 0;
  }

  @override
  void dispose() {
    _dashboardController.dispose();
    _notificationsController.dispose();
    _approvalCenterController.dispose();
    super.dispose();
  }

  AppNavigationDestination _destinationFor(AppNavigationId id) {
    return AppNavigationConfig.destinations.firstWhere(
      (destination) => destination.id == id,
    );
  }

  int? _visibleIndexForLegacyIndex(int legacyIndex) {
    if (legacyIndex < 0 || legacyIndex >= AppNavigationId.values.length) {
      return null;
    }

    final destinationId = AppNavigationId.values[legacyIndex];
    final visibleIndex = _navigationEntries.indexWhere(
      (entry) => entry.destination.id == destinationId,
    );
    return visibleIndex >= 0 ? visibleIndex : null;
  }

  bool _canNavigateToLegacyNavigationIndex(int legacyIndex) {
    return _visibleIndexForLegacyIndex(legacyIndex) != null;
  }

  void _goToLegacyNavigationIndex(int legacyIndex) {
    final visibleIndex = _visibleIndexForLegacyIndex(legacyIndex);
    if (visibleIndex == null) return;
    _goToTab(visibleIndex);
  }

  void _goToTab(int index) {
    if (index < 0 || index >= _navigationEntries.length) return;
    if (_selectedTabIndex == index) return;
    setState(() => _selectedTabIndex = index);
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NotificationsPage(controller: _notificationsController),
      ),
    );
  }

  Future<void> _openApprovalCenter() async {
    if (!_canOpenApprovalCenter) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ApprovalCenterPage(controller: _approvalCenterController),
      ),
    );
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
    await DemoDataSeeder().seedIfNeeded(force: true);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Local data reset and demo data re-seeded.')),
    );
    _dashboardController.load();
    setState(() {});
  }

  List<AppNavItem> get _navigationItems {
    return [
      for (final entry in _navigationEntries)
        AppNavItem(
          icon: entry.destination.icon,
          selectedIcon: entry.destination.selectedIcon,
          label: entry.destination.label,
        ),
    ];
  }

  List<Widget> get _navigationPages {
    return [for (final entry in _navigationEntries) entry.page];
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isWide = MediaQuery.sizeOf(context).width >= 840;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom >= 120;
    final navigationItems = _navigationItems;
    final navigationPages = _navigationPages;

    if (isWide) {
      return Scaffold(
        backgroundColor: colors.background,
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _selectedTabIndex,
              onDestinationSelected: _goToTab,
              backgroundColor: colors.surfaceMuted,
              indicatorColor: colors.primaryContainer,
              labelType: NavigationRailLabelType.selected,
              destinations: [
                for (final item in navigationItems)
                  NavigationRailDestination(
                    icon: Icon(item.icon),
                    selectedIcon: Icon(item.selectedIcon),
                    label: Text(item.label),
                  ),
              ],
            ),
            Expanded(
              child: IndexedStack(
                index: _selectedTabIndex,
                children: navigationPages,
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: colors.background,
      body: Stack(
        children: [
          IndexedStack(
            index: _selectedTabIndex,
            children: navigationPages,
          ),
          if (!keyboardOpen)
            Positioned(
              left: 16,
              right: 16,
              bottom: 0,
              child: SafeArea(
                minimum: const EdgeInsets.only(bottom: 12),
                child: AppBottomNav(
                  index: _selectedTabIndex,
                  items: navigationItems,
                  onChanged: _goToTab,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
