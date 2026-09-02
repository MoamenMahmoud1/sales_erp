import 'package:flutter/material.dart';

import '../../domain/entities/car_financial_summary.dart';

class CarClosingAnimation extends StatefulWidget {
  final String displayNumber;
  final CarFinancialSummary summary;
  final VoidCallback? onComplete;

  const CarClosingAnimation({
    super.key,
    required this.displayNumber,
    required this.summary,
    this.onComplete,
  });

  @override
  State<CarClosingAnimation> createState() => _CarClosingAnimationState();
}

class _CarClosingAnimationState extends State<CarClosingAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )
    ..addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onComplete?.call();
    });

  late final Animation<double> _truck = Tween<double>(begin: -1.2, end: .18)
      .animate(CurvedAnimation(parent: _controller, curve: const Interval(0, .38, curve: Curves.easeOutCubic)));
  late final Animation<double> _box = CurvedAnimation(
    parent: _controller,
    curve: const Interval(.30, .62, curve: Curves.easeOutCubic),
  );
  late final Animation<double> _numbers = CurvedAnimation(
    parent: _controller,
    curve: const Interval(.52, .82, curve: Curves.easeOutCubic),
  );
  late final Animation<double> _success = CurvedAnimation(
    parent: _controller,
    curve: const Interval(.80, 1, curve: Curves.easeOutBack),
  );

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final summary = widget.summary;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Spacer(),
                  Text(
                    'Finalizing car ${widget.displayNumber}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Processing the return and recording the completed sale',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 34),
                  SizedBox(
                    height: 170,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final left = ((constraints.maxWidth - 92) * _truck.value).clamp(-96.0, constraints.maxWidth - 92);
                        return Stack(
                          alignment: Alignment.bottomCenter,
                          children: [
                            Positioned(
                              left: 14,
                              right: 14,
                              bottom: 22,
                              child: Container(
                                height: 5,
                                decoration: BoxDecoration(
                                  color: scheme.outlineVariant,
                                  borderRadius: BorderRadius.circular(99),
                                ),
                              ),
                            ),
                            Positioned(
                              right: 22,
                              bottom: 26,
                              child: Transform.scale(
                                scale: .9 + (_success.value * .1),
                                child: Container(
                                  width: 96,
                                  height: 100,
                                  decoration: BoxDecoration(
                                    color: scheme.primaryContainer,
                                    borderRadius: BorderRadius.circular(22),
                                    border: Border.all(color: scheme.primary.withValues(alpha: .35)),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.inventory_2_rounded, color: scheme.primary, size: 34),
                                      const SizedBox(height: 6),
                                      const Text('WAREHOUSE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              left: left,
                              bottom: 26,
                              child: Transform.translate(
                                offset: Offset(0, -12 * _box.value),
                                child: Row(
                                  children: [
                                    Icon(Icons.local_shipping_rounded, size: 76, color: scheme.primary),
                                    const SizedBox(width: 3),
                                    if (_box.value > .2)
                                      _AnimatedCartons(progress: _box.value, color: scheme.secondary),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 22),
                  _MetricRow(
                    label: 'Loaded',
                    value: summary.totalLoadedCartons,
                    progress: _numbers.value,
                    icon: Icons.outbox_rounded,
                  ),
                  _MetricRow(
                    label: 'Returned',
                    value: summary.totalReturnedCartons,
                    progress: Curves.easeOut.transform((_numbers.value - .18).clamp(0, 1)),
                    icon: Icons.assignment_return_rounded,
                  ),
                  _MetricRow(
                    label: 'Sold',
                    value: summary.totalSoldCartons,
                    progress: Curves.easeOut.transform((_numbers.value - .32).clamp(0, 1)),
                    icon: Icons.point_of_sale_rounded,
                  ),
                  const SizedBox(height: 14),
                  Opacity(
                    opacity: _success.value,
                    child: Transform.scale(
                      scale: .92 + .08 * _success.value,
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: scheme.primary,
                              foregroundColor: scheme.onPrimary,
                              child: const Icon(Icons.check_rounded),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Car transaction confirmed', style: TextStyle(fontWeight: FontWeight.w900)),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${summary.finalTotalSoldValue.units.toStringAsFixed(2)} EGP actual sold value',
                                    style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _AnimatedCartons extends StatelessWidget {
  final double progress;
  final Color color;

  const _AnimatedCartons({required this.progress, required this.color});

  @override
  Widget build(BuildContext context) {
    final visible = (progress * 4).floor().clamp(0, 4);
    return Row(
      children: [
        for (var i = 0; i < visible; i++)
          Padding(
            padding: const EdgeInsets.only(right: 3),
            child: Icon(Icons.inventory_2_rounded, size: 18, color: color),
          ),
      ],
    );
  }
}

class _MetricRow extends StatelessWidget {
  final String label;
  final int value;
  final double progress;
  final IconData icon;

  const _MetricRow({
    required this.label,
    required this.value,
    required this.progress,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shown = (value * progress).round();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 19, color: scheme.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700))),
          Text('$shown cartons', style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}
