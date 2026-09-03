import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/repositories/app_services.dart';
import '../../../core/ui/app_card.dart';
import '../../../core/ui/empty_state.dart';
import '../../../core/ui/status_badge.dart';
import '../application/usecases/load_car_daily_dashboard.dart';
import '../domain/entities/car_money.dart';
import '../domain/entities/car_payment_status.dart';
import '../domain/entities/car_totals.dart';
import '../domain/entities/car_trip.dart';
import '../domain/entities/car_trip_status.dart';
import '../domain/entities/car_trip_summary_view.dart';
import '../domain/services/car_calculator.dart';
import '../domain/services/car_payment_evaluator.dart';
import 'car_trip_details_page.dart';
import 'car_trip_editor_page.dart';

/// Today-only Car dashboard. The view resets at midnight and stays live from
/// in-memory trip events instead of re-querying after every change.
class CarDailyDashboardPageV2 extends StatefulWidget {
  final ValueChanged<int>? onNavigate;

  const CarDailyDashboardPageV2({super.key, this.onNavigate});

  @override
  State<CarDailyDashboardPageV2> createState() =>
      _CarDailyDashboardPageV2State();
}

class _CarDailyDashboardPageV2State extends State<CarDailyDashboardPageV2>
    with WidgetsBindingObserver {
  final _loader = LoadCarDailyDashboard(
    reportRepository: AppServices.instance.carReportRepository,
    tripRepository: AppServices.instance.carTripRepository,
  );
  final _calculator = const CarCalculator();
  final _evaluator = const CarPaymentEvaluator();

  late final StreamSubscription<CarTrip> _tripChanges;
  late final StreamSubscription<int> _tripDeletions;
  Timer? _midnightTimer;

  DateTime _day = _today();
  List<CarTripSummaryView> _trips = const [];
  CarTotals? _totals;
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
    _tripDeletions =
        AppServices.instance.carTripEvents.deletionStream.listen(_onTripDeleted);
    _scheduleMidnight();
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tripChanges.cancel();
    _tripDeletions.cancel();
    _midnightTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final today = _today();
    if (!_sameDay(today, _day)) {
      _day = today;
      _scheduleMidnight();
      _load();
    }
  }

  void _scheduleMidnight() {
    _midnightTimer?.cancel();
    final now = DateTime.now();
    final next = DateTime(now.year, now.month, now.day + 1);
    _midnightTimer = Timer(next.difference(now) + const Duration(milliseconds: 100), () {
      if (!mounted) return;
      _day = _today();
      _load();
      _scheduleMidnight();
    });
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final data = await _loader(_day);
      if (!mounted || !_sameDay(data.day, _day)) return;
      setState(() {
        _trips = List.unmodifiable(data.trips);
        _totals = data.totals;
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

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

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

  void _onTripChanged(CarTrip trip) {
    if (!mounted || trip.id <= 0) return;
    final next = [..._trips]..removeWhere((item) => item.id == trip.id);
    if (_sameDay(trip.openedAt.toLocal(), _day)) next.add(_summary(trip));
    next.sort((a, b) => b.openedAt.compareTo(a.openedAt));
    setState(() {
      _trips = List.unmodifiable(next);
      _totals = _aggregate(next);
    });
  }

  void _onTripDeleted(int tripId) {
    if (!mounted) return;
    final next = [..._trips]..removeWhere((trip) => trip.id == tripId);
    if (next.length == _trips.length) return;
    setState(() {
      _trips = List.unmodifiable(next);
      _totals = _aggregate(next);
    });
  }

  CarTotals _aggregate(List<CarTripSummaryView> trips) {
    var loaded = 0;
    var returned = 0;
    var sold = 0;
    var returnedValue = 0;
    var gross = 0;
    var productDiscount = 0;
    var subtotalAfter = 0;
    var globalDiscount = 0;
    var finalValue = 0;
    var paid = 0;
    var remaining = 0;
    var open = 0;
    var closed = 0;
    var paidCount = 0;
    var partialCount = 0;
    var unpaidCount = 0;
    var overdueCount = 0;
    final now = DateTime.now();

    for (final trip in trips) {
      loaded += trip.totalLoadedCartons;
      returned += trip.totalReturnedCartons;
      sold += trip.totalSoldCartons;
      returnedValue += trip.totalReturnedValue.minorUnits;
      gross += trip.grossSubtotal.minorUnits;
      productDiscount += trip.productDiscountTotal.minorUnits;
      subtotalAfter += trip.subtotalAfterProducts.minorUnits;
      globalDiscount += trip.globalDiscountAmount.minorUnits;
      finalValue += trip.finalValue.minorUnits;
      paid += trip.paidTotal.minorUnits;
      remaining += trip.remaining.minorUnits;
      if (trip.status == CarTripStatus.open) {
        open++;
      } else {
        closed++;
      }
      switch (trip.paymentStatus(_evaluator, now)) {
        case CarPaymentStatus.paid:
          paidCount++;
        case CarPaymentStatus.partiallyPaid:
          partialCount++;
        case CarPaymentStatus.unpaid:
          unpaidCount++;
        case CarPaymentStatus.overdue:
          overdueCount++;
      }
    }

    return CarTotals(
      totalLoadedCartons: loaded,
      totalReturnedCartons: returned,
      totalSoldCartons: sold,
      totalReturnedValue: CarMoney(returnedValue),
      grossSubtotal: CarMoney(gross),
      productDiscountTotal: CarMoney(productDiscount),
      subtotalAfterProducts: CarMoney(subtotalAfter),
      globalDiscountAmount: CarMoney(globalDiscount),
      finalValue: CarMoney(finalValue),
      totalPaid: CarMoney(paid),
      totalRemaining: CarMoney(remaining),
      openCount: open,
      closedCount: closed,
      paidCount: paidCount,
      partiallyPaidCount: partialCount,
      unpaidCount: unpaidCount,
      overdueCount: overdueCount,
    );
  }

  String _money(int minor) => 'EGP ${(minor / 100).toStringAsFixed(2)}';

  String _date(DateTime value) {
    final d = value.toLocal();
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  ({StatusType type, String label}) _status(CarTripSummaryView trip) {
    switch (trip.paymentStatus(_evaluator, DateTime.now())) {
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

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
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

    final totals = _totals ?? _aggregate(_trips);
    final recent = _trips.take(6).toList(growable: false);
    final scheme = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Car dashboard', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CarTripEditorPage())),
                icon: const Icon(Icons.add_rounded),
                label: const Text('New trip'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('Today only · ${_date(_day)}', style: TextStyle(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [scheme.primary, scheme.primaryContainer],
              ),
              borderRadius: BorderRadius.circular(26),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('TODAY', style: TextStyle(color: scheme.onPrimary.withValues(alpha: .80), fontWeight: FontWeight.w900, letterSpacing: 1.4)),
                const SizedBox(height: 8),
                Text(_money(totals.finalValue.minorUnits), style: TextStyle(color: scheme.onPrimary, fontSize: 33, fontWeight: FontWeight.w900)),
                Text('Actual sold value', style: TextStyle(color: scheme.onPrimary.withValues(alpha: .82))),
                const SizedBox(height: 16),
                Row(children: [
                  _heroStat('Loaded', totals.totalLoadedCartons, scheme.onPrimary),
                  _heroStat('Returned', totals.totalReturnedCartons, scheme.onPrimary),
                  _heroStat('Sold', totals.totalSoldCartons, scheme.onPrimary),
                ]),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _metric('Trips', '${_trips.length}', Icons.route_rounded)),
            const SizedBox(width: 8),
            Expanded(child: _metric('Paid', _money(totals.totalPaid.minorUnits), Icons.payments_rounded)),
            const SizedBox(width: 8),
            Expanded(child: _metric('Due', _money(totals.totalRemaining.minorUnits), Icons.account_balance_wallet_outlined)),
          ]),
          const SizedBox(height: 12),
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Payment health', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              _statusLine('Paid', totals.paidCount, StatusType.success),
              _statusLine('Partial', totals.partiallyPaidCount, StatusType.warning),
              _statusLine('Unpaid', totals.unpaidCount, StatusType.neutral),
              _statusLine('Overdue', totals.overdueCount, StatusType.error),
            ]),
          ),
          const SizedBox(height: 18),
          Row(children: [
            const Expanded(child: Text('Today’s trips', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
            TextButton(onPressed: () => widget.onNavigate?.call(1), child: const Text('All trips')),
          ]),
          if (recent.isEmpty)
            const EmptyState(
              icon: Icons.local_shipping_outlined,
              title: 'No trips today',
              message: 'Create the first trip to start today’s dashboard.',
            )
          else
            for (final trip in recent) _tripCard(trip),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () => widget.onNavigate?.call(4),
            icon: const Icon(Icons.analytics_outlined),
            label: const Text('Overall Car reports'),
          ),
        ],
      ),
    );
  }

  Widget _heroStat(String label, int value, Color color) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$value', style: TextStyle(color: color, fontSize: 23, fontWeight: FontWeight.w900)),
            Text(label, style: TextStyle(color: color.withValues(alpha: .75), fontSize: 11, fontWeight: FontWeight.w700)),
          ],
        ),
      );

  Widget _metric(String label, String value, IconData icon) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: scheme.primary, size: 20),
        const SizedBox(height: 7),
        Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11)),
      ]),
    );
  }

  Widget _statusLine(String label, int value, StatusType type) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [Expanded(child: Text(label)), StatusBadge(type: type, label: '$value')]),
      );

  Widget _tripCard(CarTripSummaryView trip) {
    final scheme = Theme.of(context).colorScheme;
    final status = _status(trip);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CarTripDetailsPage(tripId: trip.id))),
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(16)),
            child: Icon(Icons.local_shipping_rounded, color: scheme.primary),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_date(trip.openedAt), style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 3),
              Text('${trip.salesCarName} · ${trip.warehouseName}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
              const SizedBox(height: 4),
              Text('${trip.totalLoadedCartons} loaded · ${trip.totalReturnedCartons} returned · ${trip.totalSoldCartons} sold', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11)),
            ]),
          ),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(_money(trip.finalValue.minorUnits), style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 5),
            StatusBadge(type: status.type, label: status.label),
          ]),
        ]),
      ),
    );
  }
}
