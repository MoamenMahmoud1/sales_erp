import 'package:flutter_test/flutter_test.dart';

import 'package:sales_erp/core/security/app_lock_controller.dart';

void main() {
  test('starts locked and remains unlocked for the session', () async {
    final controller = AppLockController();
    addTearDown(controller.dispose);

    await controller.init();
    expect(controller.status, AppStatus.locked);

    await controller.unlock();
    expect(controller.status, AppStatus.unlocked);

    expect(controller.status, AppStatus.unlocked);
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
