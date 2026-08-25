import 'package:flutter/foundation.dart';

import '../data/auth_repository.dart';

enum AuthStatus {
  checking,
  authenticated,
  unauthenticated,
}

class AuthController extends ChangeNotifier {
  final AuthRepository repository;
  AuthStatus status = AuthStatus.checking;

  AuthController(this.repository);

  Future<void> restoreSession() async {
    status = AuthStatus.checking;
    notifyListeners();
    try {
      if (!await repository.client.hasAccessToken()) {
        status = AuthStatus.unauthenticated;
        notifyListeners();
        return;
      }
      await repository.refresh();
      status = AuthStatus.authenticated;
    } catch (_) {
      await repository.client.clearSession();
      status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  void markAuthenticated() {
    status = AuthStatus.authenticated;
    notifyListeners();
  }

  Future<void> logout() async {
    await repository.logout();
    status = AuthStatus.unauthenticated;
    notifyListeners();
  }
}
