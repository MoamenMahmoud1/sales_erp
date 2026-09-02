import 'package:flutter/material.dart';

import '../../../core/repositories/app_services.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/app_card.dart';
import '../../../core/ui/empty_state.dart';
import '../application/usecases/allocate_car_payment.dart';
import '../domain/entities/car_payment_transaction.dart';
import '../domain/entities/car_trip.dart';
import '../domain/services/car_payment_allocator.dart';
import '../presentation/animations/payment_distribution_animation.dart';

class CarPaymentsPage extends StatefulWidget {
  final int? focusTripId;

  const CarPaymentsPage({super.key, this.focusTripId});

  @override
  State<CarPaymentsPage> createState() => _CarPaymentsPageState();
}

class _CarPaymentsPageState extends State<CarPaymentsPage> {
  final _tripRepository = AppServices.instance.carTripRepository;
  final _paymentRepository = AppServices.instance.carPaymentRepository;

  final _cashController = TextEditingController(text: '0');
  final _transferController = TextEditingController(text: '0');
  final _referenceController = TextEditingController();

  List<CarTrip> _outstandingTrips = const [];
  bool _loading = true;
  bool _processing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _cashController.dispose();
    _transferController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  double _value(TextEditingController controller) =>
      double.tryParse(controller.text.trim().replaceAll(',', '')) ?? 0;

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final trips = await _tripRepository.getTrips();
      final filtered = trips
          .where((trip) => trip.isClosed && trip.payment.totalPaid.minorUnits < _totalFor(trip))
          .toList(growable: false);
      if (!mounted) return;
      setState(() {
        _outstandingTrips = filtered;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() { _loading = false; _error = '$error'; });
    }
  }

  int _totalFor(CarTrip trip) {
    // Read the materialized final value by using the trip model's domain
    // calculator through a compact helper rather than duplicating formulas.
    final summary = const CarTripValue().value(trip);
    return summary;
  }

  Future<void> _pay() async {
    if (_processing) return;
    final cash = _value(_cashController);
    final transfer = _value(_transferController);
    if (cash < 0 || transfer < 0 || cash + transfer <= 0) {
      _showError('Enter a payment greater than zero.');
      return;
    }

    setState(() => _processing = true);
    try {
      final transaction = CarPaymentTransaction(
        cashAmount: _money(cash),
        transferAmount: _money(transfer),
        reference: _referenceController.text.trim().isEmpty ? null : _referenceController.text.trim(),
        createdAt: DateTime.now().toUtc(),
      );
      final plan = await AllocateCarPayment(
        repository: _paymentRepository,
      )(
        transaction: transaction,
        trips: _outstandingTrips,
      );

      final numbers = <int, String>{
        for (final trip in _outstandingTrips) trip.id: trip.displayNumber,
      };
      final visuals = [
        for (final allocation in plan.allocations)
          PaymentAllocationVisual(
            invoiceNumber: numbers[allocation.tripId] ?? 'Car invoice',
            amount: allocation.totalAmount.units,
            becomesPaid: plan.updatedTrips
                .firstWhere((trip) => trip.id == allocation.tripId)
                .payment
                .totalPaid
                .minorUnits >=
                _totalFor(tripById(plan.updatedTrips, allocation.tripId)),
          ),
      ];

      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PaymentDistributionAnimation(
            paymentAmount: transaction.totalAmount.units,
            allocations: visuals,
          ),
        ),
      );
      _cashController.text = '0';
      _transferController.text = '0';
      _referenceController.clear();
      if (mounted) await _load();
    } catch (error) {
      if (mounted) _showError('$error');
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  CarTrip tripById(List<CarTrip> trips, int id) =>
      trips.firstWhere((trip) => trip.id == id);

  CarMoney _money(double amount) =>
      CarMoney.fromUnits(amount);

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(child: EmptyState(
        icon: Icons.error_outline_rounded,
        title: 'Unable to load payments',
        message: _error!,
        actionLabel: 'Retry',
        onAction: _load,
      ));
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: [
          const Text('Car payments', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(
            'One payment is allocated sequentially across finalized outstanding Car invoices.',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 18),
          _paymentForm(),
          const SizedBox(height: 18),
          const Text('Outstanding invoices', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          if (_outstandingTrips.isEmpty)
            const EmptyState(
              icon: Icons.check_circle_outline_rounded,
              title: 'Everything is paid',
              message: 'There are no finalized Car invoices waiting for payment.',
            )
          else
            for (final trip in _outstandingTrips) _tripRow(trip),
        ],
      ),
    );
  }

  Widget _paymentForm() {
    final scheme = Theme.of(context).colorScheme;
    final amount = _value(_cashController) + _value(_transferController);
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Record payment', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: TextField(
            controller: _cashController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Cash', suffixText: 'EGP', border: OutlineInputBorder()),
            onChanged: (_) => setState(() {}),
          )),
          const SizedBox(width: 10),
          Expanded(child: TextField(
            controller: _transferController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Transfer', suffixText: 'EGP', border: OutlineInputBorder()),
            onChanged: (_) => setState(() {}),
          )),
        ]),
        const SizedBox(height: 10),
        TextField(
          controller: _referenceController,
          decoration: const InputDecoration(labelText: 'Reference (optional)', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: Text('Total payment', style: TextStyle(color: scheme.onSurfaceVariant))),
          Text('EGP ${amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
        ]),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: _processing || _outstandingTrips.isEmpty ? null : _pay,
          icon: _processing
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.payments_rounded),
          label: Text(_processing ? 'Applying...' : 'Apply payment'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        ),
      ]),
    );
  }

  Widget _tripRow(CarTrip trip) {
    final scheme = Theme.of(context).colorScheme;
    final remaining = _totalFor(trip) - trip.payment.totalPaid.minorUnits;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(15)),
            child: Icon(Icons.receipt_long_rounded, color: scheme.primary),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(trip.displayNumber, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 3),
            Text('${trip.salesCarName} · ${trip.openedAt.toLocal().day}/${trip.openedAt.toLocal().month}/${trip.openedAt.toLocal().year}', style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
          ])),
          Text('EGP ${(remaining / 100).toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.w900, color: remaining > 0 ? scheme.error : scheme.primary)),
        ]),
      ),
    );
  }
}

class CarTripValue {
  const CarTripValue();

  int value(CarTrip trip) => const CarCalculator().summary(trip).finalTotalSoldValue.minorUnits;
}
