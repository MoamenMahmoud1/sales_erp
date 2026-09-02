import 'dart:async';

import 'package:local_auth/local_auth.dart';

/// Result of a local biometric authentication attempt.
enum BiometricResult {
  success,
  unavailable,
  failed,
}

/// Platform-neutral wrapper around [LocalAuthentication].
class BiometricAuth {
  final LocalAuthentication _auth;
  Set<BiometricType>? _availableCache;

  BiometricAuth([LocalAuthentication? auth])
      : _auth = auth ?? LocalAuthentication();

  /// Returns the biometric methods currently registered and usable.
  Future<Set<BiometricType>> availableBiometrics({
    bool refresh = false,
  }) async {
    if (!refresh) {
      final cached = _availableCache;
      if (cached != null) return cached;
    }

    try {
      final types = (await _auth.getAvailableBiometrics()).toSet();
      _availableCache = types;
      return types;
    } catch (_) {
      _availableCache = const <BiometricType>{};
      return const <BiometricType>{};
    }
  }

  /// Returns whether this device can currently perform biometric auth.
  Future<bool> isAvailable() async {
    try {
      if (!await _auth.isDeviceSupported() ||
          !await _auth.canCheckBiometrics) {
        return false;
      }
      return (await availableBiometrics()).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Prompts the OS biometric UI. The app never retries automatically.
  Future<BiometricResult> authenticate({
    String reason = 'Unlock Sales ERP to protect your business data',
  }) async {
    final stopwatch = Stopwatch()..start();
    if (!await isAvailable()) return BiometricResult.unavailable;

    try {
      final ok = await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
        persistAcrossBackgrounding: true,
        sensitiveTransaction: false,
      );
      return ok ? BiometricResult.success : BiometricResult.failed;
    } catch (_) {
      return BiometricResult.failed;
    } finally {
      stopwatch.stop();
      // local_auth can fail immediately while Android is restoring window
      // focus. Keep the first result deterministic so the presentation layer
      // cannot mistake an instantaneous failure for a prompt that needs an
      // automatic retry.
      const minimumAttemptDuration = Duration(milliseconds: 450);
      final remaining = minimumAttemptDuration - stopwatch.elapsed;
      if (remaining > Duration.zero) {
        await Future<void>.delayed(remaining);
      }
    }
  }

  /// Whether Face authentication is available.
  Future<bool> supportsFace() async =>
      (await availableBiometrics()).contains(BiometricType.face);

  /// Whether fingerprint authentication is available.
  Future<bool> supportsFingerprint() async =>
      (await availableBiometrics()).contains(BiometricType.fingerprint);
}
