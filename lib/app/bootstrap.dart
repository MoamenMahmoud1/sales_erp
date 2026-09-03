import 'package:flutter/widgets.dart';

import '../core/data/demo_data_seeder.dart';
import '../core/repositories/app_services.dart';
import '../core/security/app_lock_controller.dart';

class AppBootstrap {
  final AppLockController lockController;

  const AppBootstrap._({required this.lockController});

  static Future<AppBootstrap> initialize() async {
    WidgetsFlutterBinding.ensureInitialized();

    await AppServices.instance.init();
    await DemoDataSeeder().seedIfNeeded();

    final lockController = AppLockController();
    await lockController.init();

    return AppBootstrap._(lockController: lockController);
  }
}
