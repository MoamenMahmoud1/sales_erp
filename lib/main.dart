import 'package:flutter/material.dart';
import 'package:workmanager/workmanager.dart';

import 'core/background/background_tasks.dart';
import 'features/customers/presentation/customers_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Workmanager().initialize(
    callbackDispatcher,
  );

  await Workmanager().registerPeriodicTask(
    'invoice-cache-cleanup',
    cleanupInvoiceCacheTask,
    frequency: const Duration(hours: 24),
  );

  runApp(const SalesErpApp());
}

class SalesErpApp extends StatelessWidget {
  const SalesErpApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sales ERP',

      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
        ),
        brightness: Brightness.light,
        useMaterial3: true,
      ),

      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),

      themeMode: ThemeMode.system,

      home: const CustomersPage(),
    );
  }
}