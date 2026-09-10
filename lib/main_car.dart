import 'package:flutter/widgets.dart';

import 'app/app.dart';
import 'core/data/car_demo_data_seeder.dart';
import 'core/repositories/app_services.dart';
import 'core/security/app_lock_controller.dart';
import 'core/theme/app_theme.dart';
import 'features/car/presentation/car_app_shell.dart';

/// Standalone Car application entry point.
///
/// The Car APK seeds only its own minimal demo dataset when the local Car
/// database is empty. It never seeds unrelated Sales/Customer/Invoice data.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AppServices.instance.init();
  await CarDemoDataSeeder().seedIfNeeded();

  final lockController = AppLockController();
  await lockController.init();

  final themeController = AppThemeController();
  await themeController.load();

  runApp(
    SalesErpApp(
      lockController: lockController,
      themeController: themeController,
      title: 'Sales ERP Car',
      homeBuilder: (themeController, onLock) => CarAppShell(
        themeController: themeController,
        onLock: onLock,
        standalone: true,
      ),
    ),
  );
}
