import 'package:local_auth/local_auth.dart';

/// Result of a local device authentication attempt.
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

  Future<Set<BiometricType>> availableBiometrics({bool refresh = false}) async {
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

  Future<bool> isDeviceSupported() async {
    try {
      return await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  Future<bool> isBiometricAvailable() async {
    try {
      if (!await _auth.isDeviceSupported() || !await _auth.canCheckBiometrics) {
        return false;
      }
      return (await availableBiometrics()).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Attempts biometrics only. The OS remains responsible for selecting the
  /// enrolled biometric modality (for example Face or fingerprint).
  Future<BiometricResult> authenticateBiometric({
    String reason = 'Unlock Sales ERP to protect your business data',
  }) async {
    if (!await isBiometricAvailable()) return BiometricResult.unavailable;

    try {
      final ok = await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
        persistAcrossBackgrounding: false,
        sensitiveTransaction: false,
      );
      return ok ? BiometricResult.success : BiometricResult.failed;
    } catch (_) {
      return BiometricResult.failed;
    }
  }

  /// Uses the OS device credential flow (PIN/pattern/password/passcode).
  /// The app never receives or stores the credential.
  Future<BiometricResult> authenticateDeviceCredential({
    String reason = 'Unlock Sales ERP with your phone PIN or password',
  }) async {
    if (!await isDeviceSupported()) return BiometricResult.unavailable;

    try {
      final ok = await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: false,
        persistAcrossBackgrounding: false,
        sensitiveTransaction: false,
      );
      return ok ? BiometricResult.success : BiometricResult.failed;
    } catch (_) {
      return BiometricResult.failed;
    }
  }

  /// Backwards-compatible convenience method for biometric-only callers.
  Future<BiometricResult> authenticate({
    String reason = 'Unlock Sales ERP to protect your business data',
  }) => authenticateBiometric(reason: reason);
}
