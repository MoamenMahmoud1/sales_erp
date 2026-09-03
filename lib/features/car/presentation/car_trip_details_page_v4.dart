import 'package:flutter/material.dart';

import '../../../core/repositories/app_services.dart';
import '../../../core/ui/app_card.dart';
import '../../../core/ui/empty_state.dart';
import '../../../core/ui/status_badge.dart';
import '../domain/entities/car_payment_status.dart';
import '../domain/entities/car_revision.dart';
import '../domain/entities/car_trip.dart';
import '../domain/entities/money.dart';
import '../domain/services/car_calculator.dart';
import '../domain/services/car_payment_evaluator.dart';
import 'car_revision_details_page.dart';
import 'car_trip_editor_page.dart';

class CarTripDetailsPage extends StatefulWidget {
  final int tripId;

  const CarTripDetailsPage({super.key, required this.tripId});

  @override
  State<CarTripDetailsPage> createState() => _CarTripDetailsPageState();
}

class _CarTripDetailsPageState extends State<CarTripDetailsPage> {
  final _repository = AppServices.instance.carTripRepository;
  final _calculator = const CarCalculator();
  final _evaluator = const CarPaymentEvaluator();

  CarTrip? _trip;
  List<CarRevision> _revisions = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final trip = await _repository.getTripById(widget.tripId);
      if (trip == null) throw StateError('Car invoice not found.');
      final revisions = await _repository.getRevisionsForTrip(widget.tripId);
      if (!mounted) return;
      setState(() {
        _trip = trip;
        _revisions = revisions;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() { _loading = false; _error = '$error'; });
    }
  }

  Future<void> _edit() async {
    final trip = _trip;
    if (trip == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CarTripEditorPage(tripId: trip.id)),
    );
    if (mounted) await _load();
  }

  String _money(CarMoney value) => 'EGP ${value.units.toStringAsFixed(2)}';

  String _date(DateTime value) {
    final local = value.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
  }

  String _tripTitle(CarTrip trip) => 'Car invoice · ${_date(trip.openedAt)}';

  StatusType _statusType(CarPaymentStatus status) => switch (status) {
        CarPaymentStatus.paid => StatusType.success,
        CarPaymentStatus.partiallyPaid => StatusType.warning,
        CarPaymentStatus.unpaid => StatusType.neutral,
        CarPaymentStatus.overdue => StatusType.error,
      };

  String _statusLabel(CarPaymentStatus status) => switch (status) {
        CarPaymentStatus.paid => 'Paid',
        CarPaymentStatus.partiallyPaid => 'Partially paid',
        CarPaymentStatus.unpaid => 'Unpaid',
        CarPaymentStatus.overdue => 'Overdue',
      };

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final trip = _trip;
    if (_error != null || trip == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Car trip')),
        body: EmptyState(
          icon: Icons.error_outline_rounded,
          title: _error == null ? 'Car trip not found' : 'Unable to load Car trip',
          message: _error ?? 'This transaction is no longer available.',
          actionLabel: 'Retry',
          onAction: _load,
        ),
      );
    }

    final summary = _calculator.summary(trip);
    final status = _evaluator.statusOf(trip, summary, DateTime.now());
    final remaining = _calculator.remaining(trip, summaryOf: summary);

    return Scaffold(
      appBar: AppBar(
        title: Text(_tripTitle(trip)),
        actions: [
          IconButton(
            tooltip: trip.isClosed ? 'Edit and create revision' : 'Edit draft',
            onPressed: _edit,
            icon: const Icon(Icons.edit_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 110),
          children: [
            AppCard(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(
                      Icons.local_shipping_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_tripTitle(trip), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                        const SizedBox(height: 2),
                        Text('${trip.salesCarName} · ${trip.warehouseName}', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                      ],
                    ),
                  ),
                  StatusBadge(type: _statusType(status), label: _statusLabel(status)),
                ],
              ),
            ),
            const SizedBox(height: 10),
            _flow(summary),
            const SizedBox(height: 10),
            _productBreakdown(summary),
            const SizedBox(height: 10),
            _financial(summary),
            const SizedBox(height: 10),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Payment', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  _amount('Paid', trip.payment.totalPaid),
                  _amount('Remaining', remaining, strong: true),
                ],
              ),
            ),
            const SizedBox(height: 10),
            _revisionCard(),
          ],
        ),
      ),
    );
  }

  Widget _flow(dynamic summary) => AppCard(
        child: Row(
          children: [
            _flowMetric('Loaded', summary.totalLoadedCartons, Icons.outbox_rounded),
            const Icon(Icons.arrow_forward_rounded, size: 18),
            _flowMetric('Returned', summary.totalReturnedCartons, Icons.assignment_return_rounded),
            const Icon(Icons.arrow_forward_rounded, size: 18),
            _flowMetric('Sold', summary.totalSoldCartons, Icons.point_of_sale_rounded),
          ],
        ),
      );

  Widget _flowMetric(String label, int value, IconData icon) => Expanded(
        child: Column(
          children: [
            Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 2),
            Text('$value', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
            Text(label, style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ),
      );

  Widget _productBreakdown(dynamic summary) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Product breakdown', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          if (summary.items.isEmpty)
            const Text('No products on this trip.')
          else
            for (final line in summary.items) ...[
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            line.item.productName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('${line.soldCartons} sold', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 7,
                      runSpacing: 5,
                      children: [
                        _mini(label: 'Buy', value: _money(line.item.purchasePrice), strong: true),
                        _mini(label: 'Discount', value: _money(line.discountAmount), strong: true),
                        _mini(label: 'Cost', value: _money(line.purchaseCost), strong: true),
                        _mini(label: 'Profit', value: _money(line.profitBeforeGlobalDiscount), strong: true),
                        _mini(label: 'Sell', value: _money(line.item.sellingPrice)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
        ],
      ),
    );
  }

  Widget _mini({required String label, required String value, bool strong = false}) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: strong ? scheme.primaryContainer : scheme.surface,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        '$label $value',
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
          color: strong ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _financial(dynamic summary) => AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Financial summary', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            _amount('Buying cost', summary.totalPurchaseCost, strong: true),
            _amount('Product discounts', summary.productDiscountTotal),
            _amount('Global % discount', summary.globalDiscountPercentAmount),
            _amount('Global EGP discount', summary.globalDiscountFixedAmount),
            const Divider(height: 16),
            _amount('Profit', summary.profit, strong: true),
            _amount('Selling total', summary.finalTotalSoldValue),
          ],
        ),
      );

  Widget _amount(String label, CarMoney amount, {bool strong = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Expanded(child: Text(label, style: TextStyle(fontWeight: strong ? FontWeight.w800 : FontWeight.w500))),
            const SizedBox(width: 10),
            Text(_money(amount), style: TextStyle(fontWeight: strong ? FontWeight.w900 : FontWeight.w700)),
          ],
        ),
      );

  Widget _revisionCard() => AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Revision history', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            if (_revisions.isEmpty)
              const Text('No revisions recorded yet.')
            else
              for (final revision in _revisions.reversed)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(child: Text('${revision.revisionNumber}')),
                  title: Text('Revision ${revision.revisionNumber}', style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text('${_date(revision.createdAt)} · ${revision.salesCarName} · ${revision.warehouseName}'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => CarRevisionDetailsPage(revision: revision)),
                  ),
                ),
          ],
        ),
      );
}
