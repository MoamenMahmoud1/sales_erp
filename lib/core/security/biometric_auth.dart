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
  bool _nativeCleanupRequired = false;

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

  /// Clears a stale native authentication state before a retry.
  ///
  /// We intentionally do this only after a previous attempt completed or was
  /// canceled. Calling stopAuthentication immediately before every new
  /// authenticate() can race the platform's completion callback.
  Future<void> resetAuthenticationSession() async {
    try {
      await _auth.stopAuthentication();
    } catch (_) {
      // No active authentication request is a valid state.
    }

    // Android/OEM biometric dialogs can need a short turn to finish tearing
    // down the previous native request before another prompt is accepted.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    _nativeCleanupRequired = false;
  }

  Future<bool> _authenticateNative({
    required String localizedReason,
    required bool biometricOnly,
  }) async {
    if (_nativeCleanupRequired) {
      await resetAuthenticationSession();
    }

    try {
      return await _auth.authenticate(
        localizedReason: localizedReason,
        biometricOnly: biometricOnly,
        persistAcrossBackgrounding: false,
        sensitiveTransaction: false,
      );
    } on LocalAuthException catch (error) {
      if (error.code != LocalAuthExceptionCode.authInProgress) rethrow;

      // Recover once from an OEM/plugin race where the canceled request has
      // not cleared its native in-progress flag yet.
      await resetAuthenticationSession();
      try {
        return await _auth.authenticate(
          localizedReason: localizedReason,
          biometricOnly: biometricOnly,
          persistAcrossBackgrounding: false,
          sensitiveTransaction: false,
        );
      } finally {
        _nativeCleanupRequired = true;
      }
    } finally {
      _nativeCleanupRequired = true;
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
      final ok = await _authenticateNative(
        localizedReason: 'Use $label to unlock Sales ERP.',
        biometricOnly: true,
      );
      return ok ? BiometricResult.success : BiometricResult.failed;
    } catch (_) {
      _nativeCleanupRequired = true;
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
      final ok = await _authenticateNative(
        localizedReason: reason,
        biometricOnly: false,
      );
      return ok ? BiometricResult.success : BiometricResult.failed;
    } catch (_) {
      _nativeCleanupRequired = true;
      return BiometricResult.failed;
    }
  }
}
