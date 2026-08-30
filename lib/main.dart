import 'package:flutter/material.dart';

import 'core/data/demo_data_seeder.dart';
import 'core/presentation/app_shell.dart';
import 'core/presentation/biometric_lock_screen.dart';
import 'core/repositories/app_services.dart';
import 'core/security/app_lock_controller.dart';
import 'core/security/biometric_auth.dart';
import 'core/security/local_session.dart';
import 'core/security/pin_service.dart';
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
  late final PinService _pinService = PinService();
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
        bypassRequiresPin: false,
      );
    }

    if (lock.status == AppStatus.locked) {
      return BiometricLockScreen(
        auth: _biometricAuth,
        onUnlocked: lock.unlock,
        bypassLabel: 'Enter with PIN',
        pinService: _pinService,
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

/// Premium, lightweight one-shot startup entrance animation (~700ms).
///
/// Performance-first design:
/// - ONE AnimationController, composited via FadeTransition/ScaleTransition
///   (opacity/transform run on the compositor — no per-frame widget rebuilds
///   of the content tree).
/// - Theme-aware: only uses the active ThemeData (no new colors).
/// - Purely visual overlay with IgnorePointer: it NEVER blocks interaction,
///   and the child (including the biometric screen and its automatic
///   authentication attempt) mounts and runs immediately beneath it.
/// - After completion the brand overlay is removed entirely; the retained
///   transitions sit at identity values and cost nothing.
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

  // Content: subtle scale (0.985 → 1.0) + fade-in with easeOutCubic.
  late final Animation<double> _contentFade = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );
  late final Animation<double> _contentScale = Tween<double>(
    begin: 0.985,
    end: 1.0,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

  // Brand mark: visible briefly, then fades away during the second half.
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
        // The real app — mounted immediately so authentication/biometric
        // behaviour is never delayed by the intro.
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
