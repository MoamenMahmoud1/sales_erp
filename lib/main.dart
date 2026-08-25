import 'package:flutter/material.dart';

import 'core/network/api_client.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/presentation/auth_controller.dart';
import 'features/auth/presentation/auth_gate.dart';
import 'features/products/data/api_product_repository.dart';
import 'features/products/domain/product_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final apiClient = await ApiClient.create();
  final authController = AuthController(
    AuthRepository(apiClient),
  );
  final productRepository = ApiProductRepository(apiClient);

  runApp(
    SalesErpApp(
      authController: authController,
      productRepository: productRepository,
    ),
  );
}

class SalesErpApp extends StatefulWidget {
  final AuthController? authController;
  final ProductRepository? productRepository;

  const SalesErpApp({
    super.key,
    this.authController,
    this.productRepository,
  });

  @override
  State<SalesErpApp> createState() => _SalesErpAppState();
}

class _SalesErpAppState extends State<SalesErpApp> {
  final _themeController = AppThemeController();

  @override
  void initState() {
    super.initState();
    _themeController.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    _themeController
      ..removeListener(_onThemeChanged)
      ..dispose();
    super.dispose();
  }

  void _onThemeChanged() => setState(() {});

  ThemeData get _theme {
    switch (_themeController.mode) {
      case AppThemeMode.light:
        return AppTheme.light();
      case AppThemeMode.mid:
        return AppTheme.mid();
      case AppThemeMode.dark:
        return AppTheme.dark();
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return MaterialApp(
      title: 'Sales ERP',

      debugShowCheckedModeBanner: false,

      theme: _theme,
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.light,

      home: widget.authController == null
          ? const Scaffold(
              body: Center(child: Text('Sales ERP')),
            )
          : AuthGate(
              controller: widget.authController!,
              themeController: _themeController,
              productRepository: widget.productRepository,
            ),
    );
  }
}

