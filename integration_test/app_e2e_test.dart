import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sales_erp/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('mobile production smoke: login and load dashboard', (tester) async {
    await app.main();
    await tester.pumpAndSettle(const Duration(seconds: 3));

    expect(find.text('Sales ERP'), findsOneWidget);

    final fields = find.byType(TextFormField);
    expect(fields, findsNWidgets(2));

    await tester.enterText(fields.at(0), 'e2e_admin');
    await tester.enterText(fields.at(1), const String.fromEnvironment('E2E_PASSWORD'));
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));

    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 500));
      if (find.text('Sales overview').evaluate().isNotEmpty) break;
    }

    expect(find.text('Sales overview'), findsOneWidget);
    expect(find.text('Recent sales'), findsOneWidget);
  });
}
