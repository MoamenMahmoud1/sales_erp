import 'package:flutter/widgets.dart';

import 'app/app.dart';
import 'core/data/demo_data_seeder.dart';
import 'core/repositories/app_services.dart';
import 'core/security/app_lock_controller.dart';
import 'core/sync/sync_outbox_scheduler.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/auth_controller.dart';
import 'features/auth/presentation/auth_gate.dart';

/// Full Sales ERP entry point.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AppServices.instance.init();
  await AppServices.instance.pushNotificationRepository.initialize();
  await SyncOutboxScheduler.initialize();
  await SyncOutboxScheduler.flushNow();
  await DemoDataSeeder().seedIfNeeded();

  final lockController = AppLockController();
  await lockController.init();

  final themeController = AppThemeController();
  await themeController.load();

  final authController = AuthController(
    AppServices.instance.authRepository,
    offlineAllowed: () => AppServices.instance.offlineAllowed,
    onModeChanged: () =>
        AppServices.instance.pushNotificationRepository.setAuthenticated(false),
    onAuthenticated: () =>
        AppServices.instance.pushNotificationRepository.setAuthenticated(true),
    onBeforeLogout: () =>
        AppServices.instance.pushNotificationRepository.setAuthenticated(false),
  );

  runApp(
    SalesErpApp(
      lockController: lockController,
      themeController: themeController,
      homeBuilder: (themeController, onLock) => AuthGate(
        controller: authController,
        themeController: themeController,
        onLock: onLock,
      ),
    ),
  );
}
