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
  )..addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onComplete?.call();
    });

  late final Animation<double> _truck = Tween<double>(begin: -1.2, end: .18)
      .animate(CurvedAnimation(
    parent: _controller,
    curve: const Interval(0, .38, curve: Curves.easeOutCubic),
  ));

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
    curve: const Interval(.80, 1, curve: Curves.easeOutCubic),
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
          padding: const EdgeInsets.all(20),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final summary = widget.summary;
              return SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 10),
                    const Text(
                      'Finalizing Car trip',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Processing the load, returns, and completed sale',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 150,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final rightLimit = constraints.maxWidth - 92;
                          final left = ((rightLimit) * _truck.value)
                              .clamp(-96.0, rightLimit);
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
                                right: 18,
                                bottom: 26,
                                child: Transform.scale(
                                  scale: .92 + (_success.value * .08),
                                  child: Container(
                                    width: 92,
                                    height: 94,
                                    decoration: BoxDecoration(
                                      color: scheme.primaryContainer,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: scheme.primary.withValues(alpha: .35),
                                      ),
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.inventory_2_rounded,
                                          color: scheme.primary,
                                          size: 32,
                                        ),
                                        const SizedBox(height: 5),
                                        const Text(
                                          'WAREHOUSE',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
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
                                      Icon(
                                        Icons.local_shipping_rounded,
                                        size: 70,
                                        color: scheme.primary,
                                      ),
                                      const SizedBox(width: 3),
                                      if (_box.value > .2)
                                        _AnimatedCartons(
                                          progress: _box.value,
                                          color: scheme.secondary,
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 18),
                    _MetricRow(
                      label: 'Loaded',
                      value: summary.totalLoadedCartons,
                      progress: _numbers.value,
                      icon: Icons.outbox_rounded,
                    ),
                    _MetricRow(
                      label: 'Returned',
                      value: summary.totalReturnedCartons,
                      progress: Curves.easeOut.transform(
                        (_numbers.value - .18).clamp(0, 1),
                      ),
                      icon: Icons.assignment_return_rounded,
                    ),
                    _MetricRow(
                      label: 'Sold',
                      value: summary.totalSoldCartons,
                      progress: Curves.easeOut.transform(
                        (_numbers.value - .32).clamp(0, 1),
                      ),
                      icon: Icons.point_of_sale_rounded,
                    ),
                    const SizedBox(height: 12),
                    Opacity(
                      opacity: _success.value,
                      child: Transform.scale(
                        scale: .94 + .06 * _success.value,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer,
                            borderRadius: BorderRadius.circular(22),
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
                                    const Text(
                                      'Car trip confirmed',
                                      style: TextStyle(fontWeight: FontWeight.w900),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '${summary.finalTotalSoldValue.units.toStringAsFixed(2)} EGP actual sold value',
                                      style: TextStyle(
                                        color: scheme.onSurfaceVariant,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
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
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 19, color: scheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Text(
            '$shown cartons',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}
