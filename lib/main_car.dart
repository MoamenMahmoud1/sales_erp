import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'app/app.dart';
import 'core/repositories/app_services.dart';
import 'core/security/app_lock_controller.dart';
import 'core/theme/app_theme.dart';
import 'features/car/presentation/car_app_shell.dart';

/// Standalone Car application entry point.
///
/// The Car feature owns its local data reads and writes after the application
/// shell is mounted; startup itself does not perform Car seeding.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');
  await AppServices.instance.init();

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
