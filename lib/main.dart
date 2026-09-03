import 'package:flutter/widgets.dart';

import 'app/app.dart';
import 'core/data/demo_data_seeder.dart';
import 'core/presentation/app_shell.dart';
import 'core/repositories/app_services.dart';
import 'core/security/app_lock_controller.dart';

/// Full Sales ERP entry point.
///
/// The server authentication feature remains disabled for the current
/// local-only build. This entry point keeps the complete application shell.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AppServices.instance.init();
  await DemoDataSeeder().seedIfNeeded();

  final lockController = AppLockController();
  await lockController.init();

  runApp(
    SalesErpApp(
      lockController: lockController,
      homeBuilder: (themeController, onLock) => AppShell(
        themeController: themeController,
        onLock: onLock,
      ),
    ),
  );
}
