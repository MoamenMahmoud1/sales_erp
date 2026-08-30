import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../security/biometric_auth.dart';

/// The current lock phase shown on the screen.
enum _LockPhase { scanning, success, failure }

/// The actual biometric capability reported by the OS.
enum _BioCapability { face, fingerprint, generic }

/// Premium biometric lock screen with a futuristic scanning visualization,
/// rotating rings, corner brackets and status feedback. Includes an optional
/// development bypass so the user is never trapped without biometric hardware.
class BiometricLockScreen extends StatefulWidget {
  final BiometricAuth auth;
  final VoidCallback onUnlocked;

  /// Optional development bypass shown when biometrics are unavailable or fail.
  final String? bypassLabel;
  final VoidCallback? onBypass;

  const BiometricLockScreen({
    super.key,
    required this.auth,
    required this.onUnlocked,
    this.bypassLabel,
    this.onBypass,
  });

  @override
  State<BiometricLockScreen> createState() => _BiometricLockScreenState();
}

class _BiometricLockScreenState extends State<BiometricLockScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scanController;
  _LockPhase _phase = _LockPhase.scanning;

  /// The device's strongest biometric capability, resolved at startup so the
  /// UI reflects the real method instead of hardcoding "Face ID".
  _BioCapability _capability = _BioCapability.generic;
  bool _autoAttempted = false;

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
    _resolveCapability();
    _start();
  }

  Future<void> _resolveCapability() async {
    if (await widget.auth.supportsFace()) {
      _capability = _BioCapability.face;
    } else if (await widget.auth.supportsFingerprint()) {
      _capability = _BioCapability.fingerprint;
    } else {
      _capability = _BioCapability.generic;
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _scanController.dispose();
    super.dispose();
  }

  /// One automatic biometric attempt per presentation, triggered after the
  /// screen is mounted & rendered — never during build(), never on rebuilds.
  Future<void> _start() async {
    if (_autoAttempted) return;
    _autoAttempted = true;
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    await _attempt();
  }

  Future<void> _attempt() async {
    if (!mounted) return;
    setState(() => _phase = _LockPhase.scanning);
    final result = await widget.auth.authenticate();
    if (!mounted) return;

    switch (result) {
      case BiometricResult.success:
        _scanController.stop();
        setState(() => _phase = _LockPhase.success);
        HapticFeedback.heavyImpact();
        await Future<void>.delayed(const Duration(milliseconds: 420));
        if (mounted) widget.onUnlocked();
      case BiometricResult.failed:
      case BiometricResult.unavailable:
        setState(() => _phase = _LockPhase.failure);
        HapticFeedback.mediumImpact();
        break;
    }
  }

  void _retry() {
    _attempt();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: const Color(0xFF0F1118),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _BackgroundGlow(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _scanController,
                    builder: (context, child) => _ScanFrame(
                      progress: _scanController.value,
                      phase: _phase,
                      child: _BioRing(
                        progress: _scanController.value,
                        phase: _phase,
                        child: child ??
                            const Icon(
                              Icons.fingerprint_rounded,
                              size: 92,
                              color: Colors.white,
                            ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  Text(
                    'Sales ERP',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _message,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white.withValues(alpha: .7)),
                  ),
                  const SizedBox(height: 40),
                  if (_phase == _LockPhase.failure)
                    FilledButton.tonal(
                      onPressed: _retry,
                      style: FilledButton.styleFrom(
                        backgroundColor: scheme.primary.withValues(alpha: .2),
                        foregroundColor: scheme.primary.withValues(alpha: .95),
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(_biometricActionLabel),
                    )
                  else
                    Text(
                      _capabilityLabel,
                      style: const TextStyle(
                        color: Color(0x8CFFFFFF),
                        fontSize: 12,
                        letterSpacing: 0.4,
                      ),
                    ),
                  if (widget.bypassLabel != null && widget.onBypass != null) ...[
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: widget.onBypass,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white.withValues(alpha: .7),
                      ),
                      child: Text(widget.bypassLabel!),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String get _message {
    switch (_phase) {
      case _LockPhase.scanning:
        return 'Hold your finger or look at the screen to unlock.';
      case _LockPhase.success:
        return 'Unlocked. Welcome back.';
      case _LockPhase.failure:
        return 'Not recognized. Please try again.';
    }
  }

  String get _capabilityLabel {
    switch (_capability) {
      case _BioCapability.face:
        return 'Face Unlock  -  Device security';
      case _BioCapability.fingerprint:
        return 'Fingerprint  -  Device security';
      case _BioCapability.generic:
        return 'Biometric authentication  -  Device security';
    }
  }

  String get _biometricActionLabel {
    switch (_capability) {
      case _BioCapability.face:
        return 'Use Face Unlock';
      case _BioCapability.fingerprint:
        return 'Use fingerprint';
      case _BioCapability.generic:
        return 'Use biometric authentication';
    }
  }
}

/// Rotating ring around the biometric icon that fills on success.
class _BioRing extends StatelessWidget {
  final double progress;
  final _LockPhase phase;
  final Widget child;

  const _BioRing({
    required this.progress,
    required this.phase,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BioRingPainter(progress, phase),
      child: SizedBox(width: 180, height: 180, child: Center(child: child)),
    );
  }
}

class _BioRingPainter extends CustomPainter {
  final double progress;
  final _LockPhase phase;

  _BioRingPainter(this.progress, this.phase);

  double get _sweep =>
      phase == _LockPhase.success ? math.pi * 2 : 0.6 + progress * 0.4;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 6;

    final back = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = Colors.white.withValues(alpha: .15);
    canvas.drawCircle(center, radius, back);

    final progressPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: math.pi * 1.5,
        colors: [
          Colors.white.withValues(alpha: .2),
          Colors.white,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    final startAngle = -math.pi / 2 + progress * math.pi * 2;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      _sweep,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _BioRingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.phase != phase;
}

/// Deep-space gradient background.

class _BackgroundGlow extends StatelessWidget {
  const _BackgroundGlow();

  @override
  Widget build(BuildContext context) {
    return const Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF0F1118),
                Color(0xFF131624),
                Color(0xFF1A1F3A),
              ],
            ),
          ),
        ),
        _RadialBlob(
          alignment: Alignment(-0.9, -0.9),
          color: Color(0x33344B8E),
          size: 260,
        ),
        _RadialBlob(
          alignment: Alignment(1.0, 1.0),
          color: Color(0x2E625A86),
          size: 300,
        ),
      ],
    );
  }
}

