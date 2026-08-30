import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../security/biometric_auth.dart';
import '../security/pin_service.dart';
import '../theme/app_colors.dart';

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

  /// Optional bypass shown when biometrics are unavailable or fail. When this
  /// is 'Enter with PIN' the button reveals a PIN entry sheet and validates
  /// the entered PIN before invoking [onUnlocked].
  final String? bypassLabel;
  final VoidCallback? onBypass;

  /// Service used to validate the bypass PIN. Falls back to a default
  /// instance when not supplied.
  final PinService? pinService;

  /// When true the bypass button reveals the PIN entry sheet and validates
  /// the PIN before invoking [onUnlocked]. When false the bypass button
  /// invokes [onBypass] directly (e.g. first-run "Continue locally").
  final bool bypassRequiresPin;

  const BiometricLockScreen({
    super.key,
    required this.auth,
    required this.onUnlocked,
    this.bypassLabel,
    this.onBypass,
    this.pinService,
    this.bypassRequiresPin = true,
  });

  @override
  State<BiometricLockScreen> createState() => _BiometricLockScreenState();
}

class _BiometricLockScreenState extends State<BiometricLockScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scanController;
  late final PinService _pinService;
  _LockPhase _phase = _LockPhase.scanning;

  /// The device's strongest biometric capability, resolved at startup so the
  /// UI reflects the real method instead of hardcoding "Face ID".
  _BioCapability _capability = _BioCapability.generic;

  @override
  void initState() {
    super.initState();
    _pinService = widget.pinService ?? PinService();
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

  /// Handles the bypass button tap. When [bypassRequiresPin] is false this
  /// invokes [widget.onBypass] directly (first-run flow). Otherwise it
  /// reveals the PIN entry sheet and validates the entered PIN — only a
  /// correct PIN invokes [widget.onUnlocked]; an incorrect or cancelled
  /// attempt leaves the user on the authentication screen.
  Future<void> _requestPin() async {
    if (!widget.bypassRequiresPin) {
      widget.onBypass?.call();
      return;
    }
    final pin = await _PinEntrySheet.show(context, _pinService);
    if (pin == null) return; // cancelled
    final ok = await _pinService.validate(pin);
    if (!mounted) return;
    if (ok) {
      widget.onUnlocked();
    } else {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(content: Text('Incorrect PIN. Please try again.')),
        );
    }
  }

  /// One automatic biometric attempt per presentation, triggered after the
  /// screen is mounted, rendered AND the app is in the resumed lifecycle
  /// state — never during build(), never on rebuilds.
  ///
  /// Platform note: on Android, BiometricPrompt cannot display while the
  /// window is still regaining focus right after the app returns from the
  /// background. If the auto attempt fails before the user interacts, we
  /// retry a few times with short gaps until the window can actually show
  /// the prompt. This is a genuine platform focus constraint, not a delay
  /// used to mask a lifecycle bug.
  static const int _maxAutoRetries = 3;
  static const Duration _autoRetryGap = Duration(milliseconds: 700);
  int _autoRetries = 0;
  bool _userInteracted = false;

  Future<void> _start() async {
    if (_autoRetries > 0 || _userInteracted) return;
    // Wait for the first frame so the screen is actually mounted & visible.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    await _autoAttempt();
  }

  Future<void> _autoAttempt() async {
    final sw = Stopwatch()..start();
    await _attempt();
    sw.stop();
    if (!mounted || _userInteracted) return;
    if (_phase == _LockPhase.success) return;

    // A healthy prompt blocks for seconds. If authenticate() returned almost
    // instantly, the native prompt never actually appeared (window focus not
    // regained yet) → retry while the user has not interacted.
    final promptNeverAppeared =
        sw.elapsedMilliseconds < 400 && _phase == _LockPhase.failure;
    if (promptNeverAppeared && _autoRetries < _maxAutoRetries) {
      _autoRetries++;
      await Future<void>.delayed(_autoRetryGap);
      if (!mounted || _userInteracted) return;
      await _autoAttempt();
    }
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
    _userInteracted = true;
    _attempt();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _BackgroundGlow(colors: colors),
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
                            Image.asset(
                              'assets/images/sales_erp_logo.png',
                              width: 92,
                              height: 92,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) => Icon(
                                Icons.fingerprint_rounded,
                                size: 92,
                                color: colors.textPrimary,
                              ),
                            ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  Text(
                    'Sales ERP',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _message,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colors.textSecondary),
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
                      style: TextStyle(
                        color: colors.textMuted,
                        fontSize: 12,
                        letterSpacing: 0.4,
                      ),
                    ),
                  if (widget.bypassLabel != null && widget.onBypass != null) ...[
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _requestPin,
                      style: TextButton.styleFrom(
                        foregroundColor: colors.textSecondary,
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
    final colors = AppColors.of(context);
    return CustomPaint(
      painter: _BioRingPainter(progress, phase, colors),
      child: SizedBox(width: 180, height: 180, child: Center(child: child)),
    );
  }
}

