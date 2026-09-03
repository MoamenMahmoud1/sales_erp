import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/repositories/app_services.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/app_card.dart';
import '../../../core/ui/dialogs.dart';
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

class CarDailyDashboardPage extends StatefulWidget {
  final ValueChanged<int>? onNavigate;

  const CarDailyDashboardPage({super.key, this.onNavigate});

  @override
  State<CarDailyDashboardPage> createState() => _CarDailyDashboardPageState();
}

class _CarDailyDashboardPageState extends State<CarDailyDashboardPage>
    with WidgetsBindingObserver {
  final _repository = AppServices.instance.carTripRepository;
  final _calculator = const CarCalculator();
  final _evaluator = const CarPaymentEvaluator();

  late final StreamSubscription<CarTrip> _tripChanges;
  late final StreamSubscription<int> _tripDeletions;

  DateTime _day = _today();
  List<CarTripSummaryView> _trips = const [];
  bool _loading = true;
  bool _confirming = false;
  int? _confirmingTripId;
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

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final trips = await _repository.getTripSummaries(
        filter: CarTripFilter(from: _day, to: _day),
      );
      if (!mounted) return;
      setState(() {
        _trips = List.unmodifiable(trips);
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
    if (_sameDay(trip.openedAt.toLocal(), _day)) next.add(_summary(trip));
    next.sort((a, b) => b.openedAt.compareTo(a.openedAt));
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

  List<CarTripSummaryView> get _drafts =>
      _trips.where((trip) => trip.status == CarTripStatus.open).toList(growable: false);

  List<CarTripSummaryView> get _confirmed =>
      _trips.where((trip) => trip.status == CarTripStatus.closed).toList(growable: false);

  int get _confirmedSoldValue =>
      _confirmed.fold(0, (sum, trip) => sum + trip.finalValue.minorUnits);

  int get _outstandingValue =>
      _confirmed.fold(0, (sum, trip) => sum + trip.remaining.minorUnits);

  Future<void> _confirmDraft(CarTripSummaryView summary) async {
    if (_confirming || summary.status != CarTripStatus.open) return;

    final trip = await _repository.getTripById(summary.id);
    if (!mounted || trip == null || trip.isClosed) return;

    final calculated = _calculator.summary(trip);
    final issues = _calculator.validate(trip);
    if (issues.isNotEmpty) {
      _showError(issues.first.message);
      return;
    }

    final confirmed = await showConfirmDialog(
      context: context,
      title: 'Confirm this Draft?',
      message: 'This will finalize ${trip.displayNumber} and lock it as a confirmed Car trip.',
      confirmLabel: 'Confirm',
    );
    if (!confirmed || !mounted) return;

    setState(() {
      _confirming = true;
      _confirmingTripId = trip.id;
    });

    try {
      final finalized = await _repository.confirmTrip(
        trip.copyWith(
          status: CarTripStatus.closed,
          closedAt: trip.closedAt ?? DateTime.now().toUtc(),
        ),
        triggeredBy: 'today_dashboard_draft_confirm',
      );
      AppServices.instance.carTripEvents.publish(finalized);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${finalized.displayNumber} confirmed successfully.')),
      );
      _load();
    } catch (error) {
      if (mounted) _showError('$error');
    } finally {
      if (mounted) {
        setState(() {
          _confirming = false;
          _confirmingTripId = null;
        });
      }
    }

    calculated;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String _money(int minorUnits) =>
      'EGP ${(minorUnits / 100).toStringAsFixed(2)}';

  String _date(DateTime value) {
    final d = value.toLocal();
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  ({StatusType type, String label}) _paymentStatus(CarTripSummaryView trip) {
    final status = trip.paymentStatus(_evaluator, DateTime.now());
    switch (status) {
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

    final drafts = _drafts;
    final confirmed = _confirmed;

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
          Text('Today · ${_date(_day)}',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 16),
          _summaryGrid(),
          const SizedBox(height: 20),
          if (drafts.isNotEmpty) ...[
            _sectionHeader(
              'Draft trips',
              '${drafts.length} waiting for confirmation',
              accent: Theme.of(context).colorScheme.tertiary,
            ),
            const SizedBox(height: 10),
            for (final trip in drafts) _tripCard(trip),
            const SizedBox(height: 12),
          ],
          _sectionHeader(
            'Confirmed trips',
            '${confirmed.length} finalized today',
          ),
          const SizedBox(height: 10),
          if (confirmed.isEmpty)
            const EmptyState(
              icon: Icons.verified_outlined,
              title: 'No confirmed trips today',
              message: 'Confirmed trips will appear here after a Draft is finalized.',
            )
          else
            for (final trip in confirmed) _tripCard(trip),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () => widget.onNavigate?.call(1),
            icon: const Icon(Icons.list_alt_rounded),
            label: const Text('View all trips'),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, String subtitle, {Color? accent}) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 9,
          height: 38,
          decoration: BoxDecoration(
            color: accent ?? scheme.primary,
            borderRadius: BorderRadius.circular(9),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _summaryGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth < 560
            ? (constraints.maxWidth - 10) / 2
            : (constraints.maxWidth - 30) / 4;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _summaryCard(
              width: width,
              label: 'Drafts',
              value: '${_drafts.length}',
              helper: 'Needs confirmation',
              icon: Icons.edit_note_rounded,
              accent: Theme.of(context).colorScheme.tertiary,
            ),
            _summaryCard(
              width: width,
              label: 'Confirmed',
              value: '${_confirmed.length}',
              helper: 'Finalized trips',
              icon: Icons.verified_rounded,
            ),
            _summaryCard(
              width: width,
              label: 'Selling',
              value: _money(_confirmedSoldValue),
              helper: 'Confirmed only',
              icon: Icons.point_of_sale_rounded,
            ),
            _summaryCard(
              width: width,
              label: 'Outstanding',
              value: _money(_outstandingValue),
              helper: 'Confirmed unpaid balance',
              icon: Icons.account_balance_wallet_outlined,
              accent: Theme.of(context).colorScheme.error,
            ),
          ],
        );
      },
    );
  }

  Widget _summaryCard({
    required double width,
    required String label,
    required String value,
    required String helper,
    required IconData icon,
    Color? accent,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final color = accent ?? scheme.primary;
    return SizedBox(
      width: width,
      child: AppCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 21, color: color),
            const SizedBox(height: 9),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            ),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(helper, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10.5, color: scheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  Widget _tripCard(CarTripSummaryView trip) {
    final scheme = Theme.of(context).colorScheme;
    final isDraft = trip.status == CarTripStatus.open;
    final payment = _paymentStatus(trip);
    final confirming = _confirmingTripId == trip.id;
    final borderColor = isDraft ? scheme.tertiary : scheme.primary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          borderRadius: AppRadius.xlAll,
          border: Border.all(color: borderColor.withValues(alpha: .28)),
        ),
        child: AppCard(
          borderRadius: AppRadius.xlAll,
          padding: const EdgeInsets.all(14),
          onTap: confirming
              ? null
              : () => Navigator.of(context).push(
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
                      color: isDraft ? scheme.tertiaryContainer : scheme.primaryContainer,
                      borderRadius: AppRadius.mdAll,
                    ),
                    child: Icon(
                      isDraft ? Icons.edit_note_rounded : Icons.local_shipping_rounded,
                      color: isDraft ? scheme.onTertiaryContainer : scheme.primary,
                    ),
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
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      StatusBadge(
                        type: isDraft ? StatusType.warning : StatusType.success,
                        label: isDraft ? 'Draft' : 'Confirmed',
                      ),
                      if (!isDraft) ...[
                        const SizedBox(height: 5),
                        StatusBadge(type: payment.type, label: payment.label),
                      ],
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _dataPill('Loaded', '${trip.totalLoadedCartons}', scheme.surfaceContainerHighest),
                  _dataPill('Returned', '${trip.totalReturnedCartons}', scheme.surfaceContainerHighest),
                  _dataPill('Sold', '${trip.totalSoldCartons}', scheme.surfaceContainerHighest),
                ],
              ),
              if (!isDraft) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _financePill(
                      'Selling',
                      _money(trip.finalValue.minorUnits),
                      scheme.primaryContainer,
                      scheme.primary,
                    ),
                    _financePill(
                      'Buying',
                      _money(trip.purchaseValue.minorUnits),
                      scheme.secondaryContainer,
                      scheme.secondary,
                    ),
                    _financePill(
                      'Profit',
                      _money(trip.profitValue.minorUnits),
                      scheme.tertiaryContainer,
                      scheme.onTertiaryContainer,
                    ),
                  ],
                ),
              ],
              if (isDraft) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.tonalIcon(
                    onPressed: _confirming ? null : () => _confirmDraft(trip),
                    icon: confirming
                        ? const SizedBox(width: 17, height: 17, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.check_circle_outline_rounded, size: 18),
                    label: Text(confirming ? 'Confirming...' : 'Confirm Draft'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _financePill(
    String label,
    String value,
    Color background,
    Color foreground,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadius.mdAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: foreground.withValues(alpha: .78),
            ),
          ),
          const SizedBox(height: 1),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dataPill(String label, String value, Color background) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadius.smAll,
      ),
      child: RichText(
        text: TextSpan(
          style: TextStyle(color: scheme.onSurface, fontSize: 11),
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
