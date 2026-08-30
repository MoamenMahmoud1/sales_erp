import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stores and validates the local PIN using FlutterSecureStorage.
///
/// The PIN is a 4–6 digit string persisted on-device. No biometric data,
/// password hash, or server credential is ever stored here — just the PIN
/// so the lock screen can validate manual entry against it.
class PinService {
  static const String _pinKey = 'local_pin_code';
  static const String _defaultPin = '1234';

  final FlutterSecureStorage _storage;

  PinService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  /// Returns the stored PIN, seeding a default on first run so the user is
  /// never locked out before setting their own PIN.
  Future<String> getPin() async {
    try {
      final existing = await _storage.read(key: _pinKey);
      if (existing != null && existing.isNotEmpty) return existing;
      // First run — persist the default so validation can proceed.
      await _storage.write(key: _pinKey, value: _defaultPin);
      return _defaultPin;
    } catch (_) {
      return _defaultPin;
    }
  }

  /// Validates [attempt] against the stored PIN.
  Future<bool> validate(String attempt) async {
    final stored = await getPin();
    return attempt == stored;
  }

  /// Updates the stored PIN (after validating the current one elsewhere).
  Future<void> setPin(String newPin) async {
    await _storage.write(key: _pinKey, value: newPin);
  }
}
