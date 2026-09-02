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

  final DateTime Function() _now;

  AppStatus _status = AppStatus.locked;
  bool _initialized = false;
  DateTime? _lastActivity;
  Timer? _inactivityTimer;

  AppLockController({DateTime Function()? now}) : _now = now ?? DateTime.now;

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
      recordActivity();
      return;
    }

    _status = AppStatus.unlocked;
    recordActivity();
    notifyListeners();
  }

  /// Records meaningful app usage and resets the five-minute idle deadline.
  void recordActivity() {
    if (_status != AppStatus.unlocked) return;
    final now = _now();
    _lastActivity = now;
    _scheduleInactivityCheck(now);
  }

  void _scheduleInactivityCheck(DateTime now) {
    _inactivityTimer?.cancel();
    final deadline = now.add(inactivityTimeout);
    final delay = deadline.difference(_now());
    _inactivityTimer = Timer(
      delay.isNegative || delay == Duration.zero ? Duration.zero : delay,
      _handleInactivityTimer,
    );
  }

  void _handleInactivityTimer() {
    if (_status != AppStatus.unlocked) return;
    final last = _lastActivity;
    if (last == null) return;

    final elapsed = _now().difference(last);
    if (elapsed >= inactivityTimeout) {
      _lockForInactivity();
      return;
    }

    _scheduleInactivityCheck(last);
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

    if (_now().difference(last) >= inactivityTimeout) {
      _lockForInactivity();
    } else {
      _scheduleInactivityCheck(last);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
    super.dispose();
  }
}
