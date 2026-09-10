import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sales_erp/app/navigation/app_navigation_config.dart';
import 'package:sales_erp/features/auth/domain/entities/auth_user.dart';

void main() {
  const salesUser = AuthUser(
    id: 1,
    username: 'sales.rep',
    email: 'sales@example.com',
    firstName: 'Sales',
    lastName: 'Rep',
    isStaff: false,
    isSuperuser: false,
    roleLevel: 20,
    permissions: {
      'invoices.view_invoice',
      'invoices.add_invoice',
    },
    role: AuthRole(
      id: 10,
      name: 'Sales Representative',
      level: 20,
      scope: 'site',
      requiresShift: true,
      description: '',
    ),
  );

  const warehouseUser = AuthUser(
    id: 2,
    username: 'warehouse.rep',
    email: 'warehouse@example.com',
    firstName: 'Warehouse',
    lastName: 'Rep',
    isStaff: false,
    isSuperuser: false,
    roleLevel: 20,
    permissions: {
      'products.view_product',
      'inventory.view_stockbalance',
    },
    role: AuthRole(
      id: 11,
      name: 'Warehouse Representative',
      level: 20,
      scope: 'site',
      requiresShift: true,
      description: '',
    ),
  );

  test('sales permissions expose sales but not unrelated feature tabs', () {
    final visibleIds = AppNavigationConfig.visibleFor(salesUser)
        .map((destination) => destination.id)
        .toSet();

    expect(visibleIds, contains(AppNavigationId.home));
    expect(visibleIds, contains(AppNavigationId.sales));
    expect(visibleIds, contains(AppNavigationId.more));
    expect(visibleIds, isNot(contains(AppNavigationId.products)));
    expect(visibleIds, isNot(contains(AppNavigationId.customers)));
  });

  test('inventory permissions expose products without exposing sales', () {
    final visibleIds = AppNavigationConfig.visibleFor(warehouseUser)
        .map((destination) => destination.id)
        .toSet();

    expect(visibleIds, contains(AppNavigationId.home));
    expect(visibleIds, contains(AppNavigationId.products));
    expect(visibleIds, contains(AppNavigationId.more));
    expect(visibleIds, isNot(contains(AppNavigationId.sales)));
    expect(visibleIds, isNot(contains(AppNavigationId.customers)));
  });

  test('superusers bypass permission-prefix filtering', () {
    final superuser = AuthUser(
      id: 3,
      username: 'admin',
      email: 'admin@example.com',
      firstName: 'System',
      lastName: 'Admin',
      isStaff: true,
      isSuperuser: true,
      roleLevel: 1000,
      permissions: const <String>{},
      role: const AuthRole(
        id: 1,
        name: 'Administrator',
        level: 1000,
        scope: 'company',
        requiresShift: false,
        description: '',
      ),
    );

    final visibleIds = AppNavigationConfig.visibleFor(superuser)
        .map((destination) => destination.id)
        .toSet();

    expect(visibleIds, containsAll(AppNavigationId.values));
  });

  test('navigation icons remain the existing Material icons', () {
    final salesDestination = AppNavigationConfig.destinations.firstWhere(
      (destination) => destination.id == AppNavigationId.sales,
    );

    expect(salesDestination.icon, Icons.receipt_long_outlined);
    expect(salesDestination.selectedIcon, Icons.receipt_long_rounded);
  });
}
