import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:sales_erp/core/repositories/app_services.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('mobile API integration: authenticate and load dashboard', (tester) async {
    final password = const String.fromEnvironment('E2E_PASSWORD');
    expect(password, isNotEmpty);

    final services = AppServices.instance;
    await services.init();

    final user = await services.authRepository.login(
      identifier: 'e2e_admin',
      password: password,
    );

    expect(user.username, 'e2e_admin');
    expect(user.isSuperuser, isTrue);

    final snapshot = await services.dashboardRepository.loadSnapshot();
    expect(snapshot.productCount, greaterThan(0));
    expect(snapshot.customerCount, greaterThan(0));

    await services.authRepository.logout();
  });
}
