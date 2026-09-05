import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sales_erp/app/app.dart';
import 'package:sales_erp/core/security/app_lock_controller.dart';
import 'package:sales_erp/core/theme/app_theme.dart';

void main() {
  testWidgets('Sales ERP app starts', (
    WidgetTester tester,
  ) async {
    final lockController = AppLockController();
    final themeController = AppThemeController();
    addTearDown(lockController.dispose);

    await tester.pumpWidget(
      SalesErpApp(
        lockController: lockController,
        themeController: themeController,
        homeBuilder: (themeController, onLock) => const SizedBox.shrink(),
      ),
    );

    expect(find.byType(SalesErpApp), findsOneWidget);
  });
}
