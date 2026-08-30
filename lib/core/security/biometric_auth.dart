import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// نتيجة تفعيل الـ biometric.
enum BiometricResult {
  /// ناجح.
  success,

  /// الجهاز/الطريقة مش متاحة.
  unavailable,

  /// المستخدم ألغى أو فشلت المحاولة.
  failed,
}

/// غلاف نظيف على [LocalAuthentication] بحيث يظل layer البيزنس
/// مستقلًا عن تفاصيل المنصة.
class BiometricAuth {
  final LocalAuthentication _auth;

  BiometricAuth([LocalAuthentication? auth])
      : _auth = auth ?? LocalAuthentication();

  /// هل جهاز/متوفر أي أسلوب biometrics؟
  Future<bool> isAvailable() async {
    try {
      return await _auth.isDeviceSupported() &&
          await _auth.canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }

  /// تنفيذ المصادقة البيومترية. [reason] تصف للمستخدم سبب الطلب.
  Future<BiometricResult> authenticate({
    String reason = 'Unlock Sales ERP with biometrics',
  }) async {
    try {
      final ok = await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
        persistAcrossBackgrounding: true,
        sensitiveTransaction: false,
      );
      return ok ? BiometricResult.success : BiometricResult.failed;
    } on PlatformException catch (e) {
      // Lockout / permanently locked → let the caller show its bypass path.
      assert(() {
        // ignore: avoid_print
        print('Biometric error: ${e.code} — ${e.message}');
        return true;
      }());
      return BiometricResult.failed;
    } catch (_) {
      return BiometricResult.failed;
    }
  }

  /// إمكانيات الجهاز البيومترية الفعلية (وجه / بصمة / أخرى).
  Future<Set<BiometricType>> availableBiometrics() async {
    try {
      final types = await _auth.getAvailableBiometrics();
      return types.toSet();
    } catch (_) {
      return const <BiometricType>{};
    }
  }

  /// هل يدعم الجهاز مصادقة الوجه (Face) تحديدًا؟
  Future<bool> supportsFace() async =>
      (await availableBiometrics()).contains(BiometricType.face);

  /// هل يدعم الجهاز البصمة تحديدًا؟
  Future<bool> supportsFingerprint() async =>
      (await availableBiometrics()).contains(BiometricType.fingerprint);
}