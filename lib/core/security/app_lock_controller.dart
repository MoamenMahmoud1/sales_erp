import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// حالة قفل التطبيق.
enum LockStatus { unlocked, locked }

/// مسؤول عن حبس التطبيق فور الإغلاق/العدول والمحافظة على إيقاع
/// القفل حسب مدة النشاط المحددة.
///
/// - عند دخول التطبيق في الخلفية (paused/inactive) بنسجّل وقت الخروج.
/// - عند العودة (resumed) لو مرت مدة أكبر من [timeout] (افتراضي 10 دقائق)
///   نتفعّل القفل ونتطلب الاستفتاح بالـ biometric.
///
/// ملاحظة: مدة القفل ثابتة (10 دقائق) كما طُلب، ويمكن لاحقًا جعلها
/// قابلة للتكوين برفق.
class AppLockController extends ChangeNotifier
    with WidgetsBindingObserver {
  static const Duration timeout = Duration(minutes: 10);

  static const String _lastActiveKey = 'app_lock_last_active';

  final FlutterSecureStorage _storage;
  final DateTime Function() _now;

  AppStatus status = AppStatus.unlocked;

  AppLockController({
    FlutterSecureStorage? storage,
    DateTime Function()? now,
  })  : _storage = storage ?? const FlutterSecureStorage(),
        _now = now ?? DateTime.now;

  bool _lifecycleObserverAttached = false;

  /// يقرأ آخر وقت نشاط محفوظ (يمنع القفل بعد كل تشغيل جديد فورًا).
  Future<void> init() async {
    WidgetsBinding.instance.addObserver(this);
    _lifecycleObserverAttached = true;

    // نبدأ النافذة من الساعة الحالية حتى لا يقفل لحظيًا عند الإقلاع.
    await _storage.write(
      key: _lastActiveKey,
      value: _now().toUtc().toIso8601String(),
    );
  }

  /// يسجّل لحظة استخدام داخل التطبيق (بتتندى من الصفحات الرئيسية).
  Future<void> registerActivity() async {
    await _storage.write(
      key: _lastActiveKey,
      value: _now().toUtc().toIso8601String(),
    );
  }

  Future<DateTime?> _lastActive() async {
    final raw = await _storage.read(key: _lastActiveKey);
    if (raw == null) return null;
    return DateTime.tryParse(raw)?.toLocal();
  }

  /// يفحص إن مرّت مدة [timeout] من آخر نشاط.
  Future<bool> shouldLock() async {
    final last = await _lastActive();
    if (last == null) return false;
    return _now().difference(last) >= timeout;
  }

  void lock() {
    status = AppStatus.locked;
    notifyListeners();
  }

  void unlock() {
    status = AppStatus.unlocked;
    // تحديث آخر نشاط ليبدأ العد من جديد.
    _storage.write(
      key: _lastActiveKey,
      value: _now().toUtc().toIso8601String(),
    );
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        // عند العودة: لو مرت مدة كافية → قفل.
        _maybeLockAfterBackgroundRestore();
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        // الدخول في الخلفية — نسجّل وقت الخروج الآن.
        _registerLastActive();
        break;
    }
  }

  Future<void> _maybeLockAfterBackgroundRestore() async {
    if (await shouldLock()) {
      lock();
    } else {
      await registerActivity();
    }
  }

  Future<void> _registerLastActive() async {
    await _storage.write(
      key: _lastActiveKey,
      value: _now().toUtc().toIso8601String(),
    );
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