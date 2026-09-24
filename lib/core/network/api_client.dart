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
  String? _accessToken;
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
        final access = _accessToken;
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

    // Remove the legacy persisted access token from older app versions.
    await secureStorage.delete(key: 'access_token');

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

  void setAccessToken(String token) {
    final value = token.trim();
    if (value.isEmpty) {
      throw ArgumentError('Access token must not be empty.');
    }
    _accessToken = value;
  }

  void clearAccessToken() {
    _accessToken = null;
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

  Future<bool> hasActiveSessionCookie() async {
    final refreshUri = Uri.parse(ApiConfig.baseUrl + '/auth/refresh/');
    final cookies = await _cookieJar.loadForRequest(refreshUri);
    return cookies.any((cookie) => cookie.name == 'refresh_token');
  }

  Future<void> clearSession() async {
    clearAccessToken();
    await _storage.delete(key: 'current_user_id');
    await _storage.delete(key: _cachedUserKey);
    await _cookieJar.deleteAll();
  }
}
