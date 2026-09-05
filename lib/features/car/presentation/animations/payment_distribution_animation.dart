import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/repositories/app_services.dart';
import '../../../../core/presentation/payment_time_picker.dart';
import '../../domain/entities/car_payment_allocation.dart';

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
/// Payment persistence completes before this route is pushed. This screen can
/// additionally collect optional payment dates and updates metadata only;
/// payment amounts and trip balances are never changed here.
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

  final Map<int, DateTime> _allocationDates = {};
  List<CarPaymentAllocation> _storedAllocations = const [];

  @override
  void initState() {
    super.initState();
    _preparePaymentDates();
  }

  Future<void> _preparePaymentDates() async {
    try {
      final repository = AppServices.instance.carPaymentRepository;
      final transactions = await repository.getTransactions();
      if (transactions.isEmpty) {
        if (mounted) _controller.forward();
        return;
      }

      final transaction = transactions.first;
      final allocations =
          await repository.getAllocationsForTransaction(transaction.id);
      if (allocations.length != widget.allocations.length || allocations.isEmpty) {
        if (mounted) _controller.forward();
        return;
      }

      _storedAllocations = allocations;
      for (final allocation in allocations) {
        final date = allocation.paymentAt ?? transaction.createdAt;
        _allocationDates[allocation.id] = date.toLocal();
      }

      if (!mounted) return;

      final specify = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Specify payment time?'),
          content: const Text(
            'Would you like to specify the payment date and time for each invoice, or continue with the current time?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Continue'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Specify details'),
            ),
          ],
        ),
      );

      if (!mounted) return;
      if (specify == true) {
        final selected = await _showAllocationDateDetails();
        if (selected != null && mounted) {
          try {
            await repository.updateAllocationPaymentDates(
              transactionId: transaction.id,
              paymentDates: selected,
            );
            _allocationDates
              ..clear()
              ..addAll({
                for (final entry in selected.entries) entry.key: entry.value.toLocal(),
              });
          } catch (error) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Payment dates could not be saved: $error')),
            );
          }
        }
      }
    } catch (_) {
      // Date details are optional; the already-persisted payment remains valid.
    }

    if (mounted) _controller.forward();
  }

  Future<Map<int, DateTime>?> _showAllocationDateDetails() async {
    final workingDates = Map<int, DateTime>.from(_allocationDates);

    return showDialog<Map<int, DateTime>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Payment date details'),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        'Set the payment date and time for each invoice allocation.',
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (var index = 0; index < _storedAllocations.length; index++)
                      _allocationDateRow(
                        context,
                        setDialogState,
                        index,
                        workingDates,
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(workingDates),
                child: const Text('Save dates'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _allocationDateRow(
    BuildContext context,
    void Function(VoidCallback) setDialogState,
    int index,
    Map<int, DateTime> workingDates,
  ) {
    final allocation = _storedAllocations[index];
    final date = workingDates[allocation.id] ?? DateTime.now();
    final visual = index < widget.allocations.length
        ? widget.allocations[index]
        : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      visual?.invoiceNumber ?? 'Invoice ${allocation.tripId}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${_allocationAmount(allocation).toStringAsFixed(2)} EGP',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () async {
                  final initial = date;
                  final pickedDate = await showDatePicker(
                    context: context,
                    initialDate: initial,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(DateTime.now().year + 5),
                    helpText: 'Select payment date',
                  );
                  if (pickedDate == null || !context.mounted) return;

                  final pickedTime = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.fromDateTime(initial),
                    helpText: 'Select payment time',
                  );
                  if (pickedTime == null || !context.mounted) return;

                  final combined = DateTime(
                    pickedDate.year,
                    pickedDate.month,
                    pickedDate.day,
                    pickedTime.hour,
                    pickedTime.minute,
                  ).toLocal();
                  setDialogState(() => workingDates[allocation.id] = combined);
                },
                icon: const Icon(Icons.schedule_rounded, size: 18),
                label: Text(formatPaymentDateTime(date)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _allocationAmount(CarPaymentAllocation allocation) =>
      allocation.totalAmount.toUnits();

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
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      '${widget.paymentAmount.toStringAsFixed(2)} EGP',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
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
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: scheme.onSurfaceVariant,
                                        ),
                                      ),
                                      if (_allocationDates[index] != null) ...[
                                        const SizedBox(height: 3),
                                        Text(
                                          'Payment: ${formatPaymentDateTime(_allocationDates[index]!)}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            color: scheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                SizedBox(
                                  width: 108,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        status,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.end,
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
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.end,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: scheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
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
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
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
