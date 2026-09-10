import '../entities/auth_user.dart';

abstract interface class AuthenticationRepository {
  Future<AuthUser> login({
    required String identifier,
    required String password,
  });

  Future<AuthUser> fetchCurrentUser();

  Future<void> refresh();

  Future<void> logout();
}
