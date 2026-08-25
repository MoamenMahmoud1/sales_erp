import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';

class AuthRepository {
  final ApiClient client;

  const AuthRepository(this.client);

  Future<void> login({
    required String identifier,
    required String password,
  }) async {
    final csrf = await client.csrfToken();
    final response = await client.dio.post(
      '/auth/login/',
      data: {'identifier': identifier, 'password': password},
      options: Options(headers: {'X-CSRFToken': csrf}),
    );
    await client.saveAccessToken(response.data['access'] as String);
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

  Future<void> refresh() async {
    final csrf = await client.csrfToken();
    final response = await client.dio.post(
      '/auth/refresh/',
      options: Options(headers: {'X-CSRFToken': csrf}),
    );
    await client.saveAccessToken(response.data['access'] as String);
  }

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
