import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:workmanager/workmanager.dart';

import '../repositories/app_services.dart';
import 'sync_outbox.dart';
import 'sync_outbox_processor.dart';

const _taskName = 'sales_erp.process_sync_outbox';
const _uniqueTaskName = 'sales_erp.sync_outbox.periodic';

@pragma('vm:entry-point')
void syncOutboxCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      await dotenv.load(fileName: '.env');
    } catch (_) {
      // The environment may already be loaded in a foreground isolate.
    }

    await AppServices.instance.init();
    final services = AppServices.instance;

    try {
      await services.authRepository.refresh();
    } catch (_) {
      // A missing/expired session must not delete business commands. They stay
      // in the outbox until the owning user restores authentication.
    }

    await SyncOutboxProcessor(
      client: services.apiClient,
      outbox: SyncOutbox(),
      refreshSession: services.authRepository.refresh,
    ).flush();
    return true;
  });
}

class SyncOutboxScheduler {
  SyncOutboxScheduler._();

  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;
    await Workmanager().initialize(
      syncOutboxCallbackDispatcher,
      isInDebugMode: false,
    );
    await Workmanager().registerPeriodicTask(
      _uniqueTaskName,
      _taskName,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
    _initialized = true;
  }

  static Future<void> flushNow() async {
    final services = AppServices.instance;
    if (!services.isReady) await services.init();

    await SyncOutboxProcessor(
      client: services.apiClient,
      outbox: SyncOutbox(),
      refreshSession: services.authRepository.refresh,
    ).flush();
  }
}
