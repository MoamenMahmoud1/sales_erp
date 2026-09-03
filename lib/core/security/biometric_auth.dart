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

  /// Best-effort cleanup after a native dialog was dismissed.
  Future<void> _clearStaleAuthentication() async {
    try {
      await _auth.stopAuthentication();
    } catch (_) {
      // No native request is also a valid state.
    }
  }

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

      return await _authenticateWithRecovery(
        localizedReason: 'Use $label to unlock Sales ERP.',
        biometricOnly: true,
      );
    } catch (_) {
      await _clearStaleAuthentication();
      return BiometricResult.failed;
    }
  }

  /// Uses the device credential flow (PIN, pattern, password or passcode).
  /// The credential is entered in the OS UI and is never exposed to the app.
  Future<BiometricResult> authenticateDeviceCredential({
    String reason = 'Unlock Sales ERP with your phone PIN or password.',
  }) async {
    if (!await isDeviceSupported()) return BiometricResult.unavailable;

    return _authenticateWithRecovery(
      localizedReason: reason,
      biometricOnly: false,
    );
  }

  /// Runs one user-requested authentication attempt.
  ///
  /// A normal user cancel must return to the app and remain available for a
  /// manual retry. A native auth-in-progress race is the only condition that
  /// is retried automatically, with one cleanup/retry cycle per call.
  Future<BiometricResult> _authenticateWithRecovery({
    required String localizedReason,
    required bool biometricOnly,
  }) async {
    try {
      final ok = await _authenticateNative(
        localizedReason: localizedReason,
        biometricOnly: biometricOnly,
      );
      return ok ? BiometricResult.success : BiometricResult.failed;
    } on LocalAuthException catch (error) {
      if (error.code == LocalAuthExceptionCode.userCanceled ||
          error.code == LocalAuthExceptionCode.systemCanceled) {
        await _clearStaleAuthentication();
        // Allow the vendor/native dialog dismissal to fully settle before the
        // Dart button becomes eligible for another request.
        await Future<void>.delayed(const Duration(milliseconds: 500));
        return BiometricResult.failed;
      }

      if (error.code == LocalAuthExceptionCode.authInProgress) {
        await _clearStaleAuthentication();
        await Future<void>.delayed(const Duration(milliseconds: 500));

        try {
          final ok = await _authenticateNative(
            localizedReason: localizedReason,
            biometricOnly: biometricOnly,
          );
          return ok ? BiometricResult.success : BiometricResult.failed;
        } on LocalAuthException catch (retryError) {
          if (retryError.code == LocalAuthExceptionCode.authInProgress) {
            await _clearStaleAuthentication();
            await Future<void>.delayed(const Duration(milliseconds: 500));
          }
          return BiometricResult.failed;
        }
      }

      await _clearStaleAuthentication();
      return BiometricResult.failed;
    } catch (_) {
      await _clearStaleAuthentication();
      return BiometricResult.failed;
    }
  }

  Future<bool> _authenticateNative({
    required String localizedReason,
    required bool biometricOnly,
  }) {
    return _auth.authenticate(
      localizedReason: localizedReason,
      biometricOnly: biometricOnly,
      // Keeping authentication sticky protects against vendor/activity
      // transitions that temporarily background the Flutter surface.
      persistAcrossBackgrounding: true,
      sensitiveTransaction: false,
    );
  }
}
