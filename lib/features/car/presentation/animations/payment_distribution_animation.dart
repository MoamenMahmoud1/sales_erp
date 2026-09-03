import 'dart:math' as math;

import 'package:flutter/material.dart';

class PaymentAllocationVisual {
  final String invoiceNumber;
  final double amount;
  final double remainingAfter;
  final bool becomesPaid;

  const PaymentAllocationVisual({
    required this.invoiceNumber,
    required this.amount,
    this.remainingAfter = 0,
    required this.becomesPaid,
  });
}

/// Fast, bounded visual confirmation of the exact invoice allocations.
///
/// It is intentionally presentation-only: persistence must already have
/// succeeded before this route is pushed.
class PaymentDistributionAnimation extends StatefulWidget {
  final double paymentAmount;
  final String? scopeLabel;
  final List<PaymentAllocationVisual> allocations;
  final VoidCallback? onComplete;

  const PaymentDistributionAnimation({
    super.key,
    required this.paymentAmount,
    this.scopeLabel,
    required this.allocations,
    this.onComplete,
  });

  @override
  State<PaymentDistributionAnimation> createState() =>
      _PaymentDistributionAnimationState();
}

class _PaymentDistributionAnimationState
    extends State<PaymentDistributionAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Duration(
      milliseconds: math.min(1800, 850 + widget.allocations.length * 170),
    ),
  )
    ..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete?.call();
      }
    });

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

  double _rowProgress(int index) {
    final count = widget.allocations.length;
    if (count == 0) return 1;

    const start = 0.08;
    const available = 0.78;
    final span = available / count;
    final rowStart = start + (index * span);
    final rowEnd = math.min(0.98, rowStart + math.max(0.16, span * 1.45));
    final raw = ((_controller.value - rowStart) / (rowEnd - rowStart));
    return Curves.easeOutCubic.transform(raw.clamp(0.0, 1.0));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.surface,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(Icons.payments_rounded, color: scheme.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Payment applied',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                        ),
                        if (widget.scopeLabel != null) ...[
                          const SizedBox(height: 3),
                          Text(
                            widget.scopeLabel!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Text(
                    '${widget.paymentAmount.toStringAsFixed(2)} EGP',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
            Expanded(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  if (widget.allocations.isEmpty) {
                    return const Center(child: Text('No invoice allocations.'));
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
                    itemCount: widget.allocations.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final allocation = widget.allocations[index];
                      final progress = _rowProgress(index);
                      final status = allocation.becomesPaid ? 'Paid' : 'Partial';
                      final isActive = progress > 0 && progress < 1;

                      return Opacity(
                        opacity: progress,
                        child: Transform.translate(
                          offset: Offset(24 * (1 - progress), 0),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? scheme.primaryContainer.withValues(alpha: .45)
                                  : scheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: isActive
                                    ? scheme.primary.withValues(alpha: .35)
                                    : scheme.outlineVariant,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: scheme.surface,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    allocation.becomesPaid
                                        ? Icons.check_circle_rounded
                                        : Icons.receipt_long_rounded,
                                    size: 20,
                                    color: allocation.becomesPaid
                                        ? scheme.primary
                                        : scheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(width: 11),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        allocation.invoiceNumber,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontWeight: FontWeight.w800),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        '${allocation.amount.toStringAsFixed(2)} EGP applied',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: scheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      status,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w900,
                                        color: allocation.becomesPaid
                                            ? scheme.primary
                                            : scheme.tertiary,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      allocation.remainingAfter <= 0
                                          ? '0.00 remaining'
                                          : '${allocation.remainingAfter.toStringAsFixed(2)} remaining',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: scheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final progress = Curves.easeOutCubic.transform(
                  ((_controller.value - .78) / .22).clamp(0.0, 1.0),
                );
                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
                  child: Opacity(
                    opacity: progress,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 19,
                            backgroundColor: scheme.primary,
                            foregroundColor: scheme.onPrimary,
                            child: const Icon(Icons.check_rounded, size: 21),
                          ),
                          const SizedBox(width: 11),
                          const Expanded(
                            child: Text(
                              'Payment recorded successfully',
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
