import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'secure_cookie_storage.dart';

import '../../app/config/api_config.dart';

class ApiClient {
  static const _cachedUserKey = 'cached_auth_user_v1';
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
    final secureStorage = storage ?? const FlutterSecureStorage();
    final cookieJar = PersistCookieJar(
      ignoreExpires: false,
      storage: SecureCookieStorage(secureStorage),
    );
    return ApiClient._(secureStorage, cookieJar);
  }

  Future<String> csrfToken() async {
    final response = await dio.get('/auth/csrf/');
    return response.data['csrf_token'] as String;
  }

  Future<void> saveAccessToken(String token) {
    return _storage.write(key: 'access_token', value: token);
  }

  Future<void> saveCurrentUserId(int userId) {
    return _storage.write(key: 'current_user_id', value: userId.toString());
  }

  Future<void> saveCachedUserJson(String value) {
    return _storage.write(key: _cachedUserKey, value: value);
  }

  Future<String?> getCachedUserJson() {
    return _storage.read(key: _cachedUserKey);
  }

  Future<int?> get currentUserId async {
    final value = await _storage.read(key: 'current_user_id');
    return int.tryParse(value ?? '');
  }

  Future<bool> hasAccessToken() async {
    final token = await _storage.read(key: 'access_token');
    return token != null && token.isNotEmpty;
  }

  Future<void> clearSession() async {
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'current_user_id');
    await _storage.delete(key: _cachedUserKey);
    await _cookieJar.deleteAll();
  }
}
