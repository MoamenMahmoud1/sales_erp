import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/app_database.dart';
import '../domain/entities/auth_user.dart';
import '../domain/repositories/authentication_repository.dart';

class AuthRepository implements AuthenticationRepository {
  static const offlineSessionLifetime = Duration(hours: 24);

  final ApiClient client;
  Future<void>? _refreshOperation;

  const AuthRepository(this.client);

  @override
  Future<bool> hasActiveSession() {
    return client.hasActiveSessionCookie();
  }

  @override
  Future<AuthUser> login({
    required String identifier,
    required String password,
  }) async {
    final csrf = await client.csrfToken();
    final response = await client.dio.post(
      '/auth/login/',
      data: {'identifier': identifier, 'password': password},
      options: Options(headers: {'X-CSRFToken': csrf}),
    );
    client.setAccessToken(response.data['access'] as String);
    return fetchCurrentUser();
  }

  Future<void> signup({
    required String username,
    required String email,
    required String firstName,
    required String lastName,
    required String password,
    required String passwordConfirm,
  }) async {
    await client.dio.post('/auth/signup/', data: {
      'username': username,
      'email': email,
      'first_name': firstName,
      'last_name': lastName,
      'password': password,
      'password_confirm': passwordConfirm,
    });
  }

  @override
  Future<AuthUser> fetchCurrentUser() async {
    final response = await client.dio.get('/auth/me/');
    final data = Map<String, dynamic>.from(response.data as Map);
    final user = AuthUser.fromJson(data);
    await AppDatabase.prepareForUser(user.id);
    await client.saveCurrentUserId(user.id);
    await cacheUser(user);
    await client.saveSessionValidatedAt(DateTime.now().toUtc());
    return user;
  }

  @override
  Future<void> refresh() {
    final inFlight = _refreshOperation;
    if (inFlight != null) return inFlight;

    final operation = _refreshAccess();
    _refreshOperation = operation;
    return operation.whenComplete(() {
      if (identical(_refreshOperation, operation)) {
        _refreshOperation = null;
      }
    });
  }

  Future<void> _refreshAccess() async {
    final csrf = await client.csrfToken();
    final response = await client.dio.post(
      '/auth/refresh/',
      options: Options(headers: {'X-CSRFToken': csrf}),
    );
    client.setAccessToken(response.data['access'] as String);
    await client.saveSessionValidatedAt(DateTime.now().toUtc());
  }

  @override
  Future<void> logout() async {
    try {
      final csrf = await client.csrfToken();
      await client.dio.post(
        '/auth/logout/',
        options: Options(headers: {'X-CSRFToken': csrf}),
      );
    } finally {
      await client.clearSession();
    }
  }

  @override
  Future<AuthUser?> getCachedUser() async {
    final raw = await client.getCachedUserJson();
    if (raw == null || raw.isEmpty) return null;

    final validatedAt = await client.sessionValidatedAt;
    if (validatedAt == null ||
        DateTime.now().toUtc().difference(validatedAt.toUtc()) >
            offlineSessionLifetime) {
      return null;
    }

    try {
      final decoded = jsonDecode(raw);
      final user = AuthUser.fromJson(Map<String, dynamic>.from(decoded as Map));
      await AppDatabase.prepareForUser(user.id);
      return user;
    } catch (_) {
      await client.clearSession();
      return null;
    }
  }

  @override
  Future<void> cacheUser(AuthUser user) {
    return client.saveCachedUserJson(jsonEncode(user.toJson()));
  }

  @override
  Future<void> clearSession() {
    return client.clearSession();
  }

  Future<void> requestPasswordReset(String email) {
    return client.dio.post(
      '/auth/password-reset/',
      data: {'email': email},
    );
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String newPasswordConfirm,
  }) async {
    final csrf = await client.csrfToken();
    await client.dio.post(
      '/auth/password/change/',
      data: {
        'current_password': currentPassword,
        'new_password': newPassword,
        'new_password_confirm': newPasswordConfirm,
      },
      options: Options(headers: {'X-CSRFToken': csrf}),
    );
    await client.clearSession();
  }
}
