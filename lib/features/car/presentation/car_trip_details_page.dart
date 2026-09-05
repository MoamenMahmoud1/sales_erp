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
import 'car_invoice_payment_card.dart';
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
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => CarTripEditorPage(tripId: trip.id)));
    if (mounted) await _load();
  }

  String _money(CarMoney value) => 'EGP ${value.units.toStringAsFixed(2)}';

  String _date(DateTime value) {
    final d = value.toLocal();
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  StatusType _paymentType(CarPaymentStatus status) => switch (status) {
        CarPaymentStatus.paid => StatusType.success,
        CarPaymentStatus.partiallyPaid => StatusType.warning,
        CarPaymentStatus.unpaid => StatusType.neutral,
        CarPaymentStatus.overdue => StatusType.error,
      };

  String _paymentLabel(CarPaymentStatus status) => switch (status) {
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
        appBar: AppBar(title: const Text('Car invoice')),
        body: EmptyState(
          icon: Icons.error_outline_rounded,
          title: _error == null ? 'Car invoice not found' : 'Unable to load Car invoice',
          message: _error ?? 'This transaction is no longer available.',
          actionLabel: 'Retry',
          onAction: _load,
        ),
      );
    }

    final summary = _calculator.summary(trip);
    final paymentStatus = _evaluator.statusOf(trip, summary, DateTime.now());
    final remaining = _calculator.remaining(trip, summaryOf: summary);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('Car invoice · ${_date(trip.openedAt)}'),
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
            _headerCard(trip, paymentStatus),
            const SizedBox(height: 10),
            _flow(summary),
            const SizedBox(height: 10),
            _productBreakdown(summary),
            const SizedBox(height: 10),
            _financial(summary),
            const SizedBox(height: 10),
            AppCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Payment status', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: _moneyState('Paid', _money(trip.payment.totalPaid), scheme.primaryContainer, scheme.onPrimaryContainer, Icons.check_circle_rounded)),
                    const SizedBox(width: 8),
                    Expanded(child: _moneyState('Outstanding', _money(remaining), remaining == CarMoney.zero ? scheme.primaryContainer : scheme.errorContainer, remaining == CarMoney.zero ? scheme.onPrimaryContainer : scheme.onErrorContainer, remaining == CarMoney.zero ? Icons.check_rounded : Icons.account_balance_wallet_outlined)),
                  ]),
                  const SizedBox(height: 9),
                  Text(
                    remaining == CarMoney.zero ? 'Invoice is fully paid.' : 'Outstanding balance is still due on this invoice.',
                    style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            if (remaining != CarMoney.zero) ...[
              const SizedBox(height: 10),
              CarInvoicePaymentCard(
                trip: trip,
                remaining: remaining,
                onPaymentCompleted: (updatedTrip) {
                  if (!mounted) return;
                  setState(() => _trip = updatedTrip);
                },
              ),
            ],
            const SizedBox(height: 10),
            _revisionCard(),
          ],
        ),
      ),
    );
  }

  Widget _headerCard(CarTrip trip, CarPaymentStatus paymentStatus) {
    final scheme = Theme.of(context).colorScheme;
    final draft = !trip.isClosed;
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(color: draft ? scheme.tertiaryContainer : scheme.primaryContainer, borderRadius: BorderRadius.circular(16)),
          child: Icon(draft ? Icons.edit_note_rounded : Icons.local_shipping_rounded, color: draft ? scheme.onTertiaryContainer : scheme.primary),
        ),
        const SizedBox(width: 11),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(trip.displayNumber, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
          const SizedBox(height: 3),
          Text('${trip.salesCarName} · ${trip.warehouseName}', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant)),
        ])),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          StatusBadge(type: draft ? StatusType.warning : StatusType.success, label: draft ? 'Draft' : 'Confirmed'),
          if (!draft) ...[const SizedBox(height: 5), StatusBadge(type: _paymentType(paymentStatus), label: _paymentLabel(paymentStatus))],
        ]),
      ]),
    );
  }

  Widget _flow(dynamic summary) => AppCard(
        child: Row(children: [
          _flowMetric('Loaded', summary.totalLoadedCartons, Icons.outbox_rounded),
          const Icon(Icons.arrow_forward_rounded, size: 18),
          _flowMetric('Returned', summary.totalReturnedCartons, Icons.assignment_return_rounded),
          const Icon(Icons.arrow_forward_rounded, size: 18),
          _flowMetric('Sold', summary.totalSoldCartons, Icons.point_of_sale_rounded),
        ]),
      );

  Widget _flowMetric(String label, int value, IconData icon) => Expanded(child: Column(children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 2),
        Text('$value', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
        Text(label, style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ]));

  Widget _productBreakdown(dynamic summary) => AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Product breakdown', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          if (summary.items.isEmpty) const Text('No products on this invoice.')
          else for (final line in summary.items)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [Expanded(child: Text(line.item.productName, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900))), const SizedBox(width: 8), Text('${line.soldCartons} sold', style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w700))]),
                const SizedBox(height: 7),
                Wrap(spacing: 7, runSpacing: 5, children: [
                  _mini('Buy', _money(line.item.purchasePrice), true),
                  _mini('Discount', _money(line.discountAmount), true),
                  _mini('Cost', _money(line.purchaseCost), true),
                  _mini('Profit', _money(line.profitBeforeGlobalDiscount), true),
                  _mini('Sell', _money(line.item.sellingPrice), false),
                ]),
              ]),
            ),
        ]),
      );

  Widget _mini(String label, String value, bool strong) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(color: strong ? scheme.primaryContainer : scheme.surface, borderRadius: BorderRadius.circular(9)),
      child: Text('$label  $value', style: TextStyle(fontSize: 10.5, fontWeight: strong ? FontWeight.w900 : FontWeight.w700, color: strong ? scheme.onPrimaryContainer : scheme.onSurfaceVariant)),
    );
  }

  Widget _financial(dynamic summary) => AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Financial summary', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          _amount('Buying cost', summary.totalPurchaseCost, strong: true),
          _amount('Product discounts', summary.productDiscountTotal),
          _amount('Global % discount', summary.globalDiscountPercentAmount),
          _amount('Global EGP discount', summary.globalDiscountFixedAmount),
          const Divider(height: 16),
          _amount('Profit', summary.profit, strong: true),
          _amount('Selling total', summary.finalTotalSoldValue),
        ]),
      );

  Widget _amount(String label, CarMoney amount, {bool strong = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [Expanded(child: Text(label, style: TextStyle(fontWeight: strong ? FontWeight.w800 : FontWeight.w500))), const SizedBox(width: 10), Text(_money(amount), style: TextStyle(fontWeight: strong ? FontWeight.w900 : FontWeight.w700))]),
      );

  Widget _moneyState(String label, String value, Color background, Color foreground, IconData icon) => Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(13)),
        child: Row(children: [
          Icon(icon, size: 19, color: foreground),
          const SizedBox(width: 7),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: TextStyle(fontSize: 10, color: foreground.withValues(alpha: .72))), const SizedBox(height: 2), Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w900, color: foreground))])),
        ]),
      );

  Widget _revisionCard() => AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Revision history', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          if (_revisions.isEmpty) const Text('No revisions recorded yet.')
          else for (final revision in _revisions.reversed)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(child: Text('${revision.revisionNumber}')),
              title: Text('Revision ${revision.revisionNumber}', style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text('${_date(revision.createdAt)} · ${revision.salesCarName} · ${revision.warehouseName}'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CarRevisionDetailsPage(revision: revision))),
            ),
        ]),
      );
}
