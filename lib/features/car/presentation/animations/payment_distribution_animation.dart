import 'package:flutter/material.dart';

class PaymentAllocationVisual {
  final String invoiceNumber;
  final double amount;
  final bool becomesPaid;

  const PaymentAllocationVisual({
    required this.invoiceNumber,
    required this.amount,
    required this.becomesPaid,
  });
}

/// One-shot visual confirmation shown only after payment persistence succeeds.
class PaymentDistributionAnimation extends StatefulWidget {
  final double paymentAmount;
  final List<PaymentAllocationVisual> allocations;
  final VoidCallback? onComplete;

  const PaymentDistributionAnimation({
    super.key,
    required this.paymentAmount,
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
    duration: const Duration(milliseconds: 2200),
  )
    ..addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onComplete?.call();
    });

  late final Animation<double> _source = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0, .25, curve: Curves.easeOutBack),
  );
  late final Animation<double> _flow = CurvedAnimation(
    parent: _controller,
    curve: const Interval(.16, .72, curve: Curves.easeInOutCubic),
  );
  late final Animation<double> _result = CurvedAnimation(
    parent: _controller,
    curve: const Interval(.68, 1, curve: Curves.easeOutBack),
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
    final visible = (widget.allocations.length * _flow.value)
        .ceil()
        .clamp(0, widget.allocations.length) as int;

    return Material(
      color: scheme.surface,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => Column(
              children: [
                const Spacer(),
                Transform.scale(
                  scale: .88 + .12 * _source.value,
                  child: Container(
                    width: 112,
                    height: 112,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: scheme.primaryContainer,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.payments_rounded, size: 38, color: scheme.primary),
                        const SizedBox(height: 4),
                        Text(
                          '${widget.paymentAmount.toStringAsFixed(2)} EGP',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 26),
                const Text(
                  'Applying payment',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                Text(
                  'Distributing the confirmed amount across outstanding invoices',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 28),
                for (var i = 0; i < visible; i++)
                  _AllocationRow(
                    allocation: widget.allocations[i],
                    progress: ((_flow.value * widget.allocations.length) - i)
                        .clamp(0.0, 1.0),
                  ),
                const SizedBox(height: 10),
                Opacity(
                  opacity: _result.value,
                  child: Transform.scale(
                    scale: .9 + .1 * _result.value,
                    child: Container(
                      padding: const EdgeInsets.all(18),
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
                          const Expanded(
                            child: Text(
                              'Payment applied successfully',
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AllocationRow extends StatelessWidget {
  final PaymentAllocationVisual allocation;
  final double progress;

  const _AllocationRow({required this.allocation, required this.progress});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(Icons.receipt_long_rounded, size: 19, color: scheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              allocation.invoiceNumber,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Opacity(
            opacity: progress,
            child: Text(
              '${allocation.amount.toStringAsFixed(2)} EGP',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          if (allocation.becomesPaid)
            Opacity(
              opacity: progress,
              child: const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(Icons.check_circle_rounded, size: 19),
              ),
            ),
        ],
      ),
    );
  }
}
