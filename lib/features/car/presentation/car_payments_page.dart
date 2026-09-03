import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/repositories/app_services.dart';
import '../../../core/ui/app_card.dart';
import '../../../core/ui/day_summary_section.dart';
import '../../../core/ui/empty_state.dart';
import '../application/usecases/allocate_car_payment.dart';
import '../domain/entities/car_payment_allocation.dart';
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
  final _calculator = const CarCalculator();

  final _cashController = TextEditingController(text: '0');
  final _transferController = TextEditingController(text: '0');
  final _referenceController = TextEditingController();

  late final StreamSubscription<CarTrip> _tripChanges;

  List<CarTrip> _allTrips = const [];
  List<CarTrip> _outstandingTrips = const [];
  List<_PaymentScope> _scopes = const [];
  List<_PaymentHistoryItem> _history = const [];
  String? _selectedScopeKey;
  int? _deletingTransactionId;
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

  List<CarTrip> get _selectedOutstandingTrips {
    final scope = _selectedScope;
    if (scope == null) return const [];
    return _outstandingTrips
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
    _tripChanges =
        AppServices.instance.carTripEvents.stream.listen(_onTripChanged);
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

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final results = await Future.wait<dynamic>([
        _tripRepository.getTrips(),
        _paymentRepository.getTransactions(),
        _paymentRepository.getAllocations(),
      ]);

      _allTrips = results[0] as List<CarTrip>;
      final transactions = results[1] as List<CarPaymentTransaction>;
      final allocations = results[2] as List<CarPaymentAllocation>;

      _setOutstanding(preserveSelection: false, preferFocus: true);
      _setHistory(transactions, allocations);

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

  void _setOutstanding({
    required bool preserveSelection,
    bool preferFocus = false,
  }) {
    final previousKey = preserveSelection ? _selectedScopeKey : null;
    final outstanding = _allTrips
        .where(
          (trip) =>
              trip.isClosed &&
              trip.payment.totalPaid.minorUnits < _totalFor(trip),
        )
        .toList()
      ..sort((a, b) => a.openedAt.compareTo(b.openedAt));

    final groups = <String, _PaymentScope>{};
    for (final trip in outstanding) {
      final scope = _PaymentScope(
        salesCarId: trip.salesCarId,
        salesCarName: trip.salesCarName,
        warehouseId: trip.warehouseId,
        warehouseName: trip.warehouseName,
      );
      groups[scope.key] = scope;
    }

    String? selection = previousKey;
    if (preferFocus && widget.focusTripId != null) {
      for (final trip in outstanding) {
        if (trip.id == widget.focusTripId) {
          selection = '${trip.salesCarId}:${trip.warehouseId}';
          break;
        }
      }
    }
    selection ??= groups.length == 1 ? groups.keys.first : null;
    if (selection != null && !groups.containsKey(selection)) selection = null;

    _outstandingTrips = List.unmodifiable(outstanding);
    _scopes = List.unmodifiable(groups.values);
    _selectedScopeKey = selection;
  }

  void _setHistory(
    List<CarPaymentTransaction> transactions,
    List<CarPaymentAllocation> allocations,
  ) {
    final byTransaction = <int, List<CarPaymentAllocation>>{};
    for (final allocation in allocations) {
      byTransaction.putIfAbsent(allocation.transactionId, () => []).add(allocation);
    }

    final history = <_PaymentHistoryItem>[];
    for (final transaction in transactions) {
      final transactionAllocations = byTransaction[transaction.id] ?? const [];
      if (transactionAllocations.isEmpty) continue;
      history.add(
        _PaymentHistoryItem(
          transaction: transaction,
          allocations: List.unmodifiable(transactionAllocations),
        ),
      );
    }
    history.sort(
      (a, b) => b.transaction.createdAt.compareTo(a.transaction.createdAt),
    );
    _history = List.unmodifiable(history);
  }

  void _onTripChanged(CarTrip trip) {
    if (!mounted || trip.id <= 0) return;
    final next = [..._allTrips]..removeWhere((item) => item.id == trip.id);
    next.add(trip);
    next.sort((a, b) => a.openedAt.compareTo(b.openedAt));
    _allTrips = List.unmodifiable(next);

    final previousKey = _selectedScopeKey;
    _setOutstanding(preserveSelection: true);
    if (previousKey != null && _scopes.any((scope) => scope.key == previousKey)) {
      _selectedScopeKey = previousKey;
    }
    setState(() {});
  }

  int _totalFor(CarTrip trip) =>
      _calculator.summary(trip).finalTotalSoldValue.minorUnits;

  double _value(TextEditingController controller) =>
      double.tryParse(controller.text.trim().replaceAll(',', '')) ?? 0;

  CarMoney _money(double amount) => CarMoney.fromUnits(amount);

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

    final trips = _selectedOutstandingTrips;
    if (trips.isEmpty) {
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

      final visuals = <PaymentAllocationVisual>[];
      for (final allocation in plan.allocations) {
        final updatedTrip = plan.updatedTrips.firstWhere(
          (trip) => trip.id == allocation.tripId,
        );
        final remaining =
            (_totalFor(updatedTrip) - updatedTrip.payment.totalPaid.minorUnits)
                .clamp(0, 1 << 62);
        visuals.add(
          PaymentAllocationVisual(
            invoiceNumber: _paymentInvoiceLabel(updatedTrip),
            amount: allocation.totalAmount.units,
            remainingAfter: remaining / 100,
            becomesPaid: remaining == 0,
          ),
        );
      }

      final savedTransaction = CarPaymentTransaction(
        id: plan.transactionId,
        cashAmount: transaction.cashAmount,
        transferAmount: transaction.transferAmount,
        reference: transaction.reference,
        createdAt: transaction.createdAt,
      );
      final historyItem = _PaymentHistoryItem(
        transaction: savedTransaction,
        allocations: plan.allocations,
      );

      if (!mounted) return;
      setState(() {
        _history = List.unmodifiable([historyItem, ..._history]);
      });

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PaymentDistributionAnimation(
            paymentAmount: transaction.totalAmount.units,
            scopeLabel: scope.label,
            allocations: visuals,
          ),
        ),
      );

      if (!mounted) return;
      _cashController.text = '0';
      _transferController.text = '0';
      _referenceController.clear();
    } catch (error) {
      if (mounted) _showError('$error');
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _deletePayment(_PaymentHistoryItem item) async {
    if (_deletingTransactionId != null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete payment?'),
        content: const Text(
          'This removes the payment record and reverses its allocations from the affected invoices. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete payment'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deletingTransactionId = item.transaction.id);
    try {
      final affectedTripIds = await _paymentRepository.deleteTransaction(
        item.transaction.id,
      );

      final affectedTrips = await Future.wait(
        affectedTripIds.map(_tripRepository.getTripById),
      );
      for (final trip in affectedTrips) {
        AppServices.instance.carTripEvents.publish(trip);
      }

      if (!mounted) return;
      setState(() {
        _history = List.unmodifiable(
          _history.where((entry) => entry.transaction.id != item.transaction.id),
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment deleted and balances restored.')),
      );
    } catch (error) {
      if (mounted) _showError('$error');
    } finally {
      if (mounted) setState(() => _deletingTransactionId = null);
    }
  }

  String _paymentInvoiceLabel(CarTrip trip) {
    final date = trip.openedAt.toLocal();
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} · ${trip.salesCarName}';
  }

  CarTrip? _tripById(int id) {
    for (final trip in _allTrips) {
      if (trip.id == id) return trip;
    }
    return null;
  }

  String _dayKey(DateTime value) {
    final local = value.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }

  String _dayTitle(DateTime value) {
    final local = value.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);
    if (day == today) return 'Today · ${_formatDate(local)}';
    if (day == today.subtract(const Duration(days: 1))) {
      return 'Yesterday · ${_formatDate(local)}';
    }
    return _formatDate(local);
  }

  String _formatDate(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

  String _formatTime(DateTime value) {
    final local = value.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

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
          const Text(
            'Car payments',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            'One payment stays inside one Car + Warehouse group and can be distributed only across that group’s finalized outstanding invoices.',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 18),
          _paymentForm(),
          const SizedBox(height: 18),
          const Text(
            'Outstanding invoices',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          if (_selectedScope == null)
            const EmptyState(
              icon: Icons.account_tree_outlined,
              title: 'Select a payment group',
              message: 'Choose the exact Car and Warehouse before applying a payment.',
            )
          else if (_selectedOutstandingTrips.isEmpty)
            const EmptyState(
              icon: Icons.check_circle_outline_rounded,
              title: 'Everything is paid',
              message: 'There are no finalized outstanding invoices for this Car + Warehouse group.',
            )
          else
            for (final trip in _selectedOutstandingTrips) _tripRow(trip),
          const SizedBox(height: 14),
          const Text(
            'Payment history',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          _buildHistory(),
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
          const Text(
            'Record payment',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
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
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Cash',
                    suffixText: 'EGP',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _transferController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Transfer',
                    suffixText: 'EGP',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _referenceController,
            decoration: const InputDecoration(
              labelText: 'Reference (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Total payment',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ),
              Text(
                'EGP ${amount.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _processing || _selectedScope == null ? null : _pay,
            icon: _processing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.payments_rounded),
            label: Text(_processing ? 'Applying...' : 'Apply payment'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
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
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(Icons.receipt_long_rounded, color: scheme.primary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _paymentInvoiceLabel(trip),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${trip.warehouseName} · ${trip.payment.totalPaid.units.toStringAsFixed(2)} paid',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'EGP ${(remaining / 100).toStringAsFixed(2)}',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: scheme.error,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistory() {
    if (_history.isEmpty) {
      return const EmptyState(
        icon: Icons.history_rounded,
        title: 'No payments recorded yet',
        message: 'Confirmed Car payments will stay here as an auditable history.',
      );
    }

    final groups = <String, List<_PaymentHistoryItem>>{};
    for (final item in _history) {
      groups.putIfAbsent(_dayKey(item.transaction.createdAt), () => []).add(item);
    }

    final orderedGroups = groups.values.toList()
      ..sort(
        (a, b) => b.first.transaction.createdAt.compareTo(a.first.transaction.createdAt),
      );

    return Column(
      children: [
        for (var index = 0; index < orderedGroups.length; index++)
          _historyDaySection(
            orderedGroups[index],
            initiallyExpanded: index == 0,
          ),
      ],
    );
  }

  Widget _historyDaySection(
    List<_PaymentHistoryItem> items, {
    required bool initiallyExpanded,
  }) {
    final firstDate = items.first.transaction.createdAt.toLocal();
    final total = items.fold<double>(
      0,
      (sum, item) => sum + item.transaction.totalAmount.units,
    );
    final allocationCount = items.fold<int>(
      0,
      (sum, item) => sum + item.allocations.length,
    );

    return DaySummarySection(
      title: _dayTitle(firstDate),
      summary:
          '${items.length} payment${items.length == 1 ? '' : 's'} · EGP ${total.toStringAsFixed(2)} · $allocationCount invoice allocations',
      initiallyExpanded: initiallyExpanded,
      children: [
        for (final item in items) _historyCard(item),
      ],
    );
  }

  Widget _historyCard(_PaymentHistoryItem item) {
    final scheme = Theme.of(context).colorScheme;
    final transaction = item.transaction;
    final firstTrip = item.allocations.isEmpty
        ? null
        : _tripById(item.allocations.first.tripId);
    final scopeLabel = firstTrip == null
        ? 'Payment group unavailable'
        : '${firstTrip.salesCarName} · ${firstTrip.warehouseName}';
    final deleting = _deletingTransactionId == transaction.id;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: scheme.primaryContainer,
                  foregroundColor: scheme.primary,
                  child: const Icon(Icons.payments_rounded),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Payment · ${_formatTime(transaction.createdAt)}',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        scopeLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  'EGP ${transaction.totalAmount.units.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                IconButton(
                  tooltip: 'Delete payment',
                  onPressed: deleting ? null : () => _deletePayment(item),
                  icon: deleting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
            if (transaction.reference != null &&
                transaction.reference!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Reference: ${transaction.reference}',
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 10),
            for (final allocation in item.allocations)
              _historyAllocationRow(allocation),
          ],
        ),
      ),
    );
  }

  Widget _historyAllocationRow(CarPaymentAllocation allocation) {
    final scheme = Theme.of(context).colorScheme;
    final trip = _tripById(allocation.tripId);
    final total = trip == null ? 0 : _totalFor(trip);
    final remaining = trip == null
        ? null
        : (total - trip.payment.totalPaid.minorUnits).clamp(0, 1 << 62);
    final paid = remaining == 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Row(
          children: [
            Icon(
              paid ? Icons.check_circle_rounded : Icons.receipt_long_rounded,
              size: 18,
              color: paid ? scheme.primary : scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                trip == null ? 'Invoice unavailable' : _paymentInvoiceLabel(trip),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '− EGP ${allocation.totalAmount.units.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(width: 8),
            Text(
              paid
                  ? 'Paid'
                  : remaining == null
                      ? 'Recorded'
                      : 'EGP ${(remaining / 100).toStringAsFixed(2)} left',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: paid ? scheme.primary : scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentHistoryItem {
  final CarPaymentTransaction transaction;
  final List<CarPaymentAllocation> allocations;

  const _PaymentHistoryItem({
    required this.transaction,
    required this.allocations,
  });
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
