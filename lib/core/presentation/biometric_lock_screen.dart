import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

import '../security/biometric_auth.dart';

/// Full-screen local authentication gate.
///
/// Sales ERP owns the lock-screen UI/UX. The native biometric prompt is only
/// requested after the user explicitly chooses a method and taps Unlock.
/// The actual biometric/device credential verification remains OS-owned.
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

enum _AuthPhase { ready, authenticating, failed, success }

class _BiometricLockScreenState extends State<BiometricLockScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;

  Set<BiometricType> _available = const {};
  _AuthMethod _method = _AuthMethod.deviceCredential;
  _AuthPhase _phase = _AuthPhase.ready;
  bool _attemptInFlight = false;
  bool _deviceCredentialAvailable = false;

  List<_AuthMethod> get _methods {
    final methods = <_AuthMethod>[];
    if (_available.contains(BiometricType.face)) {
      methods.add(_AuthMethod.face);
    }
    if (_available.contains(BiometricType.fingerprint)) {
      methods.add(_AuthMethod.fingerprint);
    }
    if (_available.isNotEmpty &&
        !methods.contains(_AuthMethod.face) &&
        !methods.contains(_AuthMethod.fingerprint)) {
      methods.add(_AuthMethod.biometric);
    }
    if (_deviceCredentialAvailable) {
      methods.add(_AuthMethod.deviceCredential);
    }
    return methods;
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
      lowerBound: 0.0,
      upperBound: 1.0,
      value: 0.0,
    );
    _prepare();
  }

  Future<void> _prepare() async {
    final available = await widget.auth.availableBiometrics(refresh: true);
    final credentialAvailable = await widget.auth.isDeviceSupported();
    if (!mounted) return;

    _available = available;
    _deviceCredentialAvailable = credentialAvailable;

    final methods = _methods;
    final preferred = methods.isEmpty
        ? _AuthMethod.deviceCredential
        : methods.first;

    setState(() {
      _method = preferred;
      _phase = _AuthPhase.ready;
    });
  }

  void _selectMethod(_AuthMethod method) {
    if (_attemptInFlight || _phase == _AuthPhase.success) return;

    setState(() {
      _method = method;
      _phase = _AuthPhase.ready;
      _animationController
        ..stop()
        ..value = 0.0;
    });
  }

  Future<void> _attempt(_AuthMethod method) async {
    if (!mounted || _attemptInFlight) return;

    _attemptInFlight = true;
    setState(() {
      _method = method;
      _phase = _AuthPhase.authenticating;
      _animationController
        ..stop()
        ..value = 0.0;
    });

    final result = switch (method) {
      _AuthMethod.face => await widget.auth.authenticateBiometric(
          method: BiometricMethod.face,
        ),
      _AuthMethod.fingerprint => await widget.auth.authenticateBiometric(
          method: BiometricMethod.fingerprint,
        ),
      _AuthMethod.biometric => await widget.auth.authenticateBiometric(
          method: BiometricMethod.generic,
        ),
      _AuthMethod.deviceCredential =>
          await widget.auth.authenticateDeviceCredential(),
    };

    if (!mounted) {
      _attemptInFlight = false;
      return;
    }

    if (result == BiometricResult.success) {
      setState(() => _phase = _AuthPhase.success);
      await _animationController.forward(from: 0.0);
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      widget.onUnlocked();
    } else {
      setState(() => _phase = _AuthPhase.failed);
      await _animationController.forward(from: 0.0);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
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
        return 'Unlock with Face';
      case _AuthMethod.fingerprint:
        return 'Unlock with Fingerprint';
      case _AuthMethod.biometric:
        return 'Unlock with Biometrics';
      case _AuthMethod.deviceCredential:
        return 'Unlock with Phone PIN';
    }
  }

  String get _subtitle {
    switch (_phase) {
      case _AuthPhase.ready:
        return 'Choose a security method, then tap Unlock.';
      case _AuthPhase.authenticating:
        return 'Waiting for your phone to verify you.';
      case _AuthPhase.failed:
        return 'Verification was not accepted. Try again or choose another method.';
      case _AuthPhase.success:
        return 'Verified. Opening Sales ERP.';
    }
  }

  String _methodLabel(_AuthMethod method) {
    switch (method) {
      case _AuthMethod.face:
        return 'Face';
      case _AuthMethod.fingerprint:
        return 'Fingerprint';
      case _AuthMethod.biometric:
        return 'Biometric';
      case _AuthMethod.deviceCredential:
        return 'Phone PIN';
    }
  }

  IconData _methodIconFor(_AuthMethod method) {
    switch (method) {
      case _AuthMethod.face:
        return Icons.face_retouching_natural_rounded;
      case _AuthMethod.fingerprint:
        return Icons.fingerprint_rounded;
      case _AuthMethod.biometric:
        return Icons.fingerprint_rounded;
      case _AuthMethod.deviceCredential:
        return Icons.lock_rounded;
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
      scale = 1.0 + 0.08 * progress;
      rotation = 0.025 * math.sin(progress * math.pi);
    }

    final color = failed ? scheme.error : scheme.primary;
    final icon = success ? Icons.verified_rounded : _methodIconFor(_method);

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
              duration: const Duration(milliseconds: 180),
              transitionBuilder: (child, animation) => ScaleTransition(
                scale: CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                ),
                child: FadeTransition(
                  opacity: animation,
                  child: child,
                ),
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

  Widget _methodSelector(ColorScheme scheme, ThemeData theme) {
    final methods = _methods;
    if (methods.length <= 1 || _phase == _AuthPhase.success) {
      return const SizedBox.shrink();
    }

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final method in methods)
          ChoiceChip(
            selected: _method == method,
            avatar: Icon(
              _methodIconFor(method),
              size: 18,
              color: _method == method
                  ? scheme.primary
                  : scheme.onSurfaceVariant,
            ),
            label: Text(_methodLabel(method)),
            backgroundColor: scheme.surfaceContainerHighest,
            selectedColor: scheme.primaryContainer,
            side: BorderSide(
              color: _method == method
                  ? scheme.primary
                  : scheme.outlineVariant,
              width: _method == method ? 1.5 : 1,
            ),
            labelStyle: theme.textTheme.labelLarge?.copyWith(
              color: _method == method
                  ? scheme.onPrimaryContainer
                  : scheme.onSurface,
              fontWeight:
                  _method == method ? FontWeight.w700 : FontWeight.w600,
            ),
            showCheckmark: false,
            onSelected: _attemptInFlight ? null : (_) => _selectMethod(method),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isSuccess = _phase == _AuthPhase.success;
    final hasMethod = _methods.isNotEmpty;

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
                    const SizedBox(height: 20),
                    _methodSelector(scheme, theme),
                    const SizedBox(height: 20),
                    if (!isSuccess)
                      FilledButton.icon(
                        onPressed: _attemptInFlight || !hasMethod
                            ? null
                            : () => _attempt(_method),
                        icon: Icon(_methodIconFor(_method)),
                        label: Text(
                          _phase == _AuthPhase.failed ? 'Try again' : 'Unlock',
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: scheme.primary,
                          foregroundColor: scheme.onPrimary,
                          disabledBackgroundColor:
                              scheme.surfaceContainerHighest,
                          disabledForegroundColor: scheme.onSurfaceVariant,
                          elevation: 2,
                          minimumSize: const Size.fromHeight(54),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    if (!hasMethod) ...[
                      const SizedBox(height: 12),
                      Text(
                        'No supported device authentication method is available.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.error,
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
                        Flexible(
                          child: Text(
                            'Protected by your phone security',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
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
