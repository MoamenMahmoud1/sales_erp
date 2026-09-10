import 'package:flutter/material.dart';

import '../../../core/presentation/app_shell.dart';
import '../../../core/repositories/app_services.dart';
import '../../../core/theme/app_theme.dart';
import 'auth_controller.dart';
import 'login_page.dart';

class AuthGate extends StatefulWidget {
  final AuthController controller;
  final AppThemeController themeController;

  const AuthGate({
    super.key,
    required this.controller,
    required this.themeController,
  });

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
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
        final user = widget.controller.currentUser;
        if (user == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return AppShell(
          user: user,
          themeController: widget.themeController,
          onLock: () {},
        );
      case AuthStatus.unauthenticated:
        return LoginPage(controller: widget.controller);
    }
  }
}
