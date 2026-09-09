import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/app_card.dart';
import '../../../core/ui/empty_state.dart';
import '../../../core/ui/kpi_card.dart';
import '../../../core/ui/section_header.dart';
import '../../../core/ui/status_badge.dart';
import '../domain/dashboard_snapshot.dart';
import 'dashboard_controller.dart';
import 'widgets/recent_sale_tile.dart';
import 'widgets/revenue_summary_card.dart';

class DashboardPage extends StatefulWidget {
  final ValueChanged<int> onNavigateTo;
  final DashboardController controller;

  const DashboardPage({
    super.key,
    required this.onNavigateTo,
    required this.controller,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  @override
  void initState() {
    super.initState();
    widget.controller.load();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) => Scaffold(
        body: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            onRefresh: widget.controller.load,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _buildHeader(context)),
                SliverToBoxAdapter(child: _buildContent(context)),
                const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final now = DateTime.now();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _greeting(now),
                  style: AppTextStyles.caption(context).copyWith(
                    color: AppColors.of(context).textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Text('Sales overview', style: AppTextStyles.headline(context)),
                const SizedBox(height: 3),
                Text(
                  _formatDate(now),
                  style: AppTextStyles.caption(context).copyWith(
                    color: AppColors.of(context).textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          FilledButton.icon(
            onPressed: () => widget.onNavigateTo(1),
            icon: const Icon(Icons.add_rounded, size: 19),
            label: const Text('New sale'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    switch (widget.controller.status) {
      case DashboardStatus.initial:
      case DashboardStatus.loading:
        return const Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: Center(child: CircularProgressIndicator()),
        );
      case DashboardStatus.error:
        return Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: EmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Dashboard unavailable',
            message: widget.controller.errorMessage ?? 'Please try again.',
            actionLabel: 'Retry',
            onAction: widget.controller.load,
          ),
        );
      case DashboardStatus.ready:
        return _buildDashboard(context, widget.controller.snapshot!);
    }
  }

  Widget _buildDashboard(BuildContext context, DashboardSnapshot snapshot) {
    return Padding(
      padding: AppSpacing.screen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RevenueSummaryCard(snapshot: snapshot),
          const SizedBox(height: AppSpacing.md),
          _buildKpis(context, snapshot),
          if (snapshot.overdueInvoiceCount > 0) ...[
            const SizedBox(height: AppSpacing.lg),
            _buildOverdueNotice(context, snapshot),
          ],
          const SizedBox(height: AppSpacing.xl),
          SectionHeader(
            title: 'Revenue — last 7 days',
            subtitle: _money(snapshot.lastSevenDaysRevenue),
          ),
          const SizedBox(height: AppSpacing.md),
          _RevenueBars(snapshot: snapshot),
          const SizedBox(height: AppSpacing.xl),
          SectionHeader(
            title: 'Recent sales',
            actionLabel: 'View all',
            onAction: () => widget.onNavigateTo(1),
          ),
          const SizedBox(height: AppSpacing.md),
          _buildRecentSales(snapshot),
        ],
      ),
    );
  }

  Widget _buildKpis(BuildContext context, DashboardSnapshot snapshot) {
    return Row(
      children: [
        Expanded(
          child: KpiCard(
            title: 'Products',
            value: '${snapshot.productCount}',
            subtitle: 'Tracked products',
            icon: Icons.inventory_2_outlined,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: KpiCard(
            title: 'Customers',
            value: '${snapshot.customerCount}',
            subtitle: 'Active customer records',
            icon: Icons.people_outline_rounded,
            accentColor: AppColors.of(context).secondary,
          ),
        ),
      ],
    );
  }

  Widget _buildOverdueNotice(
    BuildContext context,
    DashboardSnapshot snapshot,
  ) {
    final colors = AppColors.of(context);
    return AppCard(
      color: colors.warningContainer,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      borderRadius: AppRadius.mdAll,
      child: Row(
        children: [
          Icon(Icons.schedule_outlined, color: colors.warning),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${snapshot.overdueInvoiceCount} overdue invoice${snapshot.overdueInvoiceCount == 1 ? '' : 's'}',
                  style: TextStyle(
                    color: colors.onWarningContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Outstanding balance: ${_money(snapshot.outstandingAmount, 2)}',
                  style: TextStyle(
                    color: colors.onWarningContainer,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const StatusBadge(type: StatusType.warning, label: 'Action needed'),
        ],
      ),
    );
  }

  Widget _buildRecentSales(DashboardSnapshot snapshot) {
    if (snapshot.recentInvoices.isEmpty) {
      return const EmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'No sales yet',
        message: 'Create your first sale to see activity here.',
      );
    }

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var index = 0; index < snapshot.recentInvoices.take(5).length; index++) ...[
            RecentSaleTile(invoice: snapshot.recentInvoices[index]),
            if (index < snapshot.recentInvoices.take(5).length - 1)
              const Divider(height: 1, indent: 16, endIndent: 16),
          ],
        ],
      ),
    );
  }

  String _money(double amount, [int decimals = 0]) =>
      'EGP ${amount.toStringAsFixed(decimals)}';

  String _greeting(DateTime now) {
    if (now.hour < 12) return 'Good morning';
    if (now.hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  String _formatDate(DateTime date) =>
      '${_monthName(date.month)} ${date.day}, ${date.year}';

  String _monthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return months[month - 1];
  }
}

class _RevenueBars extends StatelessWidget {
  final DashboardSnapshot snapshot;

  const _RevenueBars({required this.snapshot});

  String _weekdayLabel(DateTime date) {
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return labels[date.weekday - 1];
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final maximum = snapshot.maximumDailyRevenue;

    return AppCard(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final point in snapshot.weeklyRevenue)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  children: [
                    SizedBox(
                      height: 86,
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: FractionallySizedBox(
                          heightFactor: (point.revenue / maximum).clamp(0.05, 1.0),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: colors.primary,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(6),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      _weekdayLabel(point.date),
                      style: AppTextStyles.caption(context).copyWith(
                        color: colors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
