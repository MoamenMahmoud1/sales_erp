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

  /// Fully settles a dismissed native prompt before another request is made.
  ///
  /// Some OEM implementations finish the Dart Future before their native
  /// biometric surface has completely torn down. We therefore give the native
  /// layer a chance to cancel twice, with a short settling window between the
  /// calls. This is recovery only; it is never run while starting a fresh
  /// authentication request.
  Future<void> _settleAfterDismissal() async {
    try {
      await _auth.stopAuthentication();
    } catch (_) {
      // No active authentication is valid.
    }
    await Future<void>.delayed(const Duration(milliseconds: 300));
    try {
      await _auth.stopAuthentication();
    } catch (_) {
      // No active authentication is valid.
    }
    await Future<void>.delayed(const Duration(milliseconds: 200));
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
      await _settleAfterDismissal();
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
  /// User cancellation never auto-retries. The native state is fully settled
  /// before the UI is allowed to issue a manual retry. Only a stale native
  /// auth-in-progress race gets one controlled automatic recovery attempt.
  Future<BiometricResult> _authenticateWithRecovery({
    required String localizedReason,
    required bool biometricOnly,
  }) async {
    try {
      final ok = await _authenticateNative(
        localizedReason: localizedReason,
        biometricOnly: biometricOnly,
      );

      if (ok) return BiometricResult.success;

      // Defensive handling for Android/OEM implementations that surface a
      // cancellation as false instead of LocalAuthException.userCanceled.
      await _settleAfterDismissal();
      return BiometricResult.failed;
    } on LocalAuthException catch (error) {
      if (error.code == LocalAuthExceptionCode.userCanceled ||
          error.code == LocalAuthExceptionCode.systemCanceled) {
        await _settleAfterDismissal();
        return BiometricResult.failed;
      }

      if (error.code == LocalAuthExceptionCode.authInProgress) {
        await _settleAfterDismissal();

        try {
          final ok = await _authenticateNative(
            localizedReason: localizedReason,
            biometricOnly: biometricOnly,
          );
          if (ok) return BiometricResult.success;
        } on LocalAuthException catch (retryError) {
          if (retryError.code == LocalAuthExceptionCode.authInProgress ||
              retryError.code == LocalAuthExceptionCode.userCanceled ||
              retryError.code == LocalAuthExceptionCode.systemCanceled) {
            await _settleAfterDismissal();
          }
        }

        return BiometricResult.failed;
      }

      await _settleAfterDismissal();
      return BiometricResult.failed;
    } catch (_) {
      await _settleAfterDismissal();
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
      // Do not keep an authentication operation sticky. We handle native
      // dismissal and retry explicitly so the manual Retry button owns the
      // retry lifecycle.
      persistAcrossBackgrounding: false,
      sensitiveTransaction: false,
    );
  }
}
