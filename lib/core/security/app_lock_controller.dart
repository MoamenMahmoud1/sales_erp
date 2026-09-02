import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Application-local lock state.
enum AppStatus { locked, unlocked }

/// Owns authentication state for one running application process.
///
/// A successful biometric/PIN unlock is valid for the remainder of the
/// current process. Background/resume transitions never trigger another
/// automatic authentication. Calling [lock] explicitly starts a new lock
/// cycle and therefore allows one new authentication attempt.
class AppLockController extends ChangeNotifier with WidgetsBindingObserver {
  AppStatus _status = AppStatus.locked;
  bool _initialized = false;

  AppStatus get status => _status;
  bool get isLocked => _status == AppStatus.locked;
  bool get isInitialized => _initialized;

  /// Initializes one application-local authentication session.
  ///
  /// This is intentionally in-memory only. A cold launch always starts
  /// locked; no persisted timestamp can suppress the first authentication.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    _status = AppStatus.locked;
    WidgetsBinding.instance.addObserver(this);
    notifyListeners();
  }

  /// Marks the current application session as authenticated.
  Future<void> unlock() async {
    if (!_initialized) await init();
    if (_status == AppStatus.unlocked) return;
    _status = AppStatus.unlocked;
    notifyListeners();
  }

  /// Explicitly locks the application for the next authentication cycle.
  void lock() {
    if (_status == AppStatus.locked) return;
    _status = AppStatus.locked;
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Deliberately do not re-lock on resume. Authentication is once per
    // process unless the user explicitly selects "Lock now".
  }

  @override
  void dispose() {
    if (_initialized) {
      WidgetsBinding.instance.removeObserver(this);
    }
    super.dispose();
  }
}
