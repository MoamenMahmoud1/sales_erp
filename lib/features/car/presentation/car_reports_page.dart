import 'package:flutter/material.dart';

import '../../../core/repositories/app_services.dart';
import '../../../core/ui/app_card.dart';
import '../../../core/ui/empty_state.dart';
import '../domain/entities/car_totals.dart';

class CarReportsPage extends StatefulWidget {
  const CarReportsPage({super.key});

  @override
  State<CarReportsPage> createState() => _CarReportsPageState();
}

class _CarReportsPageState extends State<CarReportsPage> {
  final _reports = AppServices.instance.carReportRepository;
  DateTime? _from;
  DateTime? _to;
  CarTotals? _totals;
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
      final totals = await _reports.getTotals(from: _from, to: _to);
      if (!mounted) return;
      setState(() { _totals = totals; _loading = false; });
    } catch (error) {
      if (!mounted) return;
      setState(() { _loading = false; _error = '$error'; });
    }
  }

  String _money(int minor) => 'EGP ${(minor / 100).toStringAsFixed(2)}';
  String _date(DateTime value) => '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

  Future<void> _pickFrom() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 3),
      initialDate: _from ?? now,
    );
    if (picked != null) {
      _from = picked;
      if (_to != null && _to!.isBefore(picked)) _to = picked;
      await _load();
    }
  }

  Future<void> _pickTo() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: _from ?? DateTime(now.year - 3),
      lastDate: DateTime(now.year + 3),
      initialDate: _to ?? _from ?? now,
    );
    if (picked != null) {
      _to = picked;
      await _load();
    }
  }

  void _clearDates() {
    setState(() {
      _from = null;
      _to = null;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final totals = _totals;
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null || totals == null) {
      return Center(child: EmptyState(
        icon: Icons.error_outline_rounded,
        title: 'Unable to load Car report',
        message: _error ?? 'No report data available.',
        actionLabel: 'Retry',
        onAction: _load,
      ));
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: [
          const Text('Car reports', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text('Operational and financial summary for finalized Car activity.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 16),
          _dateFilter(),
          const SizedBox(height: 16),
          _cartonFlow(totals),
          const SizedBox(height: 12),
          _financial(totals),
          const SizedBox(height: 12),
          _paymentStatus(totals),
        ],
      ),
    );
  }

  Widget _dateFilter() {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      child: Row(
        children: [
          Expanded(child: OutlinedButton.icon(onPressed: _pickFrom, icon: const Icon(Icons.calendar_today_outlined, size: 18), label: Text(_from == null ? 'From' : _date(_from!)))),
          const SizedBox(width: 8),
          Expanded(child: OutlinedButton.icon(onPressed: _pickTo, icon: const Icon(Icons.event_outlined, size: 18), label: Text(_to == null ? 'To' : _date(_to!)))),
          if (_from != null || _to != null)
            IconButton(tooltip: 'Clear date filter', onPressed: _clearDates, icon: Icon(Icons.clear_rounded, color: scheme.error)),
        ],
      ),
    );
  }

  Widget _cartonFlow(CarTotals totals) => AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Carton flow', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
          const SizedBox(height: 14),
          Row(children: [
            _metric('Loaded', totals.totalLoadedCartons, Icons.outbox_rounded),
            const Icon(Icons.arrow_forward_rounded),
            _metric('Returned', totals.totalReturnedCartons, Icons.assignment_return_rounded),
            const Icon(Icons.arrow_forward_rounded),
            _metric('Sold', totals.totalSoldCartons, Icons.point_of_sale_rounded),
          ]),
          const SizedBox(height: 12),
          Text(
            '${totals.totalSoldCartons} of ${totals.totalLoadedCartons} loaded cartons were actually sold.',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
          ),
        ]),
      );

  Widget _metric(String label, int value, IconData icon) => Expanded(child: Column(children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 5),
        Text('$value', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22)),
        Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 11)),
      ]));

  Widget _financial(CarTotals totals) => AppCard(
        child: Column(children: [
          const Align(alignment: Alignment.centerLeft, child: Text('Financial report', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900))),
          const SizedBox(height: 10),
          _row('Gross sold value', totals.grossSubtotal.minorUnits),
          _row('Product discounts', totals.productDiscountTotal.minorUnits),
          _row('After product discounts', totals.subtotalAfterProducts.minorUnits),
          _row('Global discount', totals.globalDiscountAmount.minorUnits),
          const Divider(height: 22),
          _row('Actual sold value', totals.finalValue.minorUnits, strong: true),
          _row('Total paid', totals.totalPaid.minorUnits),
          _row('Total remaining', totals.totalRemaining.minorUnits, strong: true),
        ]),
      );

  Widget _paymentStatus(CarTotals totals) => AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Payment status', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          _countRow('Paid', totals.paidCount),
          _countRow('Partially paid', totals.partiallyPaidCount),
          _countRow('Unpaid', totals.unpaidCount),
          _countRow('Overdue', totals.overdueCount),
        ]),
      );

  Widget _row(String label, int minor, {bool strong = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: TextStyle(fontWeight: strong ? FontWeight.w800 : FontWeight.w500)),
          Text(_money(minor), style: TextStyle(fontWeight: strong ? FontWeight.w900 : FontWeight.w700, fontSize: strong ? 17 : 13)),
        ]),
      );

  Widget _countRow(String label, int count) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label), Text('$count', style: const TextStyle(fontWeight: FontWeight.w900))]),
      );
}
