import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

import '../security/biometric_auth.dart';
import '../security/pin_service.dart';

/// Full-screen local authentication gate.
///
/// The screen performs one automatic biometric attempt per presentation.
/// Additional attempts are explicit user actions only.
class BiometricLockScreen extends StatefulWidget {
  final BiometricAuth auth;
  final VoidCallback onUnlocked;
  final String? bypassLabel;
  final VoidCallback? onBypass;
  final PinService? pinService;
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
  late final AnimationController _pulseController;
  late final PinService _pinService;

  BiometricResult? _result;
  Set<BiometricType> _available = const {};
  bool _attemptInFlight = false;
  bool _autoAttemptStarted = false;

  @override
  void initState() {
    super.initState();
    _pinService = widget.pinService ?? PinService();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
      lowerBound: 0.96,
      upperBound: 1.0,
      value: 0.98,
    )..repeat(reverse: true);
    _loadCapabilityAndAuthenticate();
  }

  Future<void> _loadCapabilityAndAuthenticate() async {
    _available = await widget.auth.availableBiometrics();
    if (mounted) setState(() {});

    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || _autoAttemptStarted) return;
    _autoAttemptStarted = true;
    await _attempt();
  }

  Future<void> _attempt() async {
    if (!mounted || _attemptInFlight) return;
    _attemptInFlight = true;
    setState(() => _result = null);

    try {
      final result = await widget.auth.authenticate();
      if (!mounted) return;
      setState(() => _result = result);
      if (result == BiometricResult.success) {
        HapticFeedback.heavyImpact();
        await Future<void>.delayed(const Duration(milliseconds: 220));
        if (mounted) widget.onUnlocked();
      } else {
        HapticFeedback.mediumImpact();
      }
    } finally {
      _attemptInFlight = false;
    }
  }

  Future<void> _requestBypass() async {
    if (!widget.bypassRequiresPin) {
      widget.onBypass?.call();
      return;
    }

    final pin = await _PinEntrySheet.show(context);
    if (!mounted || pin == null) return;

    final valid = await _pinService.validate(pin);
    if (!mounted) return;
    if (valid) {
      widget.onUnlocked();
      return;
    }

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        const SnackBar(content: Text('Incorrect PIN. Please try again.')),
      );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  String get _methodLabel {
    if (_available.contains(BiometricType.face)) return 'Face authentication';
    if (_available.contains(BiometricType.fingerprint)) {
      return 'Fingerprint authentication';
    }
    if (_available.isNotEmpty) return 'Biometric authentication';
    return 'Device authentication';
  }

  String get _description {
    switch (_result) {
      case BiometricResult.success:
        return 'Authentication successful.';
      case BiometricResult.failed:
        return 'Authentication was not completed. You can try again.';
      case BiometricResult.unavailable:
        return 'Biometric authentication is not available on this device.';
      case null:
        return 'Use your device biometric to continue to Sales ERP.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final failed =
        _result == BiometricResult.failed ||
        _result == BiometricResult.unavailable;
    final success = _result == BiometricResult.success;

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              scheme.surface,
              scheme.surfaceContainerHighest,
              scheme.primaryContainer.withValues(alpha: 0.45),
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
                    ScaleTransition(
                      scale: _pulseController,
                      child: Container(
                        width: 124,
                        height: 124,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: scheme.primaryContainer,
                          border: Border.all(
                            color: scheme.primary.withValues(alpha: 0.28),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: scheme.primary.withValues(alpha: 0.16),
                              blurRadius: 28,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: Icon(
                          success
                              ? Icons.verified_rounded
                              : Icons.fingerprint_rounded,
                          size: 62,
                          color: scheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    Text(
                      'Sales ERP',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      success ? 'Unlocked' : 'Secure local access',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _description,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 26),
                    if (!success)
                      FilledButton.icon(
                        onPressed: _attemptInFlight ? null : _attempt,
                        icon: Icon(
                          _available.contains(BiometricType.face)
                              ? Icons.face_retouching_natural_rounded
                              : Icons.fingerprint_rounded,
                        ),
                        label: Text(
                          failed ? 'Try $_methodLabel' : 'Use $_methodLabel',
                        ),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(54),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    if (widget.bypassLabel != null &&
                        widget.onBypass != null &&
                        !success) ...[
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: _requestBypass,
                        child: Text(widget.bypassLabel!),
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
                          'Protected by your device security',
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

class _PinEntrySheet extends StatefulWidget {
  const _PinEntrySheet();

  static Future<String?> show(BuildContext context) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => const _PinEntrySheet(),
    );
  }

  @override
  State<_PinEntrySheet> createState() => _PinEntrySheetState();
}

class _PinEntrySheetState extends State<_PinEntrySheet> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        8,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Enter PIN',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Use your local PIN to unlock Sales ERP.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _controller,
              autofocus: true,
              obscureText: true,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              maxLength: 6,
              onFieldSubmitted: (_) => _submit(),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'PIN',
                prefixIcon: Icon(Icons.pin_rounded),
                counterText: '',
              ),
              validator: (value) {
                final pin = value ?? '';
                if (pin.length < 4 || pin.length > 6) {
                  return 'PIN must contain 4–6 digits.';
                }
                return null;
              },
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _submit,
              child: const Text('Unlock'),
            ),
          ],
        ),
      ),
    );
  }
}
