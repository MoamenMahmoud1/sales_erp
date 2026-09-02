import 'package:flutter/foundation.dart';

/// Application-local lock state.
enum AppStatus { locked, unlocked }

/// Owns authentication state for one running application process.
///
/// A successful biometric/PIN unlock remains valid for the current process.
/// Background/resume events do not start another automatic authentication.
/// Calling [lock] explicitly starts a new authentication cycle.
class AppLockController extends ChangeNotifier {
  AppStatus _status = AppStatus.locked;
  bool _initialized = false;

  AppStatus get status => _status;
  bool get isLocked => _status == AppStatus.locked;
  bool get isInitialized => _initialized;

  /// Initializes one application-local authentication session.
  ///
  /// The state is intentionally in memory only. Every cold launch starts
  /// locked and therefore gets exactly one automatic authentication attempt.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    _status = AppStatus.locked;
    notifyListeners();
  }

  /// Marks the current application session as authenticated.
  Future<void> unlock() async {
    if (!_initialized) await init();
    if (_status == AppStatus.unlocked) return;
    _status = AppStatus.unlocked;
    notifyListeners();
  }

  /// Explicitly locks the application for a new authentication cycle.
  void lock() {
    if (_status == AppStatus.locked) return;
    _status = AppStatus.locked;
    notifyListeners();
  }
}
