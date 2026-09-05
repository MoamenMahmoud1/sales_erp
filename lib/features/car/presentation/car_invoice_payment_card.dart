import 'package:flutter/material.dart';

import '../../../core/presentation/payment_time_picker.dart';
import '../../../core/repositories/app_services.dart';
import '../../../core/ui/app_card.dart';
import '../application/usecases/allocate_car_payment.dart';
import '../domain/entities/car_payment_transaction.dart';
import '../domain/entities/car_trip.dart';
import '../domain/entities/money.dart';

class CarInvoicePaymentCard extends StatefulWidget {
  final CarTrip trip;
  final CarMoney remaining;
  final ValueChanged<CarTrip>? onPaymentCompleted;

  const CarInvoicePaymentCard({
    super.key,
    required this.trip,
    required this.remaining,
    this.onPaymentCompleted,
  });

  @override
  State<CarInvoicePaymentCard> createState() => _CarInvoicePaymentCardState();
}

class _CarInvoicePaymentCardState extends State<CarInvoicePaymentCard> {
  final _repository = AppServices.instance.carPaymentRepository;
  final _cashController = TextEditingController(text: '0');
  final _transferController = TextEditingController(text: '0');
  final _referenceController = TextEditingController();
  bool _processing = false;

  @override
  void dispose() {
    _cashController.dispose();
    _transferController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  double _value(TextEditingController controller) {
    final text = controller.text.trim().replaceAll(',', '');
    if (text.isEmpty) return 0;
    final parsed = double.tryParse(text);
    return parsed != null && parsed.isFinite ? parsed : 0;
  }

  double get _paymentNow => _value(_cashController) + _value(_transferController);

  double get _remainingAfter =>
      (widget.remaining.units - _paymentNow).clamp(0, widget.remaining.units).toDouble();

  void _payRemainingInCash() {
    _cashController.text = widget.remaining.units.toStringAsFixed(2);
    _transferController.text = '0';
    setState(() {});
  }

  Future<void> _pay() async {
    if (_processing) return;

    if (!widget.trip.isClosed) {
      _showError('Finalize the Car invoice before recording a payment.');
      return;
    }

    final amount = _paymentNow;
    if (amount <= 0) {
      _showError('Enter a payment greater than zero.');
      return;
    }

    if (amount > widget.remaining.units) {
      _showError('Payment cannot exceed the outstanding invoice balance.');
      return;
    }

    final paymentAt = await resolvePaymentTime(context);
    if (!mounted || paymentAt == null) return;

    setState(() => _processing = true);
    try {
      final transaction = CarPaymentTransaction(
        cashAmount: CarMoney.fromUnits(_value(_cashController)),
        transferAmount: CarMoney.fromUnits(_value(_transferController)),
        reference: _referenceController.text.trim().isEmpty
            ? null
            : _referenceController.text.trim(),
        createdAt: paymentAt,
      );

      final plan = await AllocateCarPayment(repository: _repository)(
        transaction: transaction,
        trips: [widget.trip],
        salesCarId: widget.trip.salesCarId,
        warehouseId: widget.trip.warehouseId,
      );

      final updatedTrip = plan.updatedTrips.firstWhere(
        (trip) => trip.id == widget.trip.id,
      );
      AppServices.instance.carTripEvents.publish(updatedTrip);
      widget.onPaymentCompleted?.call(updatedTrip);

      if (!mounted) return;
      _cashController.text = '0';
      _transferController.text = '0';
      _referenceController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Payment of EGP ${amount.toStringAsFixed(2)} recorded successfully.',
          ),
        ),
      );
    } catch (error) {
      if (mounted) _showError('$error');
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fullyPaid = widget.remaining == CarMoney.zero;
    final canPay = !_processing && !fullyPaid && widget.trip.isClosed && _paymentNow > 0;

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: fullyPaid ? scheme.primaryContainer : scheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  fullyPaid ? Icons.check_rounded : Icons.payments_rounded,
                  color: fullyPaid ? scheme.primary : scheme.onSecondaryContainer,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pay this invoice',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Record a full or partial payment directly from the invoice details.',
                      style: TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: fullyPaid ? scheme.primaryContainer : scheme.errorContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(
                  fullyPaid ? Icons.check_circle_rounded : Icons.account_balance_wallet_outlined,
                  color: fullyPaid ? scheme.primary : scheme.onErrorContainer,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    fullyPaid
                        ? 'This invoice is fully paid.'
                        : 'Outstanding: EGP ${widget.remaining.units.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: fullyPaid ? scheme.onPrimaryContainer : scheme.onErrorContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (!fullyPaid) ...[
            const SizedBox(height: 12),
            if (!widget.trip.isClosed)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  'This invoice is still a draft. Finalize it before recording a payment.',
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 520) {
                  return Column(
                    children: [
                      _amountField(_cashController, 'Cash'),
                      const SizedBox(height: 10),
                      _amountField(_transferController, 'Transfer'),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: _amountField(_cashController, 'Cash')),
                    const SizedBox(width: 10),
                    Expanded(child: _amountField(_transferController, 'Transfer')),
                  ],
                );
              },
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _referenceController,
              enabled: !_processing,
              decoration: const InputDecoration(
                labelText: 'Reference (optional)',
                prefixIcon: Icon(Icons.tag_rounded),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Remaining after payment: EGP ${_remainingAfter.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _processing ? null : _payRemainingInCash,
                  icon: const Icon(Icons.done_all_rounded, size: 18),
                  label: const Text('Pay remaining'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: canPay ? _pay : null,
                icon: _processing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.payments_rounded),
                label: Text(_processing ? 'Recording payment...' : 'Record payment'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _amountField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      enabled: !_processing && widget.trip.isClosed,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(
          label == 'Cash' ? Icons.payments_outlined : Icons.account_balance_outlined,
        ),
        suffixText: 'EGP',
        border: const OutlineInputBorder(),
      ),
    );
  }
}
