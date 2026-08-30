import 'package:flutter/material.dart';

import 'core/data/demo_data_seeder.dart';
import 'core/presentation/app_shell.dart';
import 'core/presentation/biometric_lock_screen.dart';
import 'core/repositories/app_services.dart';
import 'core/security/app_lock_controller.dart';
import 'core/security/biometric_auth.dart';
import 'core/security/local_session.dart';
import 'core/theme/app_theme.dart';

/// Local-only startup.
///
/// ```
/// main
///  └─ local initialization   (AppServices.load — no network, no Dio)
///  └─ local database + demo seed
///  └─ local session
///  └─ biometric authentication
///  └─ application shell
///  └─ dashboard
/// ```
///
/// No backend, no API client, no internet and no credentials are required.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Pure local services — never constructs the network/client stack.
  await AppServices.instance.init();

  // Local database + believable demo data on first launch.
  await DemoDataSeeder().seedIfNeeded();

  final lockController = AppLockController();
  await lockController.init();

  final localSession = LocalSession();
  await localSession.load();

  runApp(
    SalesErpApp(lockController: lockController, localSession: localSession),
  );
}

class SalesErpApp extends StatefulWidget {
  final AppLockController? lockController;
  final LocalSession? localSession;

  const SalesErpApp({super.key, this.lockController, this.localSession});

  @override
  State<SalesErpApp> createState() => _SalesErpAppState();
}

class _SalesErpAppState extends State<SalesErpApp> {
  late final AppThemeController _themeController;
  late final BiometricAuth _biometricAuth = BiometricAuth();
  late bool _showWelcomeGate;

  @override
  void initState() {
    super.initState();
    _themeController = AppThemeController();
    // Rebuild the app whenever the theme mode changes so the switch is live.
    _themeController.addListener(_onThemeChanged);
    final session = widget.localSession;
    // Show the one-time biometric gate until the local session is initialized.
    _showWelcomeGate =
        widget.lockController != null &&
        (session == null || !session.isInitialized);
    widget.lockController?.addListener(_onLockChanged);
  }

  @override
  void dispose() {
    _themeController.removeListener(_onThemeChanged);
    widget.lockController?.removeListener(_onLockChanged);
    _themeController.dispose();
    super.dispose();
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  void _onLockChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _onWelcomeUnlocked({bool viaBiometrics = true}) async {
    await widget.localSession?.markInitialized(biometricEnabled: viaBiometrics);
    widget.lockController?.unlock();
    if (mounted) setState(() => _showWelcomeGate = false);
  }

  Widget _buildHome() {
    final lock = widget.lockController;

    if (lock == null) {
      // No lock controller (e.g. widget tests) → straight to the shell.
      return AppShell(themeController: _themeController, onLock: () {});
    }

    if (_showWelcomeGate) {
      return BiometricLockScreen(
        auth: _biometricAuth,
        onUnlocked: () => _onWelcomeUnlocked(),
        bypassLabel: 'Continue locally',
        onBypass: () => _onWelcomeUnlocked(viaBiometrics: false),
      );
    }

    if (lock.status == AppStatus.locked) {
      return BiometricLockScreen(
        auth: _biometricAuth,
        onUnlocked: lock.unlock,
        bypassLabel: 'Enter with PIN',
        onBypass: lock.unlock,
      );
    }

    return AppShell(themeController: _themeController, onLock: lock.lock);
  }

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
  Widget build(BuildContext context) {
    return SmoothTheme(
      theme: _theme,
      child: Builder(
        builder: (context) => MaterialApp(
          title: 'Sales ERP',
          debugShowCheckedModeBanner: false,
          theme: SmoothTheme.of(context),
          home: AnimatedSwitcher(
            duration: const Duration(milliseconds: 380),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: KeyedSubtree(
              key: ValueKey(_buildHomeBuildKey()),
              child: _buildHome(),
            ),
          ),
        ),
      ),
    );
  }

  Object _buildHomeBuildKey() {
    final lock = widget.lockController;
    if (lock != null && _showWelcomeGate) return 'welcome';
    if (lock != null && lock.status == AppStatus.locked) return 'locked';
    return 'shell';
  }
}

/// Globally animates theme changes: when the target [theme] changes, the
/// whole application's ThemeData is interpolated over 300ms with
/// easeInOutCubic — no flash, no hard cut, no per-widget animations.
class SmoothTheme extends StatefulWidget {
  final ThemeData theme;
  final Widget child;

  const SmoothTheme({super.key, required this.theme, required this.child});

  /// The currently animated theme data.
  static ThemeData of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_SmoothThemeScope>()!.theme;

  @override
  State<SmoothTheme> createState() => _SmoothThemeState();
}

class _SmoothThemeState extends State<SmoothTheme>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
    value: 1,
  );

  late ThemeData _displayed = widget.theme;
  late ThemeData _from = widget.theme;
  ThemeData? _target;

  @override
  void didUpdateWidget(covariant SmoothTheme oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.theme != oldWidget.theme && widget.theme != _target) {
      _from = _displayed;
      _target = widget.theme;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_target == null) {
      return _SmoothThemeScope(theme: _displayed, child: widget.child);
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        if (_controller.isCompleted) {
          _displayed = _target!;
          _target = null;
          return _SmoothThemeScope(theme: _displayed, child: child!);
        }
        final t = Curves.easeInOutCubic.transform(_controller.value);
        _displayed = ThemeData.lerp(_from, _target!, t);
        return _SmoothThemeScope(theme: _displayed, child: child!);
      },
      child: widget.child,
    );
  }
}

class _SmoothThemeScope extends InheritedWidget {
  final ThemeData theme;

  const _SmoothThemeScope({required this.theme, required super.child});

  @override
  bool updateShouldNotify(_SmoothThemeScope oldWidget) =>
      theme != oldWidget.theme;
}
