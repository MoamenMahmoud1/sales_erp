import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';

import 'package:sales_erp/core/security/app_lock_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('starts locked and remains unlocked for an active session', () async {
    var now = DateTime(2026, 1, 1, 12);
    final controller = AppLockController(now: () => now);
    addTearDown(controller.dispose);

    await controller.init();
    expect(controller.status, AppStatus.locked);

    await controller.unlock();
    expect(controller.status, AppStatus.unlocked);

    now = now.add(const Duration(minutes: 4));
    controller.recordActivity();
    controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
    expect(controller.status, AppStatus.unlocked);
  });

  test('locks after five minutes without app activity', () async {
    var now = DateTime(2026, 1, 1, 12);
    final controller = AppLockController(now: () => now);
    addTearDown(controller.dispose);

    await controller.init();
    await controller.unlock();

    now = now.add(const Duration(minutes: 5));
    controller.didChangeAppLifecycleState(AppLifecycleState.resumed);

    expect(controller.status, AppStatus.locked);
  });

  test('activity resets the five-minute inactivity deadline', () async {
    var now = DateTime(2026, 1, 1, 12);
    final controller = AppLockController(now: () => now);
    addTearDown(controller.dispose);

    await controller.init();
    await controller.unlock();

    now = now.add(const Duration(minutes: 4));
    controller.recordActivity();

    now = now.add(const Duration(minutes: 4, seconds: 59));
    controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
    expect(controller.status, AppStatus.unlocked);

    now = now.add(const Duration(seconds: 1));
    controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
    expect(controller.status, AppStatus.locked);
  });

  test('explicit lock starts exactly one new authentication cycle', () async {
    final controller = AppLockController();
    addTearDown(controller.dispose);

    await controller.init();
    await controller.unlock();
    controller.lock();
    expect(controller.status, AppStatus.locked);

    await controller.unlock();
    expect(controller.status, AppStatus.unlocked);
  });

  test('init is idempotent', () async {
    final controller = AppLockController();
    addTearDown(controller.dispose);

    await controller.init();
    await controller.unlock();
    await controller.init();

    expect(controller.isInitialized, isTrue);
    expect(controller.status, AppStatus.unlocked);
  });
}