class _RadialBlob extends StatelessWidget {
  final Alignment alignment;
  final Color color;
  final double size;

  const _RadialBlob({
    required this.alignment,
    required this.color,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, Colors.transparent]),
        ),
      ),
    );
  }
}

/// Futuristic scanning frame: corner brackets + a sweeping scan line, plus a
/// success ring when authenticated.
class _ScanFrame extends StatelessWidget {
  final double progress;
  final _LockPhase phase;
  final Widget child;

  const _ScanFrame({
    required this.progress,
    required this.phase,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ScanFramePainter(progress, phase),
      child: child,
    );
  }
}

class _ScanFramePainter extends CustomPainter {
  final double progress;
  final _LockPhase phase;

  _ScanFramePainter(this.progress, this.phase);

  @override
  void paint(Canvas canvas, Size size) {
    final left = 14.0;
    final top = 14.0;
    final right = size.width - 14;
    final bottom = size.height - 14;
    final bracket = 22.0;
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(left, top + bracket)
      ..lineTo(left, top)
      ..lineTo(left + bracket, top)
      ..moveTo(right - bracket, top)
      ..lineTo(right, top)
      ..lineTo(right, top + bracket)
      ..moveTo(right, bottom - bracket)
      ..lineTo(right, bottom)
      ..lineTo(right - bracket, bottom)
      ..moveTo(left + bracket, bottom)
      ..lineTo(left, bottom)
      ..lineTo(left, bottom - bracket);
    canvas.drawPath(path, paint);

    if (phase == _LockPhase.scanning) {
      final y = top + (bottom - top) * ((progress * 2) % 1);
      final linePaint = Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0),
            Color(0xFF7185D1).withValues(alpha: 0.9),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromLTRB(left, 0, right, 0))
        ..strokeWidth = 1.6;
      canvas.drawLine(Offset(left, y), Offset(right, y), linePaint);
    } else if (phase == _LockPhase.success) {
      final ringPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Color(0xFF619A7D).withValues(alpha: 0.9);
      canvas.drawCircle(
        size.center(Offset.zero),
        size.shortestSide / 2 - 10,
        ringPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ScanFramePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.phase != phase;
}
