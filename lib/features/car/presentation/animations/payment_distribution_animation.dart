import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/presentation/payment_time_picker.dart';
import '../../../../core/repositories/app_services.dart';
import '../../domain/entities/car_payment_allocation.dart';
import '../../domain/repositories/car_payment_repository.dart';

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

/// Shows the exact Car-payment allocation result and optionally records
/// a separate payment date/time for every invoice allocation.
class PaymentDistributionAnimation extends StatefulWidget {
  final double paymentAmount;
  final String? scopeLabel;
  final List<PaymentAllocationVisual> allocations;
  final int? transactionId;
  final VoidCallback? onComplete;

  const PaymentDistributionAnimation({
    super.key,
    required this.paymentAmount,
    this.scopeLabel,
    required this.allocations,
    this.transactionId,
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
  )..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete?.call();
      }
    });

  final Map<int, DateTime> _allocationDates = {};
  List<CarPaymentAllocation> _storedAllocations = const [];
  int? _activeTransactionId;

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

      final transaction = widget.transactionId == null
          ? transactions.reduce((a, b) => a.id > b.id ? a : b)
          : transactions.firstWhere(
              (item) => item.id == widget.transactionId,
              orElse: () => transactions.reduce((a, b) => a.id > b.id ? a : b),
            );
      _activeTransactionId = transaction.id;

      final allocations = await repository.getAllocationsForTransaction(
        transaction.id,
      );
      if (allocations.length != widget.allocations.length || allocations.isEmpty) {
        if (mounted) _controller.forward();
        return;
      }

      _storedAllocations = allocations;
      for (final allocation in allocations) {
        _allocationDates[allocation.id] =
            (allocation.paymentAt ?? transaction.createdAt).toLocal();
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
          await _saveAllocationDates(repository, selected);
        }
      } else {
        final now = DateTime.now().toUtc();
        final selected = {
          for (final allocation in _storedAllocations) allocation.id: now,
        };
        await _saveAllocationDates(repository, selected);
      }
    } catch (_) {
      // Date details are optional; the payment itself has already been saved.
    }

    if (mounted) _controller.forward();
  }

  Future<void> _saveAllocationDates(
    CarPaymentRepository repository,
    Map<int, DateTime> dates,
  ) async {
    final transactionId = _activeTransactionId;
    if (transactionId == null) return;

    try {
      await repository.updateAllocationPaymentDates(
        transactionId: transactionId,
        paymentDates: dates,
      );
      _allocationDates
        ..clear()
        ..addAll({
          for (final entry in dates.entries) entry.key: entry.value.toLocal(),
        });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment dates could not be saved: $error')),
        );
      }
    }
  }

  Future<Map<int, DateTime>?> _showAllocationDateDetails() async {
    final workingDates = Map<int, DateTime>.from(_allocationDates);

    return showDialog<Map<int, DateTime>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            title: const Text('Payment date details'),
            content: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 540,
                maxHeight: MediaQuery.sizeOf(dialogContext).height * .62,
              ),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Text(
                      'Set the payment date and time for every invoice allocation.',
                      style: TextStyle(
                        color: Theme.of(dialogContext)
                            .colorScheme
                            .onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (var index = 0; index < _storedAllocations.length; index++)
                      _allocationDateRow(
                        dialogContext,
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
              FilledButton.icon(
                onPressed: () => Navigator.of(dialogContext).pop(workingDates),
                icon: const Icon(Icons.save_rounded),
                label: const Text('Save dates'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _allocationDateRow(
    BuildContext dialogContext,
    void Function(VoidCallback) setDialogState,
    int index,
    Map<int, DateTime> workingDates,
  ) {
    final allocation = _storedAllocations[index];
    final date = workingDates[allocation.id] ?? DateTime.now();
    final visual = index < widget.allocations.length
        ? widget.allocations[index]
        : null;
    final scheme = Theme.of(dialogContext).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                Icons.receipt_long_rounded,
                color: scheme.primary,
                size: 19,
              ),
            ),
            const SizedBox(width: 9),
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
                    style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: OutlinedButton.icon(
                onPressed: () async {
                  final selected = await pickPaymentDateTime(
                    dialogContext,
                    initial: date,
                  );
                  if (selected == null || !dialogContext.mounted) return;
                  setDialogState(() => workingDates[allocation.id] = selected);
                },
                icon: const Icon(Icons.schedule_rounded, size: 17),
                label: Text(
                  formatPaymentDateTime(date),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _allocationAmount(CarPaymentAllocation allocation) =>
      allocation.totalAmount.units;

  double _rowProgress(int index) {
    final count = widget.allocations.length;
    if (count == 0) return 1;
    const start = 0.08;
    const available = 0.78;
    final span = available / count;
    final rowStart = start + index * span;
    final rowEnd = math.min(0.98, rowStart + math.max(0.16, span * 1.45));
    final raw = (_controller.value - rowStart) / (rowEnd - rowStart);
    return Curves.easeOutCubic.transform(raw.clamp(0.0, 1.0));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
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
                          'Payment details',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 3),
                        if (widget.scopeLabel != null)
                          Text(
                            widget.scopeLabel!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: scheme.onSurfaceVariant),
                          ),
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
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
                    itemCount: widget.allocations.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 9),
                    itemBuilder: (context, index) {
                      final allocation = widget.allocations[index];
                      final progress = _rowProgress(index);
                      final stored = index < _storedAllocations.length
                          ? _storedAllocations[index]
                          : null;
                      final date = stored == null
                          ? null
                          : _allocationDates[stored.id];
                      final paid = allocation.remainingAfter <= 0;

                      return Opacity(
                        opacity: progress,
                        child: Transform.translate(
                          offset: Offset(18 * (1 - progress), 0),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(17),
                              border: Border.all(color: scheme.outlineVariant),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      paid
                                          ? Icons.check_circle_rounded
                                          : Icons.receipt_long_rounded,
                                      color: paid
                                          ? scheme.primary
                                          : scheme.onSurfaceVariant,
                                      size: 21,
                                    ),
                                    const SizedBox(width: 9),
                                    Expanded(
                                      child: Text(
                                        allocation.invoiceNumber,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontWeight: FontWeight.w900),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: paid
                                            ? scheme.primaryContainer
                                            : scheme.tertiaryContainer,
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        paid ? 'Paid' : 'Partial',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w900,
                                          color: paid
                                              ? scheme.onPrimaryContainer
                                              : scheme.onTertiaryContainer,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 11),
                                Wrap(
                                  spacing: 7,
                                  runSpacing: 7,
                                  children: [
                                    _metric(
                                      context,
                                      'Applied',
                                      '${allocation.amount.toStringAsFixed(2)} EGP',
                                    ),
                                    _metric(
                                      context,
                                      'Remaining',
                                      allocation.remainingAfter <= 0
                                          ? '0.00 EGP'
                                          : '${allocation.remainingAfter.toStringAsFixed(2)} EGP',
                                    ),
                                  ],
                                ),
                                if (date != null) ...[
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.event_available_rounded,
                                        size: 16,
                                        color: scheme.primary,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          'Payment date: ${formatPaymentDateTime(date)}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: scheme.onSurfaceVariant,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
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
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 5, 20, 18),
              child: FilledButton.icon(
                onPressed: _controller.isCompleted
                    ? () => Navigator.of(context).pop()
                    : null,
                icon: const Icon(Icons.done_rounded),
                label: const Text('Done'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metric(BuildContext context, String label, String value) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(11),
      ),
      child: RichText(
        text: TextSpan(
          style: TextStyle(fontSize: 11, color: scheme.onSurface),
          children: [
            TextSpan(
              text: '$label  ',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }
}
