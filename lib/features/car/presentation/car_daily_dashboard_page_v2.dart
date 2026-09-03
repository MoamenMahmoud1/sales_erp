import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/repositories/app_services.dart';
import '../../../core/ui/app_card.dart';
import '../../../core/ui/empty_state.dart';
import '../../../core/ui/status_badge.dart';
import '../domain/entities/car_payment_status.dart';
import '../domain/entities/car_trip.dart';
import '../domain/entities/car_trip_filter.dart';
import '../domain/entities/car_trip_status.dart';
import '../domain/entities/car_trip_summary_view.dart';
import '../domain/services/car_calculator.dart';
import '../domain/services/car_payment_evaluator.dart';
import 'car_trip_details_page.dart';
import 'car_trip_editor_page.dart';

/// Today contains finalized trips only. A trip enters Today using the moment
/// it was confirmed (closedAt), never the moment a draft was saved.
class CarDailyDashboardPageV2 extends StatefulWidget {
  final ValueChanged<int>? onNavigate;

  const CarDailyDashboardPageV2({super.key, this.onNavigate});

  @override
  State<CarDailyDashboardPageV2> createState() =>
      _CarDailyDashboardPageV2State();
}

class _CarDailyDashboardPageV2State extends State<CarDailyDashboardPageV2>
    with WidgetsBindingObserver {
  final _repository = AppServices.instance.carTripRepository;
  final _calculator = const CarCalculator();
  final _paymentEvaluator = const CarPaymentEvaluator();

  late final StreamSubscription<CarTrip> _tripChanges;
  late final StreamSubscription<int> _tripDeletions;

  DateTime _day = _today();
  List<CarTripSummaryView> _trips = const [];
  bool _loading = true;
  String? _error;

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tripChanges = AppServices.instance.carTripEvents.stream.listen(_onTripChanged);
    _tripDeletions = AppServices.instance.carTripEvents.deletionStream.listen(_onTripDeleted);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tripChanges.cancel();
    _tripDeletions.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final today = _today();
    if (!_sameDay(today, _day)) {
      _day = today;
      _load();
    }
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final confirmed = await _repository.getTripSummaries(
        filter: const CarTripFilter(status: CarTripStatus.closed),
      );
      final today = confirmed.where((trip) {
        final confirmedAt = trip.closedAt?.toLocal();
        return confirmedAt != null && _sameDay(confirmedAt, _day);
      }).toList(growable: false);
      if (!mounted) return;
      setState(() {
        _trips = List.unmodifiable(today);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() { _loading = false; _error = '$error'; });
    }
  }

  void _onTripChanged(CarTrip trip) {
    if (!mounted || trip.id <= 0) return;
    final next = [..._trips]..removeWhere((item) => item.id == trip.id);
    final confirmedAt = trip.closedAt?.toLocal();
    if (trip.isClosed && confirmedAt != null && _sameDay(confirmedAt, _day)) {
      next.add(_summary(trip));
    }
    next.sort((a, b) =>
        (b.closedAt ?? b.openedAt).compareTo(a.closedAt ?? a.openedAt));
    setState(() => _trips = List.unmodifiable(next));
  }

  void _onTripDeleted(int tripId) {
    if (!mounted) return;
    final next = [..._trips]..removeWhere((trip) => trip.id == tripId);
    if (next.length != _trips.length) {
      setState(() => _trips = List.unmodifiable(next));
    }
  }

  CarTripSummaryView _summary(CarTrip trip) {
    final summary = _calculator.summary(trip);
    return CarTripSummaryView(
      id: trip.id,
      displayNumber: trip.displayNumber,
      salesCarName: trip.salesCarName,
      warehouseName: trip.warehouseName,
      openedAt: trip.openedAt,
      closedAt: trip.closedAt,
      dueDate: trip.dueDate,
      status: trip.status,
      totalLoadedCartons: summary.totalLoadedCartons,
      totalReturnedCartons: summary.totalReturnedCartons,
      totalSoldCartons: summary.totalSoldCartons,
      totalReturnedValue: summary.totalReturnedValue,
      grossSubtotal: summary.grossSubtotal,
      productDiscountTotal: summary.productDiscountTotal,
      subtotalAfterProducts: summary.subtotalAfterProducts,
      globalDiscountAmount: summary.globalDiscountAmount,
      finalValue: summary.finalTotalSoldValue,
      paidCash: trip.payment.cashAmount,
      paidTransfer: trip.payment.transferAmount,
    );
  }

  ({StatusType type, String label}) _paymentStatus(CarTripSummaryView trip) {
    switch (trip.paymentStatus(_paymentEvaluator, DateTime.now())) {
      case CarPaymentStatus.paid:
        return (type: StatusType.success, label: 'Paid');
      case CarPaymentStatus.partiallyPaid:
        return (type: StatusType.warning, label: 'Partial');
      case CarPaymentStatus.unpaid:
        return (type: StatusType.neutral, label: 'Unpaid');
      case CarPaymentStatus.overdue:
        return (type: StatusType.error, label: 'Overdue');
    }
  }

  String _money(int minor) => 'EGP ${(minor / 100).toStringAsFixed(2)}';

  String _date(DateTime value) {
    final d = value.toLocal();
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  int _sum(int Function(CarTripSummaryView trip) value) =>
      _trips.fold(0, (sum, trip) => sum + value(trip));

  @override
  Widget build(BuildContext context) {
    if (_loading && _trips.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _trips.isEmpty) {
      return Center(
        child: EmptyState(
          icon: Icons.error_outline_rounded,
          title: 'Unable to load today',
          message: _error!,
          actionLabel: 'Retry',
          onAction: _load,
        ),
      );
    }

    final scheme = Theme.of(context).colorScheme;
    final soldValue = _sum((trip) => trip.finalValue.minorUnits);
    final paidValue = _sum((trip) => trip.paidTotal.minorUnits);
    final outstandingValue = _sum((trip) => trip.remaining.minorUnits);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: [
          Row(children: [
            const Expanded(child: Text('Car dashboard', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900))),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CarTripEditorPage()),
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text('New trip'),
            ),
          ]),
          const SizedBox(height: 4),
          Text('Confirmed today · ${_date(_day)}', style: TextStyle(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(17),
            decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(20)),
            child: Row(children: [
              Icon(Icons.verified_rounded, color: scheme.onPrimaryContainer, size: 28),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Confirmed sales', style: TextStyle(color: scheme.onPrimaryContainer.withValues(alpha: .76), fontSize: 11, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(_money(soldValue), style: TextStyle(color: scheme.onPrimaryContainer, fontSize: 28, fontWeight: FontWeight.w900))),
                Text('${_trips.length} finalized trip${_trips.length == 1 ? '' : 's'}', style: TextStyle(color: scheme.onPrimaryContainer.withValues(alpha: .70), fontSize: 11)),
              ])),
            ]),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(builder: (context, constraints) {
            final width = (constraints.maxWidth - 10) / 2;
            return Wrap(spacing: 10, runSpacing: 10, children: [
              _metric(width, 'Trips', '${_trips.length}', Icons.route_rounded),
              _metric(width, 'Loaded', '${_sum((trip) => trip.totalLoadedCartons)}', Icons.outbox_rounded),
              _metric(width, 'Returned', '${_sum((trip) => trip.totalReturnedCartons)}', Icons.assignment_return_rounded),
              _metric(width, 'Sold', '${_sum((trip) => trip.totalSoldCartons)}', Icons.point_of_sale_rounded),
              _metric(width, 'Paid', _money(paidValue), Icons.payments_rounded),
              _metric(width, 'Outstanding', _money(outstandingValue), Icons.account_balance_wallet_outlined),
            ]);
          }),
          const SizedBox(height: 18),
          Row(children: [
            const Expanded(child: Text('Confirmed trips', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
            TextButton(onPressed: () => widget.onNavigate?.call(1), child: const Text('All trips')),
          ]),
          const SizedBox(height: 6),
          if (_trips.isEmpty)
            const EmptyState(
              icon: Icons.verified_outlined,
              title: 'No confirmed trips today',
              message: 'Drafts stay out of Today until they are confirmed.',
            )
          else
            for (final trip in _trips) _tripCard(trip),
        ],
      ),
    );
  }

  Widget _metric(double width, String label, String value, IconData icon) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(width: width, child: AppCard(
      padding: const EdgeInsets.all(13),
      child: Row(children: [
        Icon(icon, size: 20, color: scheme.primary),
        const SizedBox(width: 9),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 10.5, color: scheme.onSurfaceVariant)),
          const SizedBox(height: 2),
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900))),
        ])),
      ]),
    ));
  }

  Widget _tripCard(CarTripSummaryView trip) {
    final scheme = Theme.of(context).colorScheme;
    final payment = _paymentStatus(trip);
    final confirmedAt = trip.closedAt!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: const EdgeInsets.all(14),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => CarTripDetailsPage(tripId: trip.id)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 44, height: 44, decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(14)), child: Icon(Icons.verified_rounded, color: scheme.primary)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(trip.displayNumber, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
              const SizedBox(height: 2),
              Text('${trip.salesCarName} · ${trip.warehouseName}', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant)),
            ])),
            const SizedBox(width: 8),
            StatusBadge(type: payment.type, label: payment.label),
          ]),
          const SizedBox(height: 11),
          Wrap(spacing: 7, runSpacing: 7, children: [
            _pill('Confirmed', _date(confirmedAt), scheme.primaryContainer),
            _pill('Loaded', '${trip.totalLoadedCartons}', scheme.surfaceContainerHighest),
            _pill('Returned', '${trip.totalReturnedCartons}', scheme.surfaceContainerHighest),
            _pill('Sold', '${trip.totalSoldCartons}', scheme.surfaceContainerHighest),
            _pill('Total', _money(trip.finalValue.minorUnits), scheme.surfaceContainerHighest),
          ]),
        ]),
      ),
    );
  }

  Widget _pill(String label, String value, Color background) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(10)),
      child: RichText(text: TextSpan(style: TextStyle(color: scheme.onSurface, fontSize: 10.5), children: [
        TextSpan(text: '$label  ', style: TextStyle(color: scheme.onSurfaceVariant)),
        TextSpan(text: value, style: const TextStyle(fontWeight: FontWeight.w900)),
      ])),
    );
  }
}
