import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// حالة قفل التطبيق.
enum LockStatus { unlocked, locked }

/// مسؤول عن جدولة فحص المصادقة (auth check) عند الإقلاع/العودة.
///
/// القاعدة: الفحص بيحصل مرة واحدة عند أول تشغيل، وبعدها فقط لو مضى
/// [checkInterval] (5 دقائق) منذ آخر فحص **ناجح**. الطابع الزمني محفوظ
/// في FlutterSecureStorage فبيدوم عبر إغلاق التطبيق بالكامل.
/// الفحص الفاشل/الملغي لا يحدّث الطابع الزمني.
class AppLockController extends ChangeNotifier
    with WidgetsBindingObserver {
  /// الحد الأدنى بين فحصي مصادقة ناجحين.
  static const Duration checkInterval = Duration(minutes: 5);

  static const String _lastCheckKey = 'app_lock_last_auth_check';

  final FlutterSecureStorage _storage;
  final DateTime Function() _now;

  AppStatus status = AppStatus.unlocked;

  /// حارس يمنع أي فحص مكرر في نفس اللحظة (rebuild / lifecycle / ...).
  bool _checkInFlight = false;

  AppLockController({
    FlutterSecureStorage? storage,
    DateTime Function()? now,
  })  : _storage = storage ?? const FlutterSecureStorage(),
        _now = now ?? DateTime.now;

  bool _lifecycleObserverAttached = false;

  /// يقرأ آخر فحص ناجح محفوظ ويقرر هل نطلب المصادقة الآن:
  /// - لا يوجد طابع زمني → فحص (أول تشغيل).
  /// - مضى >= [checkInterval] منذ آخر فحص ناجح → فحص.
  /// - غير ذلك → تخطي.
  Future<void> init() async {
    WidgetsBinding.instance.addObserver(this);
    _lifecycleObserverAttached = true;
    if (await _shouldCheckAuth()) {
      status = AppStatus.locked;
      notifyListeners();
    }
  }

  /// هل نطلب فحص مصادقة الآن؟ (حسب آخر فحص ناجح محفوظ).
  Future<bool> _shouldCheckAuth() async {
    final last = await _lastCheck();
    if (last == null) return true;
    return _now().difference(last) >= checkInterval;
  }

  Future<DateTime?> _lastCheck() async {
    final raw = await _storage.read(key: _lastCheckKey);
    if (raw == null) return null;
    return DateTime.tryParse(raw)?.toLocal();
  }

  /// يحدّث توقيت آخر فحص ناجح — يُستدعى فقط بعد مصادقة ناجحة.
  Future<void> recordSuccessfulAuth() async {
    await _storage.write(
      key: _lastCheckKey,
      value: _now().toUtc().toIso8601String(),
    );
  }

  /// عند نجاح المصادقة: نسجل التوقيت ونفك القفل.
  Future<void> unlock() async {
    await recordSuccessfulAuth();
    status = AppStatus.unlocked;
    notifyListeners();
  }

  /// عند فشل/إلغاء المصادقة: لا نحدّث الطابع الزمني.
  void lock() {
    status = AppStatus.locked;
    notifyListeners();
  }

  /// يقرر القفل عند رجوع التطبيق من الخلفية (نفس قاعدة الـ 5 دقائق).
  Future<bool> _maybeLockOnResume() async {
    if (_checkInFlight) return false;
    _checkInFlight = true;
    try {
      if (await _shouldCheckAuth()) {
        lock();
        return true;
      }
      return false;
    } finally {
      _checkInFlight = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        // عند العودة: لو مرت مدة كافية → قفل.
        _maybeLockOnResume();
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  void dispose() {
    if (_lifecycleObserverAttached) {
      WidgetsBinding.instance.removeObserver(this);
    }
    super.dispose();
  }
}

enum AppStatus { locked, unlocked }