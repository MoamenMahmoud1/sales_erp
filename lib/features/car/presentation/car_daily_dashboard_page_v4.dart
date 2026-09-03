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
import '../domain/services/car_payment_evaluator.dart';
import 'car_trip_details_page.dart';
import 'car_trip_editor_page.dart';

/// Today dashboard shows only finalized trips. A trip enters Today when its
/// closing/confirmation time falls on the selected calendar day.
class CarDailyDashboardPageV4 extends StatefulWidget {
  final ValueChanged<int>? onNavigate;

  const CarDailyDashboardPageV4({super.key, this.onNavigate});

  @override
  State<CarDailyDashboardPageV4> createState() =>
      _CarDailyDashboardPageV4State();
}

class _CarDailyDashboardPageV4State extends State<CarDailyDashboardPageV4>
    with WidgetsBindingObserver {
  final _repository = AppServices.instance.carTripRepository;
  final _evaluator = const CarPaymentEvaluator();

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
    _tripChanges =
        AppServices.instance.carTripEvents.stream.listen(_onTripChanged);
    _tripDeletions = AppServices.instance.carTripEvents.deletionStream
        .listen(_onTripDeleted);
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

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      // Date filtering is based on confirmation/closing time, not draft
      // creation/opening time. Drafts are excluded at the repository level.
      final allConfirmed = await _repository.getTripSummaries(
        filter: const CarTripFilter(status: CarTripStatus.closed),
      );
      final today = allConfirmed.where((trip) {
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
      setState(() {
        _loading = false;
        _error = '$error';
      });
    }
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  void _onTripChanged(CarTrip trip) {
    if (!mounted || trip.id <= 0) return;

    final next = [..._trips]..removeWhere((item) => item.id == trip.id);
    final confirmedAt = trip.closedAt?.toLocal();
    if (trip.isClosed &&
        confirmedAt != null &&
        _sameDay(confirmedAt, _day)) {
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
    final items = trip.items;
    var loaded = 0;
    var returned = 0;
    var sold = 0;
    var returnedValue = 0;
    var gross = 0;
    var productDiscount = 0;
    var subtotalAfter = 0;
    var finalValue = 0;

    for (final item in items) {
      final soldCount = item.loadedCartons - item.returnedCartons;
      final buyingGross = item.purchasePrice.minorUnits * soldCount;
      final discount = (buyingGross * item.discountPercent / 100).round();
      loaded += item.loadedCartons;
      returned += item.returnedCartons;
      sold += soldCount;
      returnedValue += item.sellingPrice.minorUnits * item.returnedCartons;
      gross += item.sellingPrice.minorUnits * soldCount;
      productDiscount += discount;
      subtotalAfter += buyingGross - discount;
    }

    final globalPercent =
        (subtotalAfter * trip.globalDiscountPercent / 100).round();
    final globalFixed = trip.globalDiscountEgp.minorUnits.clamp(
      0,
      subtotalAfter - globalPercent < 0
          ? 0
          : subtotalAfter - globalPercent,
    );
    finalValue = gross;

    return CarTripSummaryView(
      id: trip.id,
      displayNumber: trip.displayNumber,
      salesCarName: trip.salesCarName,
      warehouseName: trip.warehouseName,
      openedAt: trip.openedAt,
      closedAt: trip.closedAt,
      dueDate: trip.dueDate,
      status: trip.status,
      totalLoadedCartons: loaded,
      totalReturnedCartons: returned,
      totalSoldCartons: sold,
      totalReturnedValue: CarMoney(returnedValue),
      grossSubtotal: CarMoney(gross),
      productDiscountTotal: CarMoney(productDiscount),
      subtotalAfterProducts: CarMoney(subtotalAfter),
      globalDiscountAmount: CarMoney(globalPercent + globalFixed),
      finalValue: CarMoney(finalValue),
      paidCash: trip.payment.cashAmount,
      paidTransfer: trip.payment.transferAmount,
    );
  }

  ({StatusType type, String label}) _paymentStatus(
    CarTripSummaryView trip,
  ) {
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

  int get _soldValue =>
      _trips.fold(0, (sum, trip) => sum + trip.finalValue.minorUnits);

  int get _paidValue =>
      _trips.fold(0, (sum, trip) => sum + trip.paidTotal.minorUnits);

  int get _outstandingValue =>
      _trips.fold(0, (sum, trip) => sum + trip.remaining.minorUnits);

  int get _loaded =>
      _trips.fold(0, (sum, trip) => sum + trip.totalLoadedCartons);

  int get _returned =>
      _trips.fold(0, (sum, trip) => sum + trip.totalReturnedCartons);

  int get _sold =>
      _trips.fold(0, (sum, trip) => sum + trip.totalSoldCartons);

  String _money(int minor) => 'EGP ${(minor / 100).toStringAsFixed(2)}';

  String _date(DateTime value) {
    final d = value.toLocal();
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

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
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Car dashboard',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                ),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CarTripEditorPage()),
                ),
                icon: const Icon(Icons.add_rounded),
                label: const Text('New trip'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Confirmed today · ${_date(_day)}',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
          _summaryCard(
            title: 'Confirmed sales',
            value: _money(_soldValue),
            subtitle: '${_trips.length} finalized trip${_trips.length == 1 ? '' : 's'}',
            icon: Icons.verified_rounded,
            background: scheme.primaryContainer,
            foreground: scheme.onPrimaryContainer,
          ),
          const SizedBox(height: 10),
          _metricGrid(),
          const SizedBox(height: 18),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Confirmed trips',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
              ),
              TextButton(
                onPressed: () => widget.onNavigate?.call(1),
                child: const Text('All trips'),
              ),
            ],
          ),
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

  Widget _summaryCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color background,
    required Color foreground,
  }) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, color: foreground, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: foreground.withValues(alpha: .76),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: TextStyle(
                      color: foreground,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(color: foreground.withValues(alpha: .70), fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _metric(width, 'Trips', '${_trips.length}', Icons.route_rounded),
            _metric(width, 'Loaded', '$_loaded', Icons.outbox_rounded),
            _metric(width, 'Returned', '$_returned', Icons.assignment_return_rounded),
            _metric(width, 'Sold', '$_sold', Icons.point_of_sale_rounded),
            _metric(width, 'Paid', _money(_paidValue), Icons.payments_rounded),
            _metric(
              width,
              'Outstanding',
              _money(_outstandingValue),
              Icons.account_balance_wallet_outlined,
            ),
          ],
        );
      },
    );
  }

  Widget _metric(double width, String label, String value, IconData icon) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: width,
      child: AppCard(
        padding: const EdgeInsets.all(13),
        child: Row(
          children: [
            Icon(icon, size: 20, color: scheme.primary),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 10.5, color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tripCard(CarTripSummaryView trip) {
    final scheme = Theme.of(context).colorScheme;
    final payment = _paymentStatus(trip);
    final confirmedAt = trip.closedAt ?? trip.openedAt;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: const EdgeInsets.all(14),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => CarTripDetailsPage(tripId: trip.id)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.verified_rounded, color: scheme.primary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trip.displayNumber,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${trip.salesCarName} · ${trip.warehouseName}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                StatusBadge(type: payment.type, label: payment.label),
              ],
            ),
            const SizedBox(height: 11),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                _dataPill('Confirmed', _date(confirmedAt), scheme.primaryContainer),
                _dataPill('Loaded', '${trip.totalLoadedCartons}', scheme.surfaceContainerHighest),
                _dataPill('Returned', '${trip.totalReturnedCartons}', scheme.surfaceContainerHighest),
                _dataPill('Sold', '${trip.totalSoldCartons}', scheme.surfaceContainerHighest),
                _dataPill('Total', _money(trip.finalValue.minorUnits), scheme.surfaceContainerHighest),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _dataPill(String label, String value, Color background) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: RichText(
        text: TextSpan(
          style: TextStyle(color: scheme.onSurface, fontSize: 10.5),
          children: [
            TextSpan(
              text: '$label  ',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }
}
