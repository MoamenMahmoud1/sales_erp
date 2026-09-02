import 'package:local_auth/local_auth.dart';

/// The biometric modality the user selected in the app UI.
enum BiometricMethod { face, fingerprint, generic }

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

  /// Requests biometric authentication.
  ///
  /// [method] is the method selected by the app UI and controls the prompt
  /// wording. The underlying OS still controls the physical biometric sensor
  /// when more than one biometric is enrolled.
  Future<BiometricResult> authenticateBiometric({
    BiometricMethod method = BiometricMethod.generic,
  }) async {
    try {
      final available = await availableBiometrics();
      if (available.isEmpty || !await _auth.canCheckBiometrics) {
        return BiometricResult.unavailable;
      }

      final label = switch (method) {
        BiometricMethod.face => 'Face',
        BiometricMethod.fingerprint => 'fingerprint',
        BiometricMethod.generic => 'biometric authentication',
      };
      final ok = await _auth.authenticate(
        localizedReason: 'Use $label to unlock Sales ERP.',
        biometricOnly: true,
        persistAcrossBackgrounding: false,
        sensitiveTransaction: false,
      );
      return ok ? BiometricResult.success : BiometricResult.failed;
    } catch (_) {
      return BiometricResult.failed;
    }
  }

  /// Uses the device credential flow (PIN, pattern, password or passcode).
  /// The credential is entered in the OS UI and is never exposed to the app.
  Future<BiometricResult> authenticateDeviceCredential({
    String reason = 'Unlock Sales ERP with your phone PIN or password.',
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
}
