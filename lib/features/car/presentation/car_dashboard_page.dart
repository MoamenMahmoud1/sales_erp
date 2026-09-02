import 'package:flutter/material.dart';

import '../../../core/repositories/app_services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/app_card.dart';
import '../../../core/ui/empty_state.dart';
import '../../../core/ui/section_header.dart';
import '../../../core/ui/status_badge.dart';
import '../application/usecases/load_car_dashboard.dart';
import '../domain/entities/car_trip_summary_view.dart';
import 'car_trip_details_page.dart';
import 'car_trip_editor_page.dart';
import 'widgets/car_metric_card.dart';

class CarDashboardPage extends StatefulWidget {
  final ValueChanged<int>? onNavigate;

  const CarDashboardPage({super.key, this.onNavigate});

  @override
  State<CarDashboardPage> createState() => _CarDashboardPageState();
}

class _CarDashboardPageState extends State<CarDashboardPage> {
  late final LoadCarDashboard _loadDashboard = LoadCarDashboard(
    reportRepository: AppServices.instance.carReportRepository,
    tripRepository: AppServices.instance.carTripRepository,
  );

  CarDashboardData? _data;
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
      final data = await _loadDashboard();
      if (!mounted) return;
      setState(() { _data = data; _loading = false; });
    } catch (error) {
      if (!mounted) return;
      setState(() { _loading = false; _error = '$error'; });
    }
  }

  String _money(int minor) => 'EGP ${(minor / 100).toStringAsFixed(2)}';

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

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: EmptyState(
          icon: Icons.error_outline_rounded,
          title: 'Unable to load Car dashboard',
          message: _error!,
          actionLabel: 'Retry',
          onAction: _load,
        ),
      );
    }

    final data = _data!;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 120),
        children: [
          _buildHeader(),
          const SizedBox(height: AppSpacing.lg),
          _buildFlowHero(data),
          const SizedBox(height: AppSpacing.md),
          _buildMetrics(data),
          const SizedBox(height: AppSpacing.xl),
          SectionHeader(
            title: 'Recent trips',
            subtitle: '${data.totals.closedCount} closed · ${data.totals.openCount} open',
            actionLabel: 'New trip',
            onAction: _newTrip,
          ),
          const SizedBox(height: AppSpacing.md),
          if (data.recentTrips.isEmpty)
            const EmptyState(
              icon: Icons.local_shipping_outlined,
              title: 'No Car trips yet',
              message: 'Create the first daily load to start tracking cartons and sales.',
            )
          else
            for (final trip in data.recentTrips) _tripTile(trip),
          const SizedBox(height: AppSpacing.xl),
          _buildPaymentOverview(data),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final colors = AppColors.of(context);
    final now = DateTime.now();
    final date = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Car distribution', style: TextStyle(color: colors.textMuted, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text('Daily operations', style: AppTextStyles.headline(context)),
              const SizedBox(height: 4),
              Text(date, style: TextStyle(color: colors.textMuted, fontSize: 12)),
            ],
          ),
        ),
        FilledButton.icon(
          onPressed: _newTrip,
          icon: const Icon(Icons.add_rounded),
          label: const Text('New trip'),
        ),
      ],
    );
  }

  Widget _buildFlowHero(CarDashboardData data) {
    final colors = AppColors.of(context);
    final totals = data.totals;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: colors.primary,
        borderRadius: AppRadius.xxlAll,
        boxShadow: [BoxShadow(color: colors.primary.withValues(alpha: .24), blurRadius: 24, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Today’s Car Flow', style: TextStyle(color: colors.onPrimary.withValues(alpha: .85), fontWeight: FontWeight.w700)),
          const SizedBox(height: 18),
          Row(
            children: [
              _heroNumber('Loaded', totals.totalLoadedCartons, Icons.outbox_rounded, colors.onPrimary),
              _arrow(colors.onPrimary),
              _heroNumber('Returned', totals.totalReturnedCartons, Icons.assignment_return_rounded, colors.onPrimary),
              _arrow(colors.onPrimary),
              _heroNumber('Sold', totals.totalSoldCartons, Icons.point_of_sale_rounded, colors.onPrimary),
            ],
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: colors.onPrimary.withValues(alpha: .10),
              borderRadius: AppRadius.xlAll,
              border: Border.all(color: colors.onPrimary.withValues(alpha: .12)),
            ),
            child: Row(
              children: [
                Expanded(child: Text('Actual sold value', style: TextStyle(color: colors.onPrimary.withValues(alpha: .82)))),
                Text(_money(totals.finalValue.minorUnits), style: TextStyle(color: colors.onPrimary, fontWeight: FontWeight.w900, fontSize: 17)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroNumber(String label, int value, IconData icon, Color color) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color.withValues(alpha: .84), size: 22),
          const SizedBox(height: 6),
          Text('$value', style: TextStyle(color: color, fontSize: 27, fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: color.withValues(alpha: .78), fontSize: 11, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _arrow(Color color) => Icon(Icons.chevron_right_rounded, color: color.withValues(alpha: .40));

  Widget _buildMetrics(CarDashboardData data) {
    final t = data.totals;
    return Column(
      children: [
        Row(children: [
          Expanded(child: CarMetricCard(label: 'Final sold value', value: _money(t.finalValue.minorUnits), icon: Icons.attach_money_rounded)),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: CarMetricCard(label: 'Total paid', value: _money(t.totalPaid.minorUnits), icon: Icons.payments_rounded)),
        ]),
        const SizedBox(height: AppSpacing.sm),
        Row(children: [
          Expanded(child: CarMetricCard(label: 'Remaining', value: _money(t.totalRemaining.minorUnits), icon: Icons.account_balance_wallet_outlined)),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: CarMetricCard(label: 'Overdue', value: '${t.overdueCount}', icon: Icons.schedule_rounded, accent: t.overdueCount > 0 ? Theme.of(context).colorScheme.error : null)),
        ]),
      ],
    );
  }

  Widget _tripTile(CarTripSummaryView trip) {
    final evaluator = const _StatusHelper();
    final status = evaluator.status(trip);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: const EdgeInsets.all(14),
        onTap: () => _openTrip(trip),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: AppRadius.lgAll,
              ),
              child: Icon(Icons.local_shipping_rounded, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(trip.displayNumber, style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Text('${trip.salesCarName} · ${trip.warehouseName}', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text('${trip.totalLoadedCartons} loaded · ${trip.totalReturnedCartons} returned · ${trip.totalSoldCartons} sold', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 11)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(_money(trip.finalValue.minorUnits), style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 5),
                StatusBadge(type: status.type, label: status.label),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentOverview(CarDashboardData data) {
    final t = data.totals;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Payment overview', subtitle: 'Attention needed on unpaid Car invoices'),
          const SizedBox(height: AppSpacing.md),
          _paymentRow('Paid', t.paidCount, StatusType.success),
          _paymentRow('Partially paid', t.partiallyPaidCount, StatusType.warning),
          _paymentRow('Unpaid', t.unpaidCount, StatusType.neutral),
          _paymentRow('Overdue', t.overdueCount, StatusType.error),
        ],
      ),
    );
  }

  Widget _paymentRow(String label, int count, StatusType type) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Expanded(child: Text(label)),
            StatusBadge(type: type, label: '$count'),
          ],
        ),
      );
}

class _StatusHelper {
  const _StatusHelper();

  ({StatusType type, String label}) status(CarTripSummaryView trip) {
    if (trip.remaining.minorUnits == 0) return (type: StatusType.success, label: 'Paid');
    if (trip.dueDate != null && DateTime.now().isAfter(trip.dueDate!)) {
      return (type: StatusType.error, label: 'Overdue');
    }
    if (trip.paidTotal.minorUnits > 0) return (type: StatusType.warning, label: 'Partially paid');
    return (type: StatusType.neutral, label: 'Unpaid');
  }
}
