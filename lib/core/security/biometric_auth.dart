import 'package:local_auth/local_auth.dart';

enum BiometricMethod { face, fingerprint, generic }

enum BiometricResult {
  success,
  unavailable,
  failed,
}

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

    Future<void> _settleAfterDismissal() async {
    try {
      await _auth.stopAuthentication();
    } catch (_) {
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
      persistAcrossBackgrounding: false,
      sensitiveTransaction: false,
    );
  }
}
