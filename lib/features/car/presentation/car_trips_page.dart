import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/repositories/app_services.dart';
import '../../../core/ui/day_summary_section.dart';
import '../../../core/ui/empty_state.dart';
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
import 'car_trip_list_tile.dart';

class CarTripsPage extends StatefulWidget {
  const CarTripsPage({super.key});

  @override
  State<CarTripsPage> createState() => _CarTripsPageState();
}

class _CarTripsPageState extends State<CarTripsPage> {
  final _repository = AppServices.instance.carTripRepository;
  final _searchController = TextEditingController();
  final _calculator = const CarCalculator();
  final _paymentEvaluator = const CarPaymentEvaluator();
  late final ConfirmCarTrip _confirmCarTrip = ConfirmCarTrip(_repository);

  late final StreamSubscription<CarTrip> _tripChangesSubscription;
  late final StreamSubscription<int> _tripDeletionsSubscription;

  List<CarTripSummaryView> _trips = const [];
  TripListFilter _filter = TripListFilter.all;
  bool _loading = true;
  String? _error;
  int? _deletingTripId;
  int? _confirmingTripId;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_refresh);
    _tripChangesSubscription =
        AppServices.instance.carTripEvents.stream.listen(_onTripChanged);
    _tripDeletionsSubscription = AppServices.instance.carTripEvents.deletionStream
        .listen(_onTripDeleted);
    _refresh();
  }

  @override
  void dispose() {
    _tripChangesSubscription.cancel();
    _tripDeletionsSubscription.cancel();
    _searchController.removeListener(_refresh);
    _searchController.dispose();
    super.dispose();
  }

  CarTripFilter _buildFilter() {
    final text = _searchController.text.trim();
    final query = text.isEmpty ? null : text;

    return switch (_filter) {
      TripListFilter.all => CarTripFilter(query: query),
      TripListFilter.drafts =>
        CarTripFilter(status: CarTripStatus.open, query: query),
      TripListFilter.confirmed =>
        CarTripFilter(status: CarTripStatus.closed, query: query),
      TripListFilter.paid =>
        CarTripFilter(paymentStatus: CarPaymentStatus.paid, query: query),
      TripListFilter.partial => CarTripFilter(
          paymentStatus: CarPaymentStatus.partiallyPaid,
          query: query,
        ),
      TripListFilter.unpaid =>
        CarTripFilter(paymentStatus: CarPaymentStatus.unpaid, query: query),
      TripListFilter.overdue =>
        CarTripFilter(paymentStatus: CarPaymentStatus.overdue, query: query),
    };
  }

  Future<void> _refresh() async {
    final generation = ++_loadGeneration;

    try {
      final trips = await _repository.getTripSummaries(filter: _buildFilter());
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _trips = List.unmodifiable(trips);
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _loading = false;
        _error = '$error';
      });
    }
  }

  CarTripSummaryView _toSummary(CarTrip trip) {
    final totals = _calculator.summary(trip);
    return CarTripSummaryView(
      id: trip.id,
      displayNumber: trip.displayNumber,
      salesCarName: trip.salesCarName,
      warehouseName: trip.warehouseName,
      openedAt: trip.openedAt,
      closedAt: trip.closedAt,
      dueDate: trip.dueDate,
      status: trip.status,
      totalLoadedCartons: totals.totalLoadedCartons,
      totalReturnedCartons: totals.totalReturnedCartons,
      totalSoldCartons: totals.totalSoldCartons,
      totalReturnedValue: totals.totalReturnedValue,
      grossSubtotal: totals.grossSubtotal,
      productDiscountTotal: totals.productDiscountTotal,
      subtotalAfterProducts: totals.subtotalAfterProducts,
      globalDiscountAmount: totals.globalDiscountAmount,
      finalValue: totals.finalTotalSoldValue,
      paidCash: trip.payment.cashAmount,
      paidTransfer: trip.payment.transferAmount,
    );
  }

  void _onTripChanged(CarTrip trip) {
    if (!mounted || trip.id <= 0) return;

    final summary = _toSummary(trip);
    final nextTrips = [..._trips]..removeWhere((item) => item.id == trip.id);
    if (_matchesCurrentFilter(summary)) nextTrips.add(summary);
    nextTrips.sort((a, b) => b.openedAt.compareTo(a.openedAt));

    setState(() => _trips = List.unmodifiable(nextTrips));
  }

  void _onTripDeleted(int id) {
    if (!mounted) return;
    final nextTrips = [..._trips]..removeWhere((trip) => trip.id == id);
    if (nextTrips.length != _trips.length) {
      setState(() => _trips = List.unmodifiable(nextTrips));
    }
  }

  bool _matchesCurrentFilter(CarTripSummaryView trip) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty &&
        !trip.displayNumber.toLowerCase().contains(query) &&
        !trip.salesCarName.toLowerCase().contains(query) &&
        !trip.warehouseName.toLowerCase().contains(query)) {
      return false;
    }

    final paymentStatus = trip.paymentStatus(_paymentEvaluator, DateTime.now());
    return switch (_filter) {
      TripListFilter.all => true,
      TripListFilter.drafts => trip.status == CarTripStatus.open,
      TripListFilter.confirmed => trip.status == CarTripStatus.closed,
      TripListFilter.paid => paymentStatus == CarPaymentStatus.paid,
      TripListFilter.partial =>
        paymentStatus == CarPaymentStatus.partiallyPaid,
      TripListFilter.unpaid => paymentStatus == CarPaymentStatus.unpaid,
      TripListFilter.overdue => paymentStatus == CarPaymentStatus.overdue,
    };
  }

  Future<void> _confirmDraft(CarTripSummaryView summary) async {
    if (_confirmingTripId != null || summary.status != CarTripStatus.open) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm draft?'),
        content: Text(
          'Confirm ${summary.displayNumber} for ${summary.salesCarName}? '
          'This will finalize the trip and it will no longer be a draft.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _confirmingTripId = summary.id);
    try {
      final draft = await _repository.getTripById(summary.id);
      if (draft == null) throw StateError('Draft was not found.');

      final persisted = await _confirmCarTrip(
        draft,
        triggeredBy: 'draft_confirm',
      );
      AppServices.instance.carTripEvents.publish(persisted);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${persisted.displayNumber} confirmed successfully.')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$error')),
        );
      }
    } finally {
      if (mounted) setState(() => _confirmingTripId = null);
    }
  }

  Future<void> _deleteTrip(CarTripSummaryView trip) async {
    if (_deletingTripId != null || _confirmingTripId != null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete trip?'),
        content: Text(
          'Delete ${_dayLabel(trip.openedAt)} for ${trip.salesCarName} · '
          '${trip.warehouseName}? Linked payments will also be removed and '
          'shared balances recalculated.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(dialogContext, true),
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
      final paymentCount = result.deletedPaymentTransactionIds.length;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            paymentCount == 0
                ? 'Trip deleted.'
                : 'Trip deleted with $paymentCount linked payment${paymentCount == 1 ? '' : 's'}. Balances recalculated.',
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
    final local = value.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }

  String _dayLabel(DateTime value) {
    final local = value.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);
    final formatted =
        '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';

    if (day == today) return 'Today · $formatted';
    if (day == today.subtract(const Duration(days: 1))) {
      return 'Yesterday · $formatted';
    }
    return formatted;
  }

  String _money(int minorUnits) =>
      'EGP ${(minorUnits / 100).toStringAsFixed(2)}';

  List<List<CarTripSummaryView>> _groupedTrips() {
    final grouped = <String, List<CarTripSummaryView>>{};
    for (final trip in _trips) {
      grouped.putIfAbsent(_dayKey(trip.openedAt), () => []).add(trip);
    }

    final groups = grouped.values.toList()
      ..sort((a, b) => b.first.openedAt.compareTo(a.first.openedAt));
    for (final group in groups) {
      group.sort((a, b) => b.openedAt.compareTo(a.openedAt));
    }
    return groups;
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
          title: 'Unable to load trips',
          message: _error!,
          actionLabel: 'Retry',
          onAction: _refresh,
        ),
      );
    }

    final groups = _groupedTrips();
    return RefreshIndicator(
      onRefresh: _refresh,
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
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CarTripEditorPage(),
                  ),
                ),
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
                for (final filter in TripListFilter.values)
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
            for (var index = 0; index < groups.length; index++)
              DaySummarySection(
                title: _dayLabel(groups[index].first.openedAt),
                summary: _daySummary(groups[index]),
                initiallyExpanded: index == 0,
                children: [
                  for (final trip in groups[index])
                    CarTripListTile(
                      trip: trip,
                      paymentEvaluator: _paymentEvaluator,
                      deleting: _deletingTripId == trip.id,
                      confirming: _confirmingTripId == trip.id,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CarTripDetailsPage(tripId: trip.id),
                        ),
                      ),
                      onConfirm: () => _confirmDraft(trip),
                      onDelete: () => _deleteTrip(trip),
                    ),
                ],
              ),
        ],
      ),
    );
  }

  String _daySummary(List<CarTripSummaryView> trips) {
    final loaded = trips.fold<int>(
      0,
      (sum, trip) => sum + trip.totalLoadedCartons,
    );
    final returned = trips.fold<int>(
      0,
      (sum, trip) => sum + trip.totalReturnedCartons,
    );
    final sold = trips.fold<int>(
      0,
      (sum, trip) => sum + trip.totalSoldCartons,
    );
    final value = trips.fold<int>(
      0,
      (sum, trip) => sum + trip.finalValue.minorUnits,
    );
    final drafts =
        trips.where((trip) => trip.status == CarTripStatus.open).length;
    final draftSuffix = drafts == 0
        ? ''
        : ' · $drafts draft${drafts == 1 ? '' : 's'}';

    return '${trips.length} trip${trips.length == 1 ? '' : 's'}$draftSuffix · '
        '$loaded loaded · $returned returned · $sold sold · ${_money(value)}';
  }
}

enum TripListFilter {
  all('All'),
  drafts('Drafts'),
  confirmed('Confirmed'),
  paid('Paid'),
  partial('Partial'),
  unpaid('Unpaid'),
  overdue('Overdue');

  const TripListFilter(this.label);

  final String label;
}
