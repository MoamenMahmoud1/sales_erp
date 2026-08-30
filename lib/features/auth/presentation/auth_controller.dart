import 'package:flutter/foundation.dart';

import '../data/auth_repository.dart';

enum AuthStatus {
  checking,
  authenticated,
  unauthenticated,
}

class AuthController extends ChangeNotifier {
  final AuthRepository repository;

  /// دالة بترجّع هل يسمح الوضع الحالي بالدخول من غير سيرفر؟ (local / hybrid).
  ///
  /// بتتقييم لحظيًا من الـ DataMode الحالي عشان لو اتبدل الوضع
  /// وقت التشغيل تفضل القرارات صحيحة.
  final bool Function() offlineAllowed;

  /// بيتنادى لما الوضع (local / hybrid / api) يتغير عشان نقدر
  /// نعمل اللي محتاجينه زي مسح الجلسة لو المطلوب دخل بـ token.
  final Future<void> Function()? onModeChanged;

  AuthStatus status = AuthStatus.checking;

  AuthController(
    this.repository, {
    required this.offlineAllowed,
    this.onModeChanged,
  });

  bool get canAccessOffline => offlineAllowed();

  Future<void> restoreSession() async {
    status = AuthStatus.checking;
    notifyListeners();

    if (canAccessOffline) {
      // في الوضع المحلي / الهايبرد بنسمح بالدخول فورًا
      // والبيانات كلها من القاعدة المحلية.
      status = AuthStatus.authenticated;
      notifyListeners();
      return;
    }

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
    if (!canAccessOffline) {
      try {
        await repository.logout();
      } catch (_) {
        await repository.client.clearSession();
      }
    } else {
      // من غير سيرفر نمسح الجلسة المحلية بس.
      await repository.client.clearSession();
    }
    status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  /// بيستدعي الكولباك بتاع تغيير الوضع لو موجود.
  Future<void> handleModeChanged() async {
    await onModeChanged?.call();
  }
}
