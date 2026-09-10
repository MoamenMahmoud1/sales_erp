import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../domain/entities/auth_user.dart';
import '../domain/repositories/authentication_repository.dart';

class AuthRepository implements AuthenticationRepository {
  final ApiClient client;

  const AuthRepository(this.client);

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
    await client.saveAccessToken(response.data['access'] as String);
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
    return AuthUser.fromJson(data);
  }

  @override
  Future<void> refresh() async {
    final csrf = await client.csrfToken();
    final response = await client.dio.post(
      '/auth/refresh/',
      options: Options(headers: {'X-CSRFToken': csrf}),
    );
    await client.saveAccessToken(response.data['access'] as String);
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
