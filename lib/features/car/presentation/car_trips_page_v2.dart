import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/repositories/app_services.dart';
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

/// Operational Car trip list. Days stay grouped while individual trips can
/// be removed safely, including all payments attached to the deleted trip.
class CarTripsPageV2 extends StatefulWidget {
  const CarTripsPageV2({super.key});

  @override
  State<CarTripsPageV2> createState() => _CarTripsPageV2State();
}

class _CarTripsPageV2State extends State<CarTripsPageV2> {
  final _repository = AppServices.instance.carTripRepository;
  final _searchController = TextEditingController();
  final _evaluator = const CarPaymentEvaluator();

  late final StreamSubscription<CarTrip> _tripChanges;
  late final StreamSubscription<int> _tripDeletions;

  List<CarTripSummaryView> _trips = const [];
  _TripFilter _filter = _TripFilter.all;
  bool _loading = true;
  String? _error;
  int? _deletingTripId;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_load);
    _tripChanges = AppServices.instance.carTripEvents.stream.listen(_onTripChanged);
    _tripDeletions =
        AppServices.instance.carTripEvents.deletionStream.listen(_onTripDeleted);
    _load();
  }

  @override
  void dispose() {
    _tripChanges.cancel();
    _tripDeletions.cancel();
    _searchController.removeListener(_load);
    _searchController.dispose();
    super.dispose();
  }

  CarTripFilter _queryFilter() {
    final query = _searchController.text.trim();
    final status = switch (_filter) {
      _TripFilter.all => null,
      _TripFilter.open => CarTripStatus.open,
      _TripFilter.closed => CarTripStatus.closed,
    };
    return CarTripFilter(
      status: status,
      paymentStatus: switch (_filter) {
        _TripFilter.paid => CarPaymentStatus.paid,
        _TripFilter.partial => CarPaymentStatus.partiallyPaid,
        _TripFilter.unpaid => CarPaymentStatus.unpaid,
        _TripFilter.overdue => CarPaymentStatus.overdue,
        _ => null,
      },
      query: query.isEmpty ? null : query,
    );
  }

  Future<void> _load() async {
    if (_loading && _trips.isEmpty) {
      if (mounted) setState(() { _error = null; });
    }
    try {
      final trips = await _repository.getTripSummaries(filter: _queryFilter());
      if (!mounted) return;
      setState(() {
        _trips = List.unmodifiable(trips);
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$error';
      });
    }
  }

  void _onTripChanged(CarTrip trip) {
    if (!mounted || trip.id <= 0) return;
    final view = _toSummary(trip);
    final next = [..._trips]..removeWhere((item) => item.id == view.id);
    if (_matchesFilter(view)) next.add(view);
    next.sort((a, b) => b.openedAt.compareTo(a.openedAt));
    setState(() => _trips = List.unmodifiable(next));
  }

  void _onTripDeleted(int tripId) {
    if (!mounted) return;
    setState(() {
      _trips = List.unmodifiable(
        _trips.where((trip) => trip.id != tripId),
      );
    });
  }

  CarTripSummaryView _toSummary(CarTrip trip) {
    final summary = const CarCalculator().summary(trip);
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

  bool _matchesFilter(CarTripSummaryView trip) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty &&
        !trip.salesCarName.toLowerCase().contains(query) &&
        !trip.warehouseName.toLowerCase().contains(query) &&
        !trip.displayNumber.toLowerCase().contains(query)) {
      return false;
    }
    return switch (_filter) {
      _TripFilter.all => true,
      _TripFilter.open => trip.status == CarTripStatus.open,
      _TripFilter.closed => trip.status == CarTripStatus.closed,
      _TripFilter.paid => trip.paymentStatus(_evaluator, DateTime.now()) == CarPaymentStatus.paid,
      _TripFilter.partial => trip.paymentStatus(_evaluator, DateTime.now()) == CarPaymentStatus.partiallyPaid,
      _TripFilter.unpaid => trip.paymentStatus(_evaluator, DateTime.now()) == CarPaymentStatus.unpaid,
      _TripFilter.overdue => trip.paymentStatus(_evaluator, DateTime.now()) == CarPaymentStatus.overdue,
    };
  }

  Future<void> _deleteTrip(CarTripSummaryView trip) async {
    if (_deletingTripId != null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete trip?'),
        content: Text(
          'Delete ${_dayLabel(trip.openedAt)} for ${trip.salesCarName} · ${trip.warehouseName}? Any payment transaction linked to this trip will also be removed and any shared invoices will be recalculated.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deletingTripId = trip.id);
    try {
      final result = await _repository.deleteTrip(trip.id);
      AppServices.instance.carTripEvents.publishDeleted(
        tripId: result.deletedTripId,
        recalculatedTrips: result.recalculatedTrips,
        deletedPaymentTransactionIds: result.deletedPaymentTransactionIds,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.deletedPaymentTransactionIds.isEmpty
                ? 'Trip deleted.'
                : 'Trip and ${result.deletedPaymentTransactionIds.length} linked payment${result.deletedPaymentTransactionIds.length == 1 ? '' : 's'} deleted. Balances recalculated.',
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$error')),
        );
      }
    } finally {
      if (mounted) setState(() => _deletingTripId = null);
    }
  }

  String _dayKey(DateTime value) {
    final d = value.toLocal();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  String _dayLabel(DateTime value) {
    final d = value.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final formatted = '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    if (day == today) return 'Today · $formatted';
    if (day == today.subtract(const Duration(days: 1))) return 'Yesterday · $formatted';
    return formatted;
  }

  String _money(int minor) => 'EGP ${(minor / 100).toStringAsFixed(2)}';

  List<List<CarTripSummaryView>> _groups() {
    final map = <String, List<CarTripSummaryView>>{};
    for (final trip in _trips) {
      map.putIfAbsent(_dayKey(trip.openedAt), () => []).add(trip);
    }
    final groups = map.values.toList()
      ..sort((a, b) => b.first.openedAt.compareTo(a.first.openedAt));
    for (final group in groups) {
      group.sort((a, b) => b.openedAt.compareTo(a.openedAt));
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _trips.isEmpty) return const Center(child: CircularProgressIndicator());
    if (_error != null && _trips.isEmpty) {
      return Center(
        child: EmptyState(
          icon: Icons.error_outline_rounded,
          title: 'Unable to load trips',
          message: _error!,
          actionLabel: 'Retry',
          onAction: _load,
        ),
      );
    }

    final groups = _groups();
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: [
          Row(
            children: [
              const Expanded(child: Text('Car trips', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900))),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CarTripEditorPage())),
                icon: const Icon(Icons.add_rounded),
                label: const Text('New trip'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              hintText: 'Search car, warehouse or invoice',
              prefixIcon: Icon(Icons.search_rounded),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final filter in _TripFilter.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(filter.label),
                      selected: _filter == filter,
                      onSelected: (_) {
                        setState(() => _filter = filter);
                        _load();
                      },
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (groups.isEmpty)
            const EmptyState(
              icon: Icons.local_shipping_outlined,
              title: 'No trips found',
              message: 'Create a trip or adjust the current filter.',
            )
          else
            for (var index = 0; index < groups.length; index++)
              DaySummarySection(
                title: _dayLabel(groups[index].first.openedAt),
                summary: _daySummary(groups[index]),
                initiallyExpanded: index == 0,
                children: [for (final trip in groups[index]) _tripCard(trip)],
              ),
        ],
      ),
    );
  }

  String _daySummary(List<CarTripSummaryView> trips) {
    final loaded = trips.fold<int>(0, (sum, trip) => sum + trip.totalLoadedCartons);
    final returned = trips.fold<int>(0, (sum, trip) => sum + trip.totalReturnedCartons);
    final sold = trips.fold<int>(0, (sum, trip) => sum + trip.totalSoldCartons);
    final value = trips.fold<int>(0, (sum, trip) => sum + trip.finalValue.minorUnits);
    return '${trips.length} trip${trips.length == 1 ? '' : 's'} · $loaded loaded · $returned returned · $sold sold · ${_money(value)}';
  }

  Widget _tripCard(CarTripSummaryView trip) {
    final scheme = Theme.of(context).colorScheme;
    final status = _status(trip);
    final deleting = _deletingTripId == trip.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: const EdgeInsets.all(14),
        onTap: deleting ? null : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CarTripDetailsPage(tripId: trip.id))),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(16)),
              child: Icon(Icons.local_shipping_rounded, color: scheme.primary),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_dayLabel(trip.openedAt), style: const TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 3),
                  Text('${trip.salesCarName} · ${trip.warehouseName}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text('${trip.totalLoadedCartons} loaded · ${trip.totalReturnedCartons} returned · ${trip.totalSoldCartons} sold', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(_money(trip.finalValue.minorUnits), style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                StatusBadge(type: status.type, label: status.label),
                const SizedBox(height: 1),
                IconButton(
                  tooltip: 'Delete trip',
                  visualDensity: VisualDensity.compact,
                  onPressed: deleting ? null : () => _deleteTrip(trip),
                  icon: deleting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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
}

enum _TripFilter {
  all('All'),
  open('Open'),
  closed('Closed'),
  paid('Paid'),
  partial('Partial'),
  unpaid('Unpaid'),
  overdue('Overdue');

  const _TripFilter(this.label);
  final String label;
}
