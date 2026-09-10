import 'package:flutter/widgets.dart';

import 'app/app.dart';
import 'core/repositories/app_services.dart';
import 'core/security/app_lock_controller.dart';
import 'core/theme/app_theme.dart';
import 'features/car/presentation/car_app_shell.dart';

/// Standalone Car application entry point.
///
/// The Car dashboard is responsible for preparing its local demo state before
/// it is shown, so a seed failure can be rendered as an in-app error instead
/// of preventing Flutter from mounting the application.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
