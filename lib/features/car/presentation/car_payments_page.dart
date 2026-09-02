import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/repositories/app_services.dart';
import '../../../core/ui/app_card.dart';
import '../../../core/ui/empty_state.dart';
import '../application/usecases/allocate_car_payment.dart';
import '../domain/entities/car_payment_transaction.dart';
import '../domain/entities/car_trip.dart';
import '../domain/entities/money.dart';
import '../domain/services/car_calculator.dart';
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

  late final StreamSubscription<CarTrip> _tripChanges;

  List<CarTrip> _allOutstandingTrips = const [];
  List<_PaymentScope> _scopes = const [];
  String? _selectedScopeKey;
  bool _loading = true;
  bool _processing = false;
  String? _error;

  _PaymentScope? get _selectedScope {
    final key = _selectedScopeKey;
    if (key == null) return null;
    for (final scope in _scopes) {
      if (scope.key == key) return scope;
    }
    return null;
  }

  List<CarTrip> get _outstandingTrips {
    final scope = _selectedScope;
    if (scope == null) return const [];
    return _allOutstandingTrips
        .where(
          (trip) =>
              trip.salesCarId == scope.salesCarId &&
              trip.warehouseId == scope.warehouseId,
        )
        .toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    _tripChanges = AppServices.instance.carTripEvents.stream.listen(_onTripChanged);
    _load();
  }

  @override
  void dispose() {
    _tripChanges.cancel();
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
      final outstanding = trips
          .where(
            (trip) =>
                trip.isClosed &&
                trip.payment.totalPaid.minorUnits < _totalFor(trip),
          )
          .toList(growable: false);
      _applyTrips(outstanding, preferFocus: true);
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$error';
      });
    }
  }

  void _applyTrips(List<CarTrip> trips, {bool preferFocus = false}) {
    final groups = <String, _PaymentScope>{};
    for (final trip in trips) {
      final scope = _PaymentScope(
        salesCarId: trip.salesCarId,
        salesCarName: trip.salesCarName,
        warehouseId: trip.warehouseId,
        warehouseName: trip.warehouseName,
      );
      groups[scope.key] = scope;
    }

    String? selectedKey = _selectedScopeKey;
    if (preferFocus && widget.focusTripId != null) {
      final focused = trips.where((trip) => trip.id == widget.focusTripId).firstOrNull;
      if (focused != null) selectedKey = '${focused.salesCarId}:${focused.warehouseId}';
    }
    selectedKey ??= groups.length == 1 ? groups.keys.first : null;
    if (selectedKey != null && !groups.containsKey(selectedKey)) selectedKey = null;

    _allOutstandingTrips = trips;
    _scopes = groups.values.toList(growable: false);
    _selectedScopeKey = selectedKey;
  }

  void _onTripChanged(CarTrip trip) {
    if (!mounted || trip.id <= 0) return;
    final next = [..._allOutstandingTrips]..removeWhere((item) => item.id == trip.id);
    if (trip.isClosed && trip.payment.totalPaid.minorUnits < _totalFor(trip)) {
      next.add(trip);
    }
    next.sort((a, b) => a.openedAt.compareTo(b.openedAt));
    final previousKey = _selectedScopeKey;
    _applyTrips(next);
    if (previousKey != null && _scopes.any((scope) => scope.key == previousKey)) {
      _selectedScopeKey = previousKey;
    }
    setState(() {});
  }

  int _totalFor(CarTrip trip) => const CarTripValue().value(trip);

  Future<void> _pay() async {
    if (_processing) return;
    final scope = _selectedScope;
    if (scope == null) {
      _showError('Select a Car + Warehouse group first.');
      return;
    }
    final cash = _value(_cashController);
    final transfer = _value(_transferController);
    if (cash < 0 || transfer < 0 || cash + transfer <= 0) {
      _showError('Enter a payment greater than zero.');
      return;
    }
    if (_outstandingTrips.isEmpty) {
      _showError('There are no outstanding invoices for the selected group.');
      return;
    }

    setState(() => _processing = true);
    try {
      final transaction = CarPaymentTransaction(
        cashAmount: _money(cash),
        transferAmount: _money(transfer),
        reference: _referenceController.text.trim().isEmpty
            ? null
            : _referenceController.text.trim(),
        createdAt: DateTime.now().toUtc(),
      );
      final plan = await AllocateCarPayment(repository: _paymentRepository)(
        transaction: transaction,
        trips: _allOutstandingTrips,
        salesCarId: scope.salesCarId,
        warehouseId: scope.warehouseId,
      );

      for (final updatedTrip in plan.updatedTrips) {
        AppServices.instance.carTripEvents.publish(updatedTrip);
      }

      final visuals = [
        for (final allocation in plan.allocations)
          PaymentAllocationVisual(
            invoiceNumber: _tripLabel(tripById(_allOutstandingTrips, allocation.tripId)),
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
    } catch (error) {
      if (mounted) _showError('$error');
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  CarTrip tripById(List<CarTrip> trips, int id) =>
      trips.firstWhere((trip) => trip.id == id);

  String _tripLabel(CarTrip trip) {
    final date = trip.openedAt.toLocal();
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} · ${trip.salesCarName}';
  }

  CarMoney _money(double amount) => CarMoney.fromUnits(amount);

  void _showError(String message) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: EmptyState(
          icon: Icons.error_outline_rounded,
          title: 'Unable to load payments',
          message: _error!,
          actionLabel: 'Retry',
          onAction: _load,
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: [
          const Text('Car payments', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(
            'Each payment is restricted to one Car + Warehouse group and may be split only across that group’s finalized outstanding trips.',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 18),
          _paymentForm(),
          const SizedBox(height: 18),
          const Text('Outstanding invoices', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          if (_selectedScope == null)
            const EmptyState(
              icon: Icons.account_tree_outlined,
              title: 'Select a payment group',
              message: 'Choose the exact Car and Warehouse before applying a payment.',
            )
          else if (_outstandingTrips.isEmpty)
            const EmptyState(
              icon: Icons.check_circle_outline_rounded,
              title: 'Everything is paid',
              message: 'There are no finalized outstanding invoices for this Car + Warehouse group.',
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Record payment', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _selectedScopeKey,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Car + Warehouse',
              prefixIcon: Icon(Icons.route_rounded),
              border: OutlineInputBorder(),
            ),
            items: [
              for (final scope in _scopes)
                DropdownMenuItem<String>(
                  value: scope.key,
                  child: Text(scope.label, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: _processing
                ? null
                : (value) => setState(() => _selectedScopeKey = value),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _cashController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Cash', suffixText: 'EGP', border: OutlineInputBorder()),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _transferController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Transfer', suffixText: 'EGP', border: OutlineInputBorder()),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _referenceController,
            decoration: const InputDecoration(labelText: 'Reference (optional)', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: Text('Total payment', style: TextStyle(color: scheme.onSurfaceVariant))),
              Text('EGP ${amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
            ],
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _processing || _selectedScope == null ? null : _pay,
            icon: _processing
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.payments_rounded),
            label: Text(_processing ? 'Applying...' : 'Apply payment'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          ),
        ],
      ),
    );
  }

  Widget _tripRow(CarTrip trip) {
    final scheme = Theme.of(context).colorScheme;
    final remaining = _totalFor(trip) - trip.payment.totalPaid.minorUnits;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(15)),
              child: Icon(Icons.receipt_long_rounded, color: scheme.primary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_tripLabel(trip), style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Text(trip.warehouseName, style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'EGP ${(remaining / 100).toStringAsFixed(2)}',
              style: TextStyle(fontWeight: FontWeight.w900, color: remaining > 0 ? scheme.error : scheme.primary),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentScope {
  final int salesCarId;
  final String salesCarName;
  final int warehouseId;
  final String warehouseName;

  const _PaymentScope({
    required this.salesCarId,
    required this.salesCarName,
    required this.warehouseId,
    required this.warehouseName,
  });

  String get key => '$salesCarId:$warehouseId';
  String get label => '$salesCarName · $warehouseName';
}

class CarTripValue {
  const CarTripValue();
  int value(CarTrip trip) =>
      const CarCalculator().summary(trip).finalTotalSoldValue.minorUnits;
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
