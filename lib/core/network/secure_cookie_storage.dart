import 'dart:convert';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureCookieStorage implements Storage {
  static const _prefix = 'http_cookie_';

  final FlutterSecureStorage _storage;

  const SecureCookieStorage(this._storage);

  String _storageKey(String key) =>
      _prefix + base64Url.encode(utf8.encode(key));

  @override
  Future<void> init(bool persistSession, bool ignoreExpires) async {}

  @override
  Future<String?> read(String key) {
    return _storage.read(key: _storageKey(key));
  }

  @override
  Future<void> write(String key, String value) {
    return _storage.write(key: _storageKey(key), value: value);
  }

  @override
  Future<void> delete(String key) {
    return _storage.delete(key: _storageKey(key));
  }

  @override
  Future<void> deleteAll(List<String> keys) async {
    await Future.wait(keys.map(delete));
  }
}
