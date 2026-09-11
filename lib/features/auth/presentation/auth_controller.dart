import 'package:flutter/foundation.dart';

import '../domain/entities/auth_user.dart';
import '../domain/repositories/authentication_repository.dart';

enum AuthStatus {
  checking,
  authenticated,
  unauthenticated,
}

class AuthController extends ChangeNotifier {
  final AuthenticationRepository repository;

  /// Determines whether the current application mode permits offline access.
  final bool Function() offlineAllowed;

  /// Called when the operational data mode changes.
  final Future<void> Function()? onModeChanged;

  /// Called after a user has been authenticated against the application session.
  final Future<void> Function()? onAuthenticated;

  /// Called before logout while the authenticated session is still available.
  final Future<void> Function()? onBeforeLogout;

  AuthStatus status = AuthStatus.checking;
  AuthUser? currentUser;

  AuthController(
    this.repository, {
    required this.offlineAllowed,
    this.onModeChanged,
    this.onAuthenticated,
    this.onBeforeLogout,
  });

  bool get canAccessOffline => offlineAllowed();

  Future<void> restoreSession() async {
    status = AuthStatus.checking;
    currentUser = null;
    notifyListeners();

    if (canAccessOffline) {
      currentUser = AuthUser.localDevelopmentUser();
      status = AuthStatus.authenticated;
      notifyListeners();
      return;
    }

    try {
      if (!await repository.hasActiveSession()) {
        status = AuthStatus.unauthenticated;
        notifyListeners();
        return;
      }

      await repository.refresh();
      currentUser = await repository.fetchCurrentUser();
      status = AuthStatus.authenticated;
      await onAuthenticated?.call();
    } catch (_) {
      await repository.clearSession();
      currentUser = null;
      status = AuthStatus.unauthenticated;
    }

    notifyListeners();
  }

  Future<void> login({
    required String identifier,
    required String password,
  }) async {
    currentUser = await repository.login(
      identifier: identifier,
      password: password,
    );
    status = AuthStatus.authenticated;
    await onAuthenticated?.call();
    notifyListeners();
  }

  void markAuthenticated({AuthUser? user}) {
    currentUser = user ?? AuthUser.localDevelopmentUser();
    status = AuthStatus.authenticated;
    notifyListeners();
  }

  Future<void> logout() async {
    try {
      await onBeforeLogout?.call();
    } catch (_) {
      // Push device cleanup must never prevent an authenticated user from logging out.
    }

    if (canAccessOffline) {
      await repository.clearSession();
    } else {
      try {
        await repository.logout();
      } catch (_) {
        await repository.clearSession();
      }
    }

    currentUser = null;
    status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  Future<void> handleModeChanged() async {
    await onModeChanged?.call();
  }
}
