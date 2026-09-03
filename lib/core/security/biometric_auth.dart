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

  /// Cancels any stale native authentication request.
  ///
  /// Android can keep the previous biometric prompt alive briefly after the
  /// user presses Back/Cancel. We only call this as recovery between attempts;
  /// never while a fresh request is being started.
  Future<void> _clearStaleAuthentication() async {
    try {
      await _auth.stopAuthentication();
    } catch (_) {
      // No active request is a valid state.
    }
  }

  /// Starts a fresh native biometric request.
  ///
  /// After a user cancellation some Android implementations can briefly
  /// report authInProgress. A single recovery retry clears that stale native
  /// state, waits for the dismissal to settle, and starts a new request.
  Future<bool> _authenticateNative({
    required String localizedReason,
    required bool biometricOnly,
    bool allowRecovery = true,
  }) async {
    try {
      return await _auth.authenticate(
        localizedReason: localizedReason,
        biometricOnly: biometricOnly,
        persistAcrossBackgrounding: false,
        sensitiveTransaction: false,
      );
    } on LocalAuthException catch (error) {
      if (!allowRecovery || error.code != LocalAuthExceptionCode.authInProgress) {
        rethrow;
      }

      await _clearStaleAuthentication();
      await Future<void>.delayed(const Duration(milliseconds: 300));

      return _authenticateNative(
        localizedReason: localizedReason,
        biometricOnly: biometricOnly,
        allowRecovery: false,
      );
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

      return await _authenticateWithRecovery(
        localizedReason: 'Use $label to unlock Sales ERP.',
        biometricOnly: true,
      );
    } catch (_) {
      await _clearStaleAuthentication();
      return BiometricResult.failed;
    }
  }

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
      // Clear only an already-finished/stale request before a user-triggered
      // attempt. This is deliberately followed by a small settling delay.
      await _clearStaleAuthentication();
      await Future<void>.delayed(const Duration(milliseconds: 150));

      final ok = await _authenticateNative(
        localizedReason: localizedReason,
        biometricOnly: biometricOnly,
      );
      return ok ? BiometricResult.success : BiometricResult.failed;
    } on LocalAuthException {
      await _clearStaleAuthentication();
      return BiometricResult.failed;
    } catch (_) {
      await _clearStaleAuthentication();
      return BiometricResult.failed;
    }
  }
}
