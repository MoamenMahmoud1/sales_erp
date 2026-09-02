import 'package:flutter/material.dart';

import '../../../core/repositories/app_services.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/app_card.dart';
import '../../../core/ui/empty_state.dart';
import '../../../core/ui/status_badge.dart';
import '../domain/entities/car_payment_status.dart';
import '../domain/entities/car_trip_filter.dart';
import '../domain/entities/car_trip_status.dart';
import '../domain/entities/car_trip_summary_view.dart';
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

  List<CarTripSummaryView> _trips = const [];
  _TripFilterTab _tab = _TripFilterTab.all;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_search);
    _load();
  }

  @override
  void dispose() {
    _searchController.removeListener(_search);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final trips = await _repository.getTripSummaries(filter: _buildFilter());
      if (!mounted) return;
      setState(() {
        _trips = trips;
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

  Future<void> _search() => _load();

  CarTripFilter _buildFilter() {
    final query = _searchController.text.trim();
    final normalized = query.isEmpty ? null : query;
    switch (_tab) {
      case _TripFilterTab.all:
        return CarTripFilter(query: normalized);
      case _TripFilterTab.open:
        return CarTripFilter(status: CarTripStatus.open, query: normalized);
      case _TripFilterTab.closed:
        return CarTripFilter(status: CarTripStatus.closed, query: normalized);
      case _TripFilterTab.paid:
        return CarTripFilter(paymentStatus: CarPaymentStatus.paid, query: normalized);
      case _TripFilterTab.partial:
        return CarTripFilter(paymentStatus: CarPaymentStatus.partiallyPaid, query: normalized);
      case _TripFilterTab.unpaid:
        return CarTripFilter(paymentStatus: CarPaymentStatus.unpaid, query: normalized);
      case _TripFilterTab.overdue:
        return CarTripFilter(paymentStatus: CarPaymentStatus.overdue, query: normalized);
    }
  }

  Future<void> _newTrip() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CarTripEditorPage()),
    );
    if (mounted) await _load();
  }

  Future<void> _openTrip(CarTripSummaryView trip) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CarTripDetailsPage(tripId: trip.id)),
    );
    if (mounted) await _load();
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

  String _tripTitle(DateTime value) {
    final date = value.toLocal();
    final today = DateTime.now();
    final isToday = date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;
    final yesterday = today.subtract(const Duration(days: 1));
    final isYesterday = date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day;
    final formatted = _formatDate(value);
    if (isToday) return 'Today · $formatted';
    if (isYesterday) return 'Yesterday · $formatted';
    return formatted;
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
              for (final trip in _trips) _buildTripCard(trip),
          ],
        ),
      ),
    );
  }

  Widget _buildTripCard(CarTripSummaryView trip) {
    final status = _status(trip);
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
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
                    _tripTitle(trip.openedAt),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${trip.salesCarName} · ${trip.warehouseName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                  ),
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 6,
                    runSpacing: 3,
                    children: [
                      Text('${trip.totalLoadedCartons} loaded', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11)),
                      Text('${trip.totalReturnedCartons} returned', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11)),
                      Text('${trip.totalSoldCartons} sold', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11)),
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
