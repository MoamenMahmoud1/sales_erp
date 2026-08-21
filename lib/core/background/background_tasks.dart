import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';

import '../storage/app_database.dart';

const String cleanupInvoiceCacheTask = 'cleanupInvoiceCache';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    debugPrint('[BACKGROUND] Task started: $task');

    try {
      switch (task) {
        case cleanupInvoiceCacheTask:
          await AppDatabase.cleanupExpiredInvoiceChanges();

          debugPrint(
            '[BACKGROUND] Invoice cache cleanup completed',
          );

          return true;

        default:
          debugPrint(
            '[BACKGROUND] Unknown task: $task',
          );

          return false;
      }
    } catch (error, stackTrace) {
      debugPrint(
        '[BACKGROUND] Task failed: $error',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );

      return false;
    }
  });
}