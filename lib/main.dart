import 'package:flutter/material.dart';

import 'core/data/demo_data_seeder.dart';
import 'core/presentation/app_shell.dart';
import 'core/presentation/biometric_lock_screen.dart';
import 'core/repositories/app_services.dart';
import 'core/security/app_lock_controller.dart';
import 'core/security/biometric_auth.dart';
import 'core/theme/app_theme.dart';

/// Local-only startup.
///
/// The server authentication feature remains available for the future API
/// integration, but is intentionally not initialized or used here.
///
/// Startup is:
/// local services → local database/seed → one device-auth gate → app shell.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AppServices.instance.init();
  await DemoDataSeeder().seedIfNeeded();

  final lockController = AppLockController();
  await lockController.init();

  runApp(SalesErpApp(lockController: lockController));
}

class SalesErpApp extends StatefulWidget {
  final AppLockController? lockController;

  const SalesErpApp({super.key, this.lockController});

  @override
  State<SalesErpApp> createState() => _SalesErpAppState();
}

class _SalesErpAppState extends State<SalesErpApp> {
  late final AppThemeController _themeController;
  late final BiometricAuth _deviceAuth = BiometricAuth();

  @override
  void initState() {
    super.initState();
    _themeController = AppThemeController();
    _themeController.addListener(_onThemeChanged);
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

  void _recordActivity() {
    widget.lockController?.recordActivity();
  }

  Widget _buildHome() {
    final lock = widget.lockController;

    if (lock == null) {
      return AppShell(themeController: _themeController, onLock: () {});
    }

    if (lock.status == AppStatus.locked) {
      return BiometricLockScreen(
        auth: _deviceAuth,
        onUnlocked: lock.unlock,
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
    final lock = widget.lockController;
    final content = SmoothTheme(
      theme: _theme,
      child: Builder(
        builder: (context) => MaterialApp(
          title: 'Sales ERP',
          debugShowCheckedModeBanner: false,
          theme: SmoothTheme.of(context),
          home: StartupIntro(
            child: AnimatedSwitcher(
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
      ),
    );

    if (lock == null) return content;

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _recordActivity(),
      onPointerMove: (_) => _recordActivity(),
      child: content,
    );
  }

  Object _buildHomeBuildKey() {
    final lock = widget.lockController;
    if (lock != null && lock.status == AppStatus.locked) return 'locked';
    return 'shell';
  }
}

/// Globally animates theme changes.
class SmoothTheme extends StatefulWidget {
  final ThemeData theme;
  final Widget child;

  const SmoothTheme({super.key, required this.theme, required this.child});

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

/// Lightweight one-shot startup entrance animation.
class StartupIntro extends StatefulWidget {
  final Widget child;

  const StartupIntro({super.key, required this.child});

  @override
  State<StartupIntro> createState() => _StartupIntroState();
}

class _StartupIntroState extends State<StartupIntro>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  late final Animation<double> _contentFade = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );
  late final Animation<double> _contentScale = Tween<double>(
    begin: 0.985,
    end: 1.0,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  late final Animation<double> _brandFade = Tween<double>(begin: 1, end: 0)
      .animate(
    CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.45, 1.0, curve: Curves.easeIn),
    ),
  );

  bool _brandRemoved = false;

  @override
  void initState() {
    super.initState();
    _controller.forward();
    _controller.addStatusListener(_onStatus);
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && !_brandRemoved && mounted) {
      setState(() => _brandRemoved = true);
    }
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_onStatus);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      children: [
        FadeTransition(
          opacity: _contentFade,
          child: ScaleTransition(
            scale: _contentScale,
            child: widget.child,
          ),
        ),
        if (!_brandRemoved)
          IgnorePointer(
            child: FadeTransition(
              opacity: _brandFade,
              child: ColoredBox(
                color: theme.colorScheme.surface,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.point_of_sale_rounded,
                          size: 44,
                          color: theme.colorScheme.onPrimary,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Sales ERP',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
