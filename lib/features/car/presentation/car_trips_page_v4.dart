import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/repositories/app_services.dart';
import '../../../core/ui/app_card.dart';
import '../../../core/ui/day_summary_section.dart';
import '../../../core/ui/empty_state.dart';
import '../../../core/ui/status_badge.dart';
import '../application/usecases/confirm_car_trip.dart';
import '../domain/entities/car_payment_status.dart';
import '../domain/entities/car_trip.dart';
import '../domain/entities/car_trip_filter.dart';
import '../domain/entities/car_trip_status.dart';
import '../domain/entities/car_trip_summary_view.dart';
import '../domain/services/car_calculator.dart';
import '../domain/services/car_payment_evaluator.dart';
import 'car_trip_details_page.dart';
import 'car_trip_editor_page.dart';

class CarTripsPageV4 extends StatefulWidget {
  const CarTripsPageV4({super.key});

  @override
  State<CarTripsPageV4> createState() => _CarTripsPageV4State();
}

class _CarTripsPageV4State extends State<CarTripsPageV4> {
  final _repository = AppServices.instance.carTripRepository;
  final _searchController = TextEditingController();
  final _calculator = const CarCalculator();
  final _evaluator = const CarPaymentEvaluator();
  late final ConfirmCarTrip _confirm = ConfirmCarTrip(_repository);

  late final StreamSubscription<CarTrip> _tripChanges;
  late final StreamSubscription<int> _tripDeletions;

