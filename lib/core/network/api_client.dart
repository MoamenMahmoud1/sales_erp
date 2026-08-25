import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

import '../../app/config/api_config.dart';

class ApiClient {
  final FlutterSecureStorage _storage;
  final PersistCookieJar _cookieJar;
  late final Dio dio;

  ApiClient._(this._storage, this._cookieJar) {
    dio = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      contentType: Headers.jsonContentType,
      headers: {'Accept': 'application/json'},
    ));
    dio.interceptors.add(CookieManager(_cookieJar));
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final access = await _storage.read(key: 'access_token');
        if (access != null && access.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $access';
        }
        handler.next(options);
      },
    ));
  }

  static Future<ApiClient> create({
    FlutterSecureStorage? storage,
  }) async {
    final directory = await getApplicationSupportDirectory();
    final cookieJar = PersistCookieJar(
      ignoreExpires: false,
      storage: FileStorage('${directory.path}/http_cookies/'),
    );
    return ApiClient._(
      storage ?? const FlutterSecureStorage(),
      cookieJar,
    );
  }

  Future<String> csrfToken() async {
    final response = await dio.get('/auth/csrf/');
    return response.data['csrf_token'] as String;
  }

  Future<void> saveAccessToken(String token) {
    return _storage.write(key: 'access_token', value: token);
  }

  Future<bool> hasAccessToken() async {
    final token = await _storage.read(key: 'access_token');
    return token != null && token.isNotEmpty;
  }

  Future<void> clearSession() async {
    await _storage.delete(key: 'access_token');
    await _cookieJar.deleteAll();
  }
}
