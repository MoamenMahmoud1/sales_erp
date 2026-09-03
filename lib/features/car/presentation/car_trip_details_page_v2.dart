import 'package:flutter/material.dart';

import '../../../core/repositories/app_services.dart';
import '../../../core/ui/app_card.dart';
import '../../../core/ui/empty_state.dart';
import '../../../core/ui/status_badge.dart';
import '../domain/entities/car_payment_status.dart';
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
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final trip = await _repository.getTripById(widget.tripId);
      if (!mounted) return;
      setState(() {
        _trip = trip;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$error';
      });
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

  String _formatDate(DateTime value) {
    final local = value.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
  }

  String _tripTitle(DateTime value) => 'Car invoice · ${_formatDate(value)}';

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
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final trip = _trip;
    if (_error != null || trip == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Car trip')),
        body: EmptyState(
          icon: Icons.receipt_long_outlined,
          title: _error == null ? 'Car trip not found' : 'Unable to load Car trip',
          message: _error ?? 'This transaction is no longer available.',
          actionLabel: 'Retry',
          onAction: _load,
        ),
      );
    }

    final summary = _calculator.summary(trip);
    final paymentStatus = _evaluator.statusOf(trip, summary, DateTime.now());
    final remaining = _calculator.remaining(trip, summaryOf: summary);

    return Scaffold(
      appBar: AppBar(
        title: Text(_tripTitle(trip.openedAt)),
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
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          children: [
            AppCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(Icons.local_shipping_rounded, color: Theme.of(context).colorScheme.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_tripTitle(trip.openedAt), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 3),
                        Text('${trip.salesCarName} · ${trip.warehouseName}', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  StatusBadge(type: _statusType(paymentStatus), label: _statusLabel(paymentStatus)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Carton flow', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _flowMetric('Loaded', summary.totalLoadedCartons, Icons.outbox_rounded),
                      const Icon(Icons.arrow_forward_rounded, size: 18),
                      _flowMetric('Returned', summary.totalReturnedCartons, Icons.assignment_return_rounded),
                      const Icon(Icons.arrow_forward_rounded, size: 18),
                      _flowMetric('Sold', summary.totalSoldCartons, Icons.point_of_sale_rounded),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _productBreakdown(summary),
            const SizedBox(height: 12),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Financial summary', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  _amount('Selling total', summary.finalTotalSoldValue),
                  _amount('Buying cost', summary.totalPurchaseCost),
                  _amount('Product discount EGP', summary.productDiscountTotal),
                  _amount('Global discount %', summary.globalDiscountPercentAmount),
                  _amount('Global discount EGP', summary.globalDiscountFixedAmount),
                  const Divider(height: 18),
                  _amount('Profit', summary.profit, strong: true),
                ],
              ),
            ),
            const SizedBox(height: 12),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Payment', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  _amount('Paid', trip.payment.totalPaid),
                  _amount('Remaining', remaining, strong: true),
                ],
              ),
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<dynamic>>(
              future: _repository.getRevisionsForTrip(trip.id),
              builder: (context, snapshot) {
                final revisions = snapshot.data ?? const [];
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  );
                }
                return _revisionCard(revisions);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _flowMetric(String label, int value, IconData icon) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: scheme.primary),
          const SizedBox(height: 3),
          Text('$value', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          Text(label, style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _productBreakdown(dynamic summary) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Product breakdown', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          if (summary.items.isEmpty)
            const Text('No products on this trip.')
          else
            for (final line in summary.items) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(line.item.productName, style: const TextStyle(fontWeight: FontWeight.w800))),
                        Text('${line.soldCartons} sold', style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant, fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 2,
                      children: [
                        Text('Sell ${_money(line.item.sellingPrice)}', style: const TextStyle(fontSize: 11)),
                        Text('Buy ${_money(line.item.purchasePrice)}', style: const TextStyle(fontSize: 11)),
                        Text('Disc EGP ${_money(line.discountAmount)}', style: const TextStyle(fontSize: 11)),
                        Text('Cost ${_money(line.purchaseCost)}', style: const TextStyle(fontSize: 11)),
                        Text('Profit ${_money(line.profitBeforeGlobalDiscount)}', style: const TextStyle(fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              ),
              if (line != summary.items.last) const Divider(height: 1),
            ],
        ],
      ),
    );
  }

  Widget _amount(String label, dynamic amount, {bool strong = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                softWrap: true,
                style: TextStyle(fontWeight: strong ? FontWeight.w800 : FontWeight.w500),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              _money(amount),
              textAlign: TextAlign.end,
              style: TextStyle(fontWeight: strong ? FontWeight.w900 : FontWeight.w700),
            ),
          ],
        ),
      );

  Widget _revisionCard(List<dynamic> revisions) => AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Revision history', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            if (revisions.isEmpty)
              const Text('No revisions recorded yet.')
            else
              for (final revision in revisions.reversed)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(child: Text('${revision.revisionNumber}')),
                  title: Text('Revision ${revision.revisionNumber}', style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text('${_formatDate(revision.createdAt)} · ${revision.salesCarName} · ${revision.warehouseName}'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => CarRevisionDetailsPage(revision: revision)),
                  ),
                ),
          ],
        ),
      );
}
