import 'package:flutter_test/flutter_test.dart';
import 'package:sales_erp/main.dart';

void main() {
  testWidgets('Sales ERP app starts', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const SalesErpApp(),
    );

    expect(find.text('Sales ERP'), findsOneWidget);
  });
}