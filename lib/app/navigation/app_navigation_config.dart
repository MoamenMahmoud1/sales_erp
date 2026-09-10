import '../../features/auth/domain/entities/auth_user.dart';

class AppNavigationDestination {
  final AppNavigationId id;
  final String label;
  final Object icon;
  final Object selectedIcon;
  final List<String> permissionPrefixes;
  final bool requiresRole;

  const AppNavigationDestination({
    required this.id,
    required this.label,
    required this.icon,
    required this.selectedIcon,
    this.permissionPrefixes = const [],
    this.requiresRole = false,
  });

  bool isVisibleFor(AuthUser user) {
    if (requiresRole && user.role == null && !user.isStaff && !user.isSuperuser) {
      return false;
    }
    if (permissionPrefixes.isEmpty) return true;
    return user.hasAnyPermissionWithPrefix(permissionPrefixes);
  }
}

enum AppNavigationId {
  home,
  sales,
  products,
  customers,
  more,
}

class AppNavigationConfig {
  const AppNavigationConfig._();

  static const destinations = [
    AppNavigationDestination(
      id: AppNavigationId.home,
      icon: 'space_dashboard_outlined',
      selectedIcon: 'space_dashboard_rounded',
      label: 'Home',
      requiresRole: true,
    ),
    AppNavigationDestination(
      id: AppNavigationId.sales,
      icon: 'receipt_long_outlined',
      selectedIcon: 'receipt_long_rounded',
      label: 'Sales',
      permissionPrefixes: ['sales.'],
    ),
    AppNavigationDestination(
      id: AppNavigationId.products,
      icon: 'inventory_2_outlined',
      selectedIcon: 'inventory_2_rounded',
      label: 'Products',
      permissionPrefixes: ['products.', 'inventory.'],
    ),
    AppNavigationDestination(
      id: AppNavigationId.customers,
      icon: 'people_outline_rounded',
      selectedIcon: 'people_rounded',
      label: 'Customers',
      permissionPrefixes: ['customers.', 'crm.'],
    ),
    AppNavigationDestination(
      id: AppNavigationId.more,
      icon: 'more_horiz_rounded',
      selectedIcon: 'tune_rounded',
      label: 'More',
      requiresRole: true,
    ),
  ];

  static List<AppNavigationDestination> visibleFor(AuthUser user) {
    return [
      for (final destination in destinations)
        if (destination.isVisibleFor(user)) destination,
    ];
  }
}
