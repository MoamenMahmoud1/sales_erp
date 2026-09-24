import 'package:flutter_test/flutter_test.dart';

import 'package:sales_erp/features/auth/domain/entities/auth_user.dart';
import 'package:sales_erp/features/auth/domain/repositories/authentication_repository.dart';
import 'package:sales_erp/features/auth/presentation/auth_controller.dart';

class FakeAuthenticationRepository implements AuthenticationRepository {
  final AuthUser user;
  bool activeSession = true;
  bool cachedUserAvailable = false;
  int refreshCalls = 0;
  int fetchCalls = 0;
  int clearCalls = 0;

  FakeAuthenticationRepository(this.user);

  @override
  Future<bool> hasActiveSession() async => activeSession;

  @override
  Future<AuthUser> login({
    required String identifier,
    required String password,
  }) async => user;

  @override
  Future<AuthUser> fetchCurrentUser() async {
    fetchCalls++;
    return user;
  }

  @override
  Future<void> refresh() async {
    refreshCalls++;
  }

  @override
  Future<void> logout() async {}

  @override
  Future<AuthUser?> getCachedUser() async {
    return cachedUserAvailable ? user : null;
  }

  @override
  Future<void> cacheUser(AuthUser user) async {}

  @override
  Future<void> clearSession() async {
    clearCalls++;
  }
}

AuthUser _user() => const AuthUser(
      id: 7,
      username: 'rep',
      email: 'rep@example.com',
      firstName: 'Field',
      lastName: 'Rep',
      isStaff: true,
      isSuperuser: false,
      roleLevel: 10,
      permissions: {'invoices.view_invoice'},
      role: null,
    );

void main() {
  test('expired offline cache falls back to the real server session', () async {
    final repository = FakeAuthenticationRepository(_user());
    final controller = AuthController(
      repository,
      offlineAllowed: () => true,
    );

    await controller.restoreSession();

    expect(controller.status, AuthStatus.authenticated);
    expect(controller.currentUser?.id, 7);
    expect(repository.refreshCalls, 1);
    expect(repository.fetchCalls, 1);
  });

  test('valid offline cache is used without a server round trip', () async {
    final repository = FakeAuthenticationRepository(_user())
      ..cachedUserAvailable = true;
    final controller = AuthController(
      repository,
      offlineAllowed: () => true,
    );

    await controller.restoreSession();

    expect(controller.status, AuthStatus.authenticated);
    expect(controller.currentUser?.id, 7);
    expect(repository.refreshCalls, 0);
    expect(repository.fetchCalls, 0);
  });
}
