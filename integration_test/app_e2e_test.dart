import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('mobile API integration: csrf, login, session and dashboard', (tester) async {
    final baseUrl = const String.fromEnvironment('API_BASE_URL');
    final password = const String.fromEnvironment('E2E_PASSWORD');

    expect(baseUrl, isNotEmpty);
    expect(password, isNotEmpty);

    final cookieJar = CookieJar();
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(seconds: 10),
        headers: const {'Accept': 'application/json'},
      ),
    )..interceptors.add(CookieManager(cookieJar));

    final health = await dio.get('/health/ready/');
    expect(health.statusCode, 200);

    final csrfResponse = await dio.get('/auth/csrf/');
    final csrfToken = csrfResponse.data['csrf_token'] as String;
    expect(csrfToken, isNotEmpty);

    final loginResponse = await dio.post(
      '/auth/login/',
      data: {
        'identifier': 'e2e_admin',
        'password': password,
      },
      options: Options(
        headers: {
          'X-CSRFToken': csrfToken,
        },
        contentType: Headers.jsonContentType,
      ),
      queryParameters: const {},
    );
    final accessToken = loginResponse.data['access'] as String;
    expect(accessToken, isNotEmpty);

    final authOptions = Options(
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    final me = await dio.get('/auth/me/', options: authOptions);
    expect(me.statusCode, 200);
    expect(me.data['username'], 'e2e_admin');
    expect(me.data['is_superuser'], true);

    final dashboard = await dio.get(
      '/accounting/analytics/overview/',
      options: authOptions,
    );
    expect(dashboard.statusCode, 200);

    final data = Map<String, dynamic>.from(dashboard.data as Map);
    final counts = Map<String, dynamic>.from(data['counts'] as Map);
    expect((counts['product_count'] as num).toInt(), greaterThan(0));
    expect((counts['customer_count'] as num).toInt(), greaterThan(0));
  });
}
