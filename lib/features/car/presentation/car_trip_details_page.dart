import 'package:flutter/material.dart';

import '../../../core/repositories/app_services.dart';
import '../../../core/ui/app_card.dart';
import '../../../core/ui/empty_state.dart';
import '../../../core/ui/status_badge.dart';
import '../domain/entities/car_trip.dart';
import '../domain/entities/car_payment_status.dart';
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

  String _money(int minor) => 'EGP ${(minor / 100).toStringAsFixed(2)}';

  String _formatDate(DateTime value) {
    final local = value.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
  }

  String _tripTitle(DateTime value) {
    final local = value.toLocal();
    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));
    final formatted = _formatDate(value);
    final isToday = local.year == today.year &&
        local.month == today.month &&
        local.day == today.day;
    final isYesterday = local.year == yesterday.year &&
        local.month == yesterday.month &&
        local.day == yesterday.day;
    if (isToday) return 'Today · $formatted';
    if (isYesterday) return 'Yesterday · $formatted';
    return formatted;
  }

  ({StatusType type, String label}) _status(CarTrip trip) {
    final summary = _calculator.summary(trip);
    final status = _evaluator.statusOf(trip, summary, DateTime.now());
    return switch (status) {
      CarPaymentStatus.paid => (type: StatusType.success, label: 'Paid'),
      CarPaymentStatus.partiallyPaid => (
        type: StatusType.warning,
        label: 'Partially paid',
      ),
      CarPaymentStatus.overdue => (type: StatusType.error, label: 'Overdue'),
      CarPaymentStatus.unpaid => (type: StatusType.neutral, label: 'Unpaid'),
    };
  }

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
          icon: Icons.receipt_long_outlined,
          title: _error == null ? 'Car trip not found' : 'Unable to load Car trip',
          message: _error ?? 'This transaction is no longer available.',
          actionLabel: 'Retry',
          onAction: _load,
        ),
      );
    }

    final summary = _calculator.summary(trip);
    final status = _status(trip);
    final paymentStatus = _evaluator.statusOf(trip, summary, DateTime.now());
    final remaining = _evaluator.remaining(trip, summary);

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
            _headerCard(trip, status, summary),
            const SizedBox(height: 12),
            _flowCard(summary),
            const SizedBox(height: 12),
            _productBreakdown(summary),
            const SizedBox(height: 12),
            _financialCard(summary),
            const SizedBox(height: 12),
            _paymentCard(trip, remaining, paymentStatus),
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

  Widget _headerCard(
    CarTrip trip,
    ({StatusType type, String label}) status,
    dynamic summary,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final productNames = summary.items
        .map((line) => line.item.productName as String)
        .join(', ');
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.local_shipping_rounded,
                  color: scheme.primary,
                  size: 29,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _tripTitle(trip.openedAt),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${trip.salesCarName} · ${trip.warehouseName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StatusBadge(type: status.type, label: status.label),
            ],
          ),
          if (productNames.isNotEmpty) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Loaded: $productNames',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _info('Opened', _formatDate(trip.openedAt))),
              Expanded(
                child: _info(
                  'Closed',
                  trip.closedAt == null ? 'Open' : _formatDate(trip.closedAt!),
                ),
              ),
              Expanded(
                child: _info(
                  'Due',
                  trip.dueDate == null ? '—' : _formatDate(trip.dueDate!),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _info(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
          ),
        ],
      );

  Widget _flowCard(dynamic summary) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Carton flow',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _flowMetric('Loaded', summary.totalLoadedCartons, Icons.outbox_rounded, scheme.primary),
              const Icon(Icons.remove_rounded, size: 18),
              _flowMetric('Returned', summary.totalReturnedCartons, Icons.assignment_return_rounded, scheme.error),
              const Icon(Icons.drag_handle_rounded, size: 18),
              _flowMetric('Sold', summary.totalSoldCartons, Icons.point_of_sale_rounded, scheme.primary),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.center,
            child: Text(
              '${summary.totalLoadedCartons} loaded − ${summary.totalReturnedCartons} returned = ${summary.totalSoldCartons} sold',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _flowMetric(String label, int value, IconData icon, Color color) =>
      Expanded(
        child: Column(
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 4),
            Text(
              '$value',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );

  Widget _productBreakdown(dynamic summary) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Product breakdown',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          if (summary.items.isEmpty)
            const Text('No products on this trip.')
          else
            for (final line in summary.items)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            line.item.productName,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        Text(
                          _money(line.netValue.minorUnits),
                          style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${line.item.loadedCartons} loaded − ${line.item.returnedCartons} returned = ${line.soldCartons} sold',
                            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant, fontWeight: FontWeight.w700),
                          ),
                        ),
                        Text(
                          '${line.item.discountPercent.toStringAsFixed(2)}% off',
                          style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${_money(line.item.unitPrice.minorUnits)} / carton',
                          style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                        ),
                        Flexible(
                          child: Text(
                            'Sold ${_money(line.grossValue.minorUnits)} · Discount ${_money(line.discountAmount.minorUnits)}',
                            textAlign: TextAlign.end,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'Returned value: ${_money((line.item.unitPrice * line.item.returnedCartons).minorUnits)}',
                        style: TextStyle(fontSize: 11, color: scheme.error, fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (line != summary.items.last) const Divider(height: 18),
                  ],
                ),
              ),
          const Divider(height: 8),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Products total',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              Text(
                '${summary.totalLoadedCartons} − ${summary.totalReturnedCartons} = ${summary.totalSoldCartons} cartons',
                style: TextStyle(
                  color: scheme.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Actual sold value: ${_money(summary.finalTotalSoldValue.minorUnits)}',
              style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }

  Widget _financialCard(dynamic summary) => AppCard(
        child: Column(
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Financial summary',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(height: 10),
            _amountRow('Gross sold value', summary.grossSubtotal),
            _amountRow('Product discounts', summary.productDiscountTotal),
            _amountRow('After product discounts', summary.subtotalAfterProducts),
            _amountRow(
              'Global discount (${summary.globalDiscountPercent.toStringAsFixed(2)}%)',
              summary.globalDiscountAmount,
            ),
            const Divider(height: 22),
            _amountRow('Actual sold value', summary.finalTotalSoldValue, strong: true),
          ],
        ),
      );

  Widget _paymentCard(CarTrip trip, dynamic remaining, CarPaymentStatus status) {
    final scheme = Theme.of(context).colorScheme;
    final statusLabel = switch (status) {
      CarPaymentStatus.paid => 'Paid',
      CarPaymentStatus.partiallyPaid => 'Partially paid',
      CarPaymentStatus.unpaid => 'Unpaid',
      CarPaymentStatus.overdue => 'Overdue',
    };
    final statusType = switch (status) {
      CarPaymentStatus.paid => StatusType.success,
      CarPaymentStatus.partiallyPaid => StatusType.warning,
      CarPaymentStatus.unpaid => StatusType.neutral,
      CarPaymentStatus.overdue => StatusType.error,
    };
    final days = _evaluator.daysOverdue(
      trip,
      DateTime.now(),
      summary: _calculator.summary(trip),
    );
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Payment',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
              ),
              StatusBadge(type: statusType, label: statusLabel),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _info('Paid', _money(trip.payment.totalPaid.minorUnits))),
              Expanded(child: _info('Remaining', _money(remaining.minorUnits))),
            ],
          ),
          if (trip.dueDate != null && days > 0) ...[
            const SizedBox(height: 10),
            Text(
              '$days days overdue',
              style: TextStyle(color: scheme.error, fontWeight: FontWeight.w800),
            ),
          ],
        ],
      ),
    );
  }

  Widget _revisionCard(List<dynamic> revisions) => AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Revision history',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            if (revisions.isEmpty)
              const Text('No revisions recorded yet.')
            else
              for (final revision in revisions.reversed)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(child: Text('${revision.revisionNumber}')),
                  title: Text(
                    'Revision ${revision.revisionNumber}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    '${_formatDate(revision.createdAt)} · ${revision.salesCarName} · ${revision.warehouseName}',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CarRevisionDetailsPage(revision: revision),
                    ),
                  ),
                ),
          ],
        ),
      );

  Widget _amountRow(String label, dynamic amount, {bool strong = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: strong ? FontWeight.w800 : FontWeight.w500),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              _money(amount.minorUnits),
              style: TextStyle(
                fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
                fontSize: strong ? 17 : 13,
              ),
            ),
          ],
        ),
      );
}
