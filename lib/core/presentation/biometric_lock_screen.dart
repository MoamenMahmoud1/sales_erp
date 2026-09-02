import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

import '../security/biometric_auth.dart';

/// Full-screen local authentication gate.
///
/// Priority is:
/// 1. Face, when enrolled and exposed by the OS.
/// 2. Fingerprint, when enrolled and Face is not available.
/// 3. Device PIN/password/passcode when no biometric is enrolled.
///
/// The OS chooses the actual biometric prompt UI. The app never stores or
/// receives the device credential.
class BiometricLockScreen extends StatefulWidget {
  final BiometricAuth auth;
  final VoidCallback onUnlocked;

  const BiometricLockScreen({
    super.key,
    required this.auth,
    required this.onUnlocked,
  });

  @override
  State<BiometricLockScreen> createState() => _BiometricLockScreenState();
}

enum _AuthMethod { face, fingerprint, biometric, deviceCredential }

enum _AuthPhase { authenticating, failed, success }

class _BiometricLockScreenState extends State<BiometricLockScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;

  Set<BiometricType> _available = const {};
  _AuthMethod _method = _AuthMethod.deviceCredential;
  _AuthPhase _phase = _AuthPhase.authenticating;
  bool _attemptInFlight = false;
  bool _autoAttemptStarted = false;
  bool _deviceCredentialOffered = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _prepare();
  }

  Future<void> _prepare() async {
    _available = await widget.auth.availableBiometrics();
    if (mounted) setState(() => _method = _preferredMethod);

    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || _autoAttemptStarted) return;
    _autoAttemptStarted = true;
    await _attempt(_method, automatic: true);
  }

  _AuthMethod get _preferredMethod {
    if (_available.contains(BiometricType.face)) return _AuthMethod.face;
    if (_available.contains(BiometricType.fingerprint)) {
      return _AuthMethod.fingerprint;
    }
    if (_available.isNotEmpty) return _AuthMethod.biometric;
    return _AuthMethod.deviceCredential;
  }

  Future<void> _attempt(
    _AuthMethod method, {
    bool automatic = false,
  }) async {
    if (!mounted || _attemptInFlight) return;
    _attemptInFlight = true;
    setState(() {
      _method = method;
      _phase = _AuthPhase.authenticating;
      _animationController
        ..stop()
        ..value = 0;
    });

    final result = method == _AuthMethod.deviceCredential
        ? await widget.auth.authenticateDeviceCredential()
        : await widget.auth.authenticateBiometric();

    if (!mounted) return;

    if (result == BiometricResult.success) {
      setState(() => _phase = _AuthPhase.success);
      await _animationController.forward();
      HapticFeedback.heavyImpact();
      if (mounted) widget.onUnlocked();
    } else {
      setState(() => _phase = _AuthPhase.failed);
      await _animationController.forward();
      HapticFeedback.mediumImpact();

      if (automatic && method != _AuthMethod.deviceCredential) {
        _deviceCredentialOffered = true;
        if (mounted) setState(() {});
      }
    }

    _attemptInFlight = false;
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  String get _title {
    switch (_method) {
      case _AuthMethod.face:
        return 'Face authentication';
      case _AuthMethod.fingerprint:
        return 'Fingerprint authentication';
      case _AuthMethod.biometric:
        return 'Biometric authentication';
      case _AuthMethod.deviceCredential:
        return 'Phone PIN or password';
    }
  }

  String get _subtitle {
    switch (_phase) {
      case _AuthPhase.authenticating:
        return 'Authenticate once to unlock Sales ERP on this app session.';
      case _AuthPhase.failed:
        return _method == _AuthMethod.deviceCredential
            ? 'That device credential was not accepted. Try again.'
            : 'That biometric was not accepted. Try again or use your phone credential.';
      case _AuthPhase.success:
        return 'Authentication successful. Welcome back.';
    }
  }

  IconData get _methodIcon {
    switch (_method) {
      case _AuthMethod.face:
        return Icons.face_retouching_natural_rounded;
      case _AuthMethod.fingerprint:
      case _AuthMethod.biometric:
        return Icons.fingerprint_rounded;
      case _AuthMethod.deviceCredential:
        return Icons.lock_rounded;
    }
  }

  String get _primaryAction {
    switch (_method) {
      case _AuthMethod.face:
        return 'Use Face';
      case _AuthMethod.fingerprint:
        return 'Use fingerprint';
      case _AuthMethod.biometric:
        return 'Use biometric';
      case _AuthMethod.deviceCredential:
        return 'Use phone PIN / password';
    }
  }

  Widget _buildAuthIcon(ColorScheme scheme) {
    final progress = _animationController.value;
    final failed = _phase == _AuthPhase.failed;
    final success = _phase == _AuthPhase.success;

    var scale = 1.0;
    var rotation = 0.0;
    var dx = 0.0;
    var dy = 0.0;

    if (_phase == _AuthPhase.authenticating) {
      final pulse = (math.sin(progress * math.pi * 2) + 1) / 2;
      scale = 1.0 + pulse * 0.035;
    } else if (failed) {
      switch (_method) {
        case _AuthMethod.face:
          dx = math.sin(progress * math.pi * 6) * (1 - progress) * 8;
        case _AuthMethod.fingerprint:
          scale = 1.0 + 0.06 * math.sin(progress * math.pi) * (1 - progress);
        case _AuthMethod.biometric:
          rotation = math.sin(progress * math.pi * 4) * 0.05 * (1 - progress);
        case _AuthMethod.deviceCredential:
          dy = -math.sin(progress * math.pi * 5) * (1 - progress) * 7;
      }
    } else if (success) {
      switch (_method) {
        case _AuthMethod.face:
          scale = 1.0 + 0.10 * progress;
          rotation = 0.04 * math.sin(progress * math.pi);
        case _AuthMethod.fingerprint:
          scale = 1.0 + 0.14 * math.sin(progress * math.pi / 2);
        case _AuthMethod.biometric:
          scale = 1.0 + 0.08 * progress;
          rotation = -0.025 * progress;
        case _AuthMethod.deviceCredential:
          dy = -10 * progress;
          scale = 1.0 + 0.05 * progress;
      }
    }

    final color = failed ? scheme.error : scheme.primary;
    final icon = success ? Icons.verified_rounded : _methodIcon;

    return Transform.translate(
      offset: Offset(dx, dy),
      child: Transform.rotate(
        angle: rotation,
        child: Transform.scale(
          scale: scale,
          child: Container(
            width: 132,
            height: 132,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: success
                  ? scheme.primaryContainer
                  : scheme.surfaceContainerHigh,
              border: Border.all(
                color: failed
                    ? scheme.error.withValues(alpha: 0.7)
                    : scheme.primary.withValues(alpha: 0.3),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.14),
                  blurRadius: 28,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, animation) => ScaleTransition(
                scale: CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutBack,
                ),
                child: FadeTransition(opacity: animation, child: child),
              ),
              child: Icon(
                icon,
                key: ValueKey<Object>('$success-$_method'),
                size: 64,
                color: color,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isSuccess = _phase == _AuthPhase.success;

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              scheme.surface,
              scheme.surfaceContainerHighest,
              scheme.primaryContainer.withValues(alpha: 0.42),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedBuilder(
                      animation: _animationController,
                      builder: (context, _) => _buildAuthIcon(scheme),
                    ),
                    const SizedBox(height: 30),
                    Text(
                      'Sales ERP',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: Text(
                        _title,
                        key: ValueKey(_title),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _subtitle,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 26),
                    if (!isSuccess)
                      FilledButton.icon(
                        onPressed: _attemptInFlight
                            ? null
                            : () => _attempt(_method),
                        icon: Icon(_methodIcon),
                        label: Text(
                          _phase == _AuthPhase.failed
                              ? 'Try again'
                              : _primaryAction,
                        ),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(54),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    if (!isSuccess &&
                        _deviceCredentialOffered &&
                        _method != _AuthMethod.deviceCredential) ...[
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: _attemptInFlight
                            ? null
                            : () => _attempt(_AuthMethod.deviceCredential),
                        icon: const Icon(Icons.lock_rounded),
                        label: const Text('Use phone PIN / password'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.shield_outlined,
                          size: 15,
                          color: scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 7),
                        Text(
                          'Protected by your phone security',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
