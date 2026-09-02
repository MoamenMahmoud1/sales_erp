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

  BiometricAuth([LocalAuthentication? auth])
      : _auth = auth ?? LocalAuthentication();

  /// Returns the biometric methods currently registered and usable.
  Future<Set<BiometricType>> availableBiometrics() async {
    try {
      return (await _auth.getAvailableBiometrics()).toSet();
    } catch (_) {
      return const <BiometricType>{};
    }
  }

  /// Returns whether this device can currently perform biometric auth.
  Future<bool> isAvailable() async {
    try {
      return await _auth.isDeviceSupported() &&
          await _auth.canCheckBiometrics &&
          (await availableBiometrics()).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Prompts the OS biometric UI. The OS may carry this prompt across a
  /// temporary background transition; the app itself never starts retries.
  Future<BiometricResult> authenticate({
    String reason = 'Unlock Sales ERP to protect your business data',
  }) async {
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
    }
  }

  /// Whether Face authentication is available.
  Future<bool> supportsFace() async =>
      (await availableBiometrics()).contains(BiometricType.face);

  /// Whether fingerprint authentication is available.
  Future<bool> supportsFingerprint() async =>
      (await availableBiometrics()).contains(BiometricType.fingerprint);
}
