import 'package:flutter/material.dart';

import '../../../core/presentation/dashboard_page.dart';
import '../../../core/repositories/app_services.dart';
import '../../../core/theme/app_theme.dart';
import '../../products/domain/product_repository.dart';
import 'auth_controller.dart';
import 'login_page.dart';

class AuthGate extends StatefulWidget {
  final AuthController controller;
  final AppThemeController themeController;
  final ProductRepository? productRepository;

  const AuthGate({
    super.key,
    required this.controller,
    required this.themeController,
    this.productRepository,
  });

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
    // لما الوضع يتغير بنعيد تقييم الجلسة تاني.
    AppServices.instance.dataMode.addListener(_onDataModeChanged);
    widget.controller.restoreSession();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    AppServices.instance.dataMode.removeListener(_onDataModeChanged);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _onDataModeChanged() async {
    await widget.controller.handleModeChanged();
    await widget.controller.restoreSession();
  }

  @override
  Widget build(BuildContext context) {
    switch (widget.controller.status) {
      case AuthStatus.checking:
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      case AuthStatus.authenticated:
        return DashboardPage(
          onNavigateTo: (_) {},
          themeController: widget.themeController,
        );
      case AuthStatus.unauthenticated:
        return LoginPage(controller: widget.controller);
    }
  }
}
