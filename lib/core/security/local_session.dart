import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Represents the *local* application session, completely decoupled from any
/// server authentication.
///
/// It persists whether this device has completed the local onboarding /
/// biometric unlock so subsequent launches skip the welcome gate and go
/// straight to the app shell (subject to the app-lock controller).
///
/// No username, password, token, or biometric data is ever stored here.
class LocalSession extends ChangeNotifier {
  static const String _initializedKey = 'local_session_initialized';
  static const String _biometricEnabledKey = 'local_session_biometric_enabled';

  final FlutterSecureStorage _storage;
  bool _initialized = false;
  bool _biometricEnabled = false;

  LocalSession({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  bool get isInitialized => _initialized;
  bool get biometricEnabled => _biometricEnabled;

  /// Loads persisted local-session state.
  Future<void> load() async {
    try {
      _initialized =
          await _storage.read(key: _initializedKey) == 'true';
      _biometricEnabled =
          await _storage.read(key: _biometricEnabledKey) == 'true';
      notifyListeners();
    } catch (_) {
      // Fall back to a fresh local session on storage errors.
      _initialized = false;
      _biometricEnabled = false;
    }
  }

  /// Marks the local session as set up (first local unlock completed).
  Future<void> markInitialized({bool biometricEnabled = true}) async {
    _initialized = true;
    _biometricEnabled = biometricEnabled;
    notifyListeners();
    try {
      await _storage.write(key: _initializedKey, value: 'true');
      await _storage.write(
        key: _biometricEnabledKey,
        value: biometricEnabled ? 'true' : 'false',
      );
    } catch (_) {
      // Ignore persistence failures; session stays valid for this run.
    }
  }

  /// Resets the local session (used by "reset device" in settings).
  Future<void> reset() async {
    _initialized = false;
    _biometricEnabled = false;
    notifyListeners();
    try {
      await _storage.delete(key: _initializedKey);
      await _storage.delete(key: _biometricEnabledKey);
    } catch (_) {
      // Ignore.
    }
  }
}