class _BioRingPainter extends CustomPainter {
  final double progress;
  final _LockPhase phase;
  final AppColors colors;

  _BioRingPainter(this.progress, this.phase, this.colors);

  double get _sweep =>
      phase == _LockPhase.success ? math.pi * 2 : 0.6 + progress * 0.4;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 6;

    final back = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = colors.textPrimary.withValues(alpha: .15);
    canvas.drawCircle(center, radius, back);

    final progressPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: math.pi * 1.5,
        colors: [
          colors.primary.withValues(alpha: .2),
          colors.primary,
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
  final AppColors colors;

  const _BackgroundGlow({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colors.background,
                colors.surfaceElevated,
                Color.lerp(colors.background, colors.primary, 0.14)!,
              ],
            ),
          ),
        ),
        _RadialBlob(
          alignment: Alignment(-0.9, -0.9),
          color: colors.primary.withValues(alpha: 0.20),
          size: 260,
        ),
        _RadialBlob(
          alignment: Alignment(1.0, 1.0),
          color: colors.secondary.withValues(alpha: 0.18),
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
    final colors = AppColors.of(context);
    return CustomPaint(
      painter: _ScanFramePainter(progress, phase, colors),
      child: child,
    );
  }
}

class _ScanFramePainter extends CustomPainter {
  final double progress;
  final _LockPhase phase;
  final AppColors colors;

  _ScanFramePainter(this.progress, this.phase, this.colors);

  @override
  void paint(Canvas canvas, Size size) {
    final left = 14.0;
    final top = 14.0;
    final right = size.width - 14;
    final bottom = size.height - 14;
    final bracket = 22.0;
    final paint = Paint()
      ..color = colors.textPrimary.withValues(alpha: 0.55)
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
            colors.textPrimary.withValues(alpha: 0),
            colors.primary.withValues(alpha: 0.9),
            colors.textPrimary.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromLTRB(left, 0, right, 0))
        ..strokeWidth = 1.6;
      canvas.drawLine(Offset(left, y), Offset(right, y), linePaint);
    } else if (phase == _LockPhase.success) {
      final ringPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = colors.success.withValues(alpha: 0.9);
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

/// A lightweight modal bottom sheet that captures a 4–6 digit PIN. Returns the
/// entered PIN on confirm, or null when the user dismisses the sheet.
class _PinEntrySheet {
  static Future<String?> show(BuildContext context, PinService pinService) {
    final colors = AppColors.of(context);
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _PinEntryBody(colors: colors),
    );
  }
}

class _PinEntryBody extends StatefulWidget {
  final AppColors colors;

  const _PinEntryBody({required this.colors});

  @override
  State<_PinEntryBody> createState() => _PinEntryBodyState();
}

class _PinEntryBodyState extends State<_PinEntryBody> {
  final TextEditingController _controller = TextEditingController();
  bool _obscured = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    Navigator.of(context).pop(value.isEmpty ? null : value);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final colors = widget.colors;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 20, 24, 20 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Enter PIN',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Enter your device PIN to unlock.',
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _controller,
            autofocus: true,
            obscureText: _obscured,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 6,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              letterSpacing: 6,
              color: colors.textPrimary,
            ),
            decoration: InputDecoration(
              counterText: '',
              filled: true,
              fillColor: colors.surfaceMuted,
              hintText: '••••',
              hintStyle: TextStyle(
                color: colors.textMuted,
                letterSpacing: 6,
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscured ? Icons.visibility_off : Icons.visibility,
                  color: colors.textMuted,
                ),
                onPressed: () => setState(() => _obscured = !_obscured),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: colors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: colors.primary, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _submit,
            style: FilledButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: colors.surface,
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'Unlock',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(foregroundColor: colors.textSecondary),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}