  List<CarTripSummaryView> _trips = const [];
  _TripFilter _filter = _TripFilter.all;
  bool _loading = true;
  String? _error;
  int? _deletingTripId;
  int? _confirmingTripId;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_refresh);
    _tripChanges = AppServices.instance.carTripEvents.stream.listen(_onTripChanged);
    _tripDeletions = AppServices.instance.carTripEvents.deletionStream.listen(_onTripDeleted);
    _refresh();
  }

  @override
  void dispose() {
    _tripChanges.cancel();
    _tripDeletions.cancel();
    _searchController.removeListener(_refresh);
    _searchController.dispose();
    super.dispose();
  }

  CarTripFilter _query() {
    final text = _searchController.text.trim();
    final query = text.isEmpty ? null : text;
    switch (_filter) {
      case _TripFilter.all:
        return CarTripFilter(query: query);
      case _TripFilter.drafts:
        return CarTripFilter(status: CarTripStatus.open, query: query);
      case _TripFilter.confirmed:
        return CarTripFilter(status: CarTripStatus.closed, query: query);
      case _TripFilter.paid:
        return CarTripFilter(paymentStatus: CarPaymentStatus.paid, query: query);
      case _TripFilter.partial:
        return CarTripFilter(paymentStatus: CarPaymentStatus.partiallyPaid, query: query);
      case _TripFilter.unpaid:
        return CarTripFilter(paymentStatus: CarPaymentStatus.unpaid, query: query);
      case _TripFilter.overdue:
        return CarTripFilter(paymentStatus: CarPaymentStatus.overdue, query: query);
    }
  }

  Future<void> _refresh() async {
    try {
      final trips = await _repository.getTripSummaries(filter: _query());
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

  CarTripSummaryView _project(CarTrip trip) {
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
    final view = _project(trip);
    final next = [..._trips]..removeWhere((item) => item.id == trip.id);
    if (_matches(view)) next.add(view);
    next.sort((a, b) => b.openedAt.compareTo(a.openedAt));
    setState(() => _trips = List.unmodifiable(next));
  }

  void _onTripDeleted(int id) {
    if (!mounted) return;
    final next = [..._trips]..removeWhere((trip) => trip.id == id);
    if (next.length != _trips.length) {
      setState(() => _trips = List.unmodifiable(next));
    }
  }

  bool _matches(CarTripSummaryView trip) {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isNotEmpty &&
        !trip.displayNumber.toLowerCase().contains(q) &&
        !trip.salesCarName.toLowerCase().contains(q) &&
        !trip.warehouseName.toLowerCase().contains(q)) {
      return false;
    }
    final status = trip.paymentStatus(_evaluator, DateTime.now());
    switch (_filter) {
      case _TripFilter.all:
        return true;
      case _TripFilter.drafts:
        return trip.status == CarTripStatus.open;
      case _TripFilter.confirmed:
        return trip.status == CarTripStatus.closed;
      case _TripFilter.paid:
        return status == CarPaymentStatus.paid;
      case _TripFilter.partial:
        return status == CarPaymentStatus.partiallyPaid;
      case _TripFilter.unpaid:
        return status == CarPaymentStatus.unpaid;
      case _TripFilter.overdue:
        return status == CarPaymentStatus.overdue;
    }
  }

  Future<void> _confirmDraft(CarTripSummaryView summary) async {
    if (_confirmingTripId != null || summary.status != CarTripStatus.open) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm draft?'),
        content: Text(
          'Confirm ${summary.displayNumber} for ${summary.salesCarName}? This will finalize the Car trip and it will no longer be a draft.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _confirmingTripId = summary.id);
    try {
      final draft = await _repository.getTripById(summary.id);
      if (draft == null) throw StateError('Draft was not found.');
      final persisted = await _confirm(draft, triggeredBy: 'draft_confirm');
      AppServices.instance.carTripEvents.publish(persisted);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${persisted.displayNumber} confirmed successfully.')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _confirmingTripId = null);
    }
  }

  Future<void> _deleteTrip(CarTripSummaryView trip) async {
    if (_deletingTripId != null || _confirmingTripId != null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete trip?'),
        content: Text(
          'Delete ${_dayLabel(trip.openedAt)} for ${trip.salesCarName} · ${trip.warehouseName}? Linked payments will also be removed and shared balances recalculated.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton.tonal(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
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
      final count = result.deletedPaymentTransactionIds.length;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            count == 0 ? 'Trip deleted.' : 'Trip deleted with $count linked payment${count == 1 ? '' : 's'}. Balances recalculated.',
          ),
        ),
      );
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
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
    final grouped = <String, List<CarTripSummaryView>>{};
    for (final trip in _trips) {
      grouped.putIfAbsent(_dayKey(trip.openedAt), () => []).add(trip);
    }
    final groups = grouped.values.toList()..sort((a, b) => b.first.openedAt.compareTo(a.first.openedAt));
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
          onAction: _refresh,
        ),
      );
    }

    final groups = _groups();
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: [
          Row(
            children: [
              const Expanded(child: Text('Car trips', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900))),
              FilledButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CarTripEditorPage())),
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
                        _refresh();
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
            for (var i = 0; i < groups.length; i++)
              DaySummarySection(
                title: _dayLabel(groups[i].first.openedAt),
                summary: _daySummary(groups[i]),
                initiallyExpanded: i == 0,
                children: [for (final trip in groups[i]) _tripCard(trip)],
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
    final drafts = trips.where((trip) => trip.status == CarTripStatus.open).length;
    final suffix = drafts == 0 ? '' : ' · $drafts draft${drafts == 1 ? '' : 's'}';
    return '${trips.length} trip${trips.length == 1 ? '' : 's'}$suffix · $loaded loaded · $returned returned · $sold sold · ${_money(value)}';
  }

  Widget _tripCard(CarTripSummaryView trip) {
    final scheme = Theme.of(context).colorScheme;
    final isDraft = trip.status == CarTripStatus.open;
    final status = trip.paymentStatus(_evaluator, DateTime.now());
    final deleting = _deletingTripId == trip.id;
    final confirming = _confirmingTripId == trip.id;
    final paymentBadge = switch (status) {
      CarPaymentStatus.paid => (StatusType.success, 'Paid'),
      CarPaymentStatus.partiallyPaid => (StatusType.warning, 'Partial'),
      CarPaymentStatus.unpaid => (StatusType.neutral, 'Unpaid'),
      CarPaymentStatus.overdue => (StatusType.error, 'Overdue'),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: const EdgeInsets.all(14),
        onTap: deleting || confirming ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => CarTripDetailsPage(tripId: trip.id))),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(16)),
              child: Icon(Icons.local_shipping_rounded, color: scheme.primary),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_dayLabel(trip.openedAt), style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text('${trip.salesCarName} · ${trip.warehouseName}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
                const SizedBox(height: 4),
                Text('${trip.totalLoadedCartons} loaded · ${trip.totalReturnedCartons} returned · ${trip.totalSoldCartons} sold', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11)),
              ]),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(_money(trip.finalValue.minorUnits), style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                StatusBadge(
                  type: isDraft ? StatusType.warning : paymentBadge.$1,
                  label: isDraft ? 'Draft' : paymentBadge.$2,
                ),
                if (isDraft) ...[
                  const SizedBox(height: 2),
                  TextButton.icon(
                    onPressed: confirming || _confirmingTripId != null || _deletingTripId != null
                        ? null
                        : () => _confirmDraft(trip),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 7),
                    ),
                    icon: confirming
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.check_circle_outline_rounded, size: 17),
                    label: Text(confirming ? 'Confirming' : 'Confirm'),
                  ),
                ],
                IconButton(
                  tooltip: 'Delete trip',
                  visualDensity: VisualDensity.compact,
                  onPressed: deleting || confirming ? null : () => _deleteTrip(trip),
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
}

enum _TripFilter {
  all('All'),
  drafts('Drafts'),
  confirmed('Confirmed'),
  paid('Paid'),
  partial('Partial'),
  unpaid('Unpaid'),
  overdue('Overdue');

  const _TripFilter(this.label);
  final String label;
}
