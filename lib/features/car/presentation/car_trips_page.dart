import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/repositories/app_services.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/app_card.dart';
import '../../../core/ui/day_summary_section.dart';
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

class CarTripsPage extends StatefulWidget {
  const CarTripsPage({super.key});

  @override
  State<CarTripsPage> createState() => _CarTripsPageState();
}

class _CarTripsPageState extends State<CarTripsPage> {
  final _repository = AppServices.instance.carTripRepository;
  final _searchController = TextEditingController();
  final _calculator = const CarCalculator();
  final _evaluator = const CarPaymentEvaluator();

  late final StreamSubscription<CarTrip> _tripChanges;

  List<CarTripSummaryView> _trips = const [];
  _TripFilterTab _tab = _TripFilterTab.all;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_search);
    _tripChanges =
        AppServices.instance.carTripEvents.stream.listen(_onTripChanged);
    _load();
  }

  @override
  void dispose() {
    _tripChanges.cancel();
    _searchController.removeListener(_search);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final trips = await _repository.getTripSummaries(filter: _buildFilter());
      if (!mounted) return;
      setState(() { _trips = trips; _loading = false; });
    } catch (error) {
      if (!mounted) return;
      setState(() { _loading = false; _error = '$error'; });
    }
  }

  void _onTripChanged(CarTrip trip) {
    if (!mounted || trip.id <= 0) return;
    final view = _toSummaryView(trip);
    final next = [..._trips]..removeWhere((item) => item.id == view.id);
    if (_matchesCurrentFilter(view)) next.add(view);
    next.sort((a, b) => b.openedAt.compareTo(a.openedAt));
    setState(() => _trips = List.unmodifiable(next));
  }

  CarTripSummaryView _toSummaryView(CarTrip trip) {
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

  bool _matchesCurrentFilter(CarTripSummaryView view) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty &&
        !view.displayNumber.toLowerCase().contains(query) &&
        !view.salesCarName.toLowerCase().contains(query) &&
        !view.warehouseName.toLowerCase().contains(query)) {
      return false;
    }

    return switch (_tab) {
      _TripFilterTab.all => true,
      _TripFilterTab.open => view.status == CarTripStatus.open,
      _TripFilterTab.closed => view.status == CarTripStatus.closed,
      _TripFilterTab.paid =>
        view.paymentStatus(_evaluator, DateTime.now()) == CarPaymentStatus.paid,
      _TripFilterTab.partial =>
        view.paymentStatus(_evaluator, DateTime.now()) ==
            CarPaymentStatus.partiallyPaid,
      _TripFilterTab.unpaid =>
        view.paymentStatus(_evaluator, DateTime.now()) == CarPaymentStatus.unpaid,
      _TripFilterTab.overdue =>
        view.paymentStatus(_evaluator, DateTime.now()) == CarPaymentStatus.overdue,
    };
  }

  Future<void> _search() async {
    if (_loading) return;
    await _load();
  }

  CarTripFilter _buildFilter() {
    final query = _searchController.text.trim();
    switch (_tab) {
      case _TripFilterTab.all:
        return CarTripFilter(query: query.isEmpty ? null : query);
      case _TripFilterTab.open:
        return CarTripFilter(
          status: CarTripStatus.open,
          query: query.isEmpty ? null : query,
        );
      case _TripFilterTab.closed:
        return CarTripFilter(
          status: CarTripStatus.closed,
          query: query.isEmpty ? null : query,
        );
      case _TripFilterTab.paid:
        return CarTripFilter(
          paymentStatus: CarPaymentStatus.paid,
          query: query.isEmpty ? null : query,
        );
      case _TripFilterTab.partial:
        return CarTripFilter(
          paymentStatus: CarPaymentStatus.partiallyPaid,
          query: query.isEmpty ? null : query,
        );
      case _TripFilterTab.unpaid:
        return CarTripFilter(
          paymentStatus: CarPaymentStatus.unpaid,
          query: query.isEmpty ? null : query,
        );
      case _TripFilterTab.overdue:
        return CarTripFilter(
          paymentStatus: CarPaymentStatus.overdue,
          query: query.isEmpty ? null : query,
        );
    }
  }

  Future<void> _newTrip() async {
    // Saved/confirmed trips are published by the editor; cancel emits nothing.
    // No post-navigation DB read is needed.
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CarTripEditorPage()),
    );
  }

  Future<void> _openTrip(CarTripSummaryView trip) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CarTripDetailsPage(tripId: trip.id)),
    );
  }

  String _money(int minor) => 'EGP ${(minor / 100).toStringAsFixed(2)}';

  ({StatusType type, String label}) _status(CarTripSummaryView trip) {
    if (trip.remaining.minorUnits == 0) {
      return (type: StatusType.success, label: 'Paid');
    }
    if (trip.dueDate != null && DateTime.now().isAfter(trip.dueDate!)) {
      return (type: StatusType.error, label: 'Overdue');
    }
    if (trip.paidTotal.minorUnits > 0) {
      return (type: StatusType.warning, label: 'Partially paid');
    }
    return (type: StatusType.neutral, label: 'Unpaid');
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
    final formatted = _formatDate(local);
    if (day == today) return 'Today · $formatted';
    if (day == today.subtract(const Duration(days: 1))) {
      return 'Yesterday · $formatted';
    }
    return formatted;
  }

  List<List<CarTripSummaryView>> _groupTripsByDay() {
    final groups = <String, List<CarTripSummaryView>>{};
    for (final trip in _trips) {
      groups.putIfAbsent(_dayKey(trip.openedAt), () => []).add(trip);
    }
    final ordered = groups.values.toList()
      ..sort((a, b) => b.first.openedAt.compareTo(a.first.openedAt));
    for (final group in ordered) {
      group.sort((a, b) => b.openedAt.compareTo(a.openedAt));
    }
    return ordered;
  }

  Widget _daySection(
    List<CarTripSummaryView> trips, {
    required bool initiallyExpanded,
  }) {
    final day = trips.first.openedAt.toLocal();
    final loaded = trips.fold<int>(
      0,
      (sum, trip) => sum + trip.totalLoadedCartons,
    );
    final returned = trips.fold<int>(
      0,
      (sum, trip) => sum + trip.totalReturnedCartons,
    );
    final sold = trips.fold<int>(0, (sum, trip) => sum + trip.totalSoldCartons);
    final value = trips.fold<int>(
      0,
      (sum, trip) => sum + trip.finalValue.minorUnits,
    );

    return DaySummarySection(
      title: _dayTitle(day),
      summary:
          '${trips.length} trip${trips.length == 1 ? '' : 's'} · $loaded loaded · $returned returned · $sold sold · ${_money(value)}',
      initiallyExpanded: initiallyExpanded,
      children: [
        for (final trip in trips) _buildTripCard(trip),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Car trips',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                  ),
                ),
                FilledButton.icon(
                  onPressed: _newTrip,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('New trip'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search car or warehouse',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () => _searchController.clear(),
                        icon: const Icon(Icons.clear_rounded),
                      ),
                border: OutlineInputBorder(borderRadius: AppRadius.xlAll),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 42,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final tab in _TripFilterTab.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(tab.label),
                        selected: _tab == tab,
                        onSelected: (_) {
                          setState(() => _tab = tab);
                          _load();
                        },
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              EmptyState(
                icon: Icons.error_outline_rounded,
                title: 'Unable to load Car trips',
                message: _error!,
                actionLabel: 'Retry',
                onAction: _load,
              )
            else if (_trips.isEmpty)
              const EmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'No Car trips found',
                message: 'Create a trip or change the current filters.',
              )
            else
              for (var index = 0; index < _groupTripsByDay().length; index++)
                _daySection(
                  _groupTripsByDay()[index],
                  initiallyExpanded: index == 0,
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildTripCard(CarTripSummaryView trip) {
    final status = _status(trip);
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        onTap: () => _openTrip(trip),
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(17),
              ),
              child: Icon(Icons.local_shipping_rounded, color: scheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatDate(trip.openedAt),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${trip.salesCarName} · ${trip.warehouseName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 6,
                    runSpacing: 3,
                    children: [
                      Text(
                        '${trip.totalLoadedCartons} loaded',
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                      Text(
                        '${trip.totalReturnedCartons} returned',
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                      Text(
                        '${trip.totalSoldCartons} sold',
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _money(trip.finalValue.minorUnits),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 5),
                StatusBadge(type: status.type, label: status.label),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime value) {
    final date = value.toLocal();
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}

enum _TripFilterTab {
  all('All'),
  open('Open'),
  closed('Closed'),
  paid('Paid'),
  partial('Partial'),
  unpaid('Unpaid'),
  overdue('Overdue');

  const _TripFilterTab(this.label);
  final String label;
}
