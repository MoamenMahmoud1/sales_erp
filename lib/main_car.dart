import 'package:flutter/widgets.dart';

import 'app/app.dart';
import 'core/repositories/app_services.dart';
import 'core/security/app_lock_controller.dart';
import 'features/car/presentation/car_app_shell.dart';

/// Standalone Car application entry point.
///
/// This entry point intentionally imports the Car shell rather than the full
/// Sales ERP shell. It also skips the generic Sales demo seeder so the Car APK
/// does not create unrelated Sales/Customer/Invoice demo data on first launch.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AppServices.instance.init();

  final lockController = AppLockController();
  await lockController.init();

  runApp(
    SalesErpApp(
      lockController: lockController,
      title: 'Sales ERP Car',
      homeBuilder: (themeController, onLock) => CarAppShell(
        themeController: themeController,
        onLock: onLock,
        standalone: true,
      ),
    ),
  );
}
