import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Application-local lock state.
enum AppStatus { locked, unlocked }

/// Owns authentication state for one running application process.
///
/// A successful device authentication remains valid while the user is active.
/// After five minutes with no interaction, the app locks again. The user may
/// also lock it explicitly with "Lock now".
class AppLockController extends ChangeNotifier with WidgetsBindingObserver {
  static const Duration inactivityTimeout = Duration(minutes: 5);

  AppStatus _status = AppStatus.locked;
  bool _initialized = false;
  DateTime? _lastActivity;
  Timer? _inactivityTimer;

  AppStatus get status => _status;
  bool get isLocked => _status == AppStatus.locked;
  bool get isInitialized => _initialized;

  /// Initializes one application-local authentication session.
  ///
  /// State is intentionally kept in memory only. Every cold launch starts
  /// locked and requires one automatic device-authentication attempt.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    _status = AppStatus.locked;
    WidgetsBinding.instance.addObserver(this);
    notifyListeners();
  }

  /// Marks the current session as authenticated and starts the inactivity
  /// countdown. Authentication is not requested again while the user remains
  /// active.
  Future<void> unlock() async {
    if (!_initialized) await init();
    if (_status == AppStatus.unlocked) {
      _recordActivity(now: DateTime.now());
      return;
    }

    _status = AppStatus.unlocked;
    _recordActivity(now: DateTime.now());
    notifyListeners();
  }

  /// Records meaningful app usage. While unlocked this resets the five-minute
  /// inactivity deadline. Calls while locked are intentionally ignored.
  void recordActivity({DateTime? now}) {
    if (_status != AppStatus.unlocked) return;
    _recordActivity(now: now ?? DateTime.now());
  }

  void _recordActivity({required DateTime now}) {
    _lastActivity = now;
    _scheduleInactivityCheck(now);
  }

  void _scheduleInactivityCheck(DateTime now) {
    _inactivityTimer?.cancel();
    final elapsed = now.difference(_lastActivity ?? now);
    final remaining = inactivityTimeout - elapsed;
    _inactivityTimer = Timer(
      remaining.isNegative || remaining == Duration.zero
          ? Duration.zero
          : remaining,
      _lockForInactivity,
    );
  }

  void _lockForInactivity() {
    if (_status != AppStatus.unlocked) return;
    _status = AppStatus.locked;
    _lastActivity = null;
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
    notifyListeners();
  }

  /// Explicitly locks the application for a new authentication cycle.
  void lock() {
    if (_status == AppStatus.locked) return;
    _status = AppStatus.locked;
    _lastActivity = null;
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || _status != AppStatus.unlocked) {
      return;
    }

    final last = _lastActivity;
    if (last == null) return;
    if (DateTime.now().difference(last) >= inactivityTimeout) {
      _lockForInactivity();
      return;
    }

    _scheduleInactivityCheck(DateTime.now());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
    super.dispose();
  }
}
