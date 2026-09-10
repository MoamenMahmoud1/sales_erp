import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sales_erp/app/app.dart';
import 'package:sales_erp/core/security/app_lock_controller.dart';
import 'package:sales_erp/core/theme/app_theme.dart';

void main() {
  testWidgets('Sales ERP root renders the supplied home', (
    WidgetTester tester,
  ) async {
    final lockController = AppLockController();
    final themeController = AppThemeController();
    addTearDown(lockController.dispose);

    await tester.pumpWidget(
      SalesErpApp(
        lockController: lockController,
        themeController: themeController,
        homeBuilder: (themeController, onLock) => const Scaffold(
          body: SizedBox(key: ValueKey('sales-home')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('sales-home')), findsOneWidget);
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).title,
      'Sales ERP',
    );
  });
}
