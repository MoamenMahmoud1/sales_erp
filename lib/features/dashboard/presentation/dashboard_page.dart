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
  final bool Function(int)? canNavigateTo;
  final DashboardController controller;

  const DashboardPage({
    super.key,
    required this.onNavigateTo,
    this.canNavigateTo,
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
    final colors = AppColors.of(context);
    final now = DateTime.now();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _greeting(now),
                  style: AppTextStyles.title(context).copyWith(
                    color: colors.textMuted,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                Text('Sales overview', style: AppTextStyles.headline(context)),
                const SizedBox(height: 2),
                Text(
                  _formatDate(now),
                  style: AppTextStyles.caption(context).copyWith(
                    color: colors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          _ProtectedIndicator(colors: colors),
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
          const SizedBox(height: AppSpacing.xl),
          SectionHeader(
            title: 'Revenue — last 7 days',
            subtitle: _money(snapshot.lastSevenDaysRevenue),
          ),
          const SizedBox(height: AppSpacing.md),
          _RevenueBars(snapshot: snapshot),
          const SizedBox(height: AppSpacing.xl),
          const SectionHeader(title: 'Quick actions'),
          const SizedBox(height: AppSpacing.md),
          _buildQuickActions(),
          if (snapshot.overdueInvoiceCount > 0) ...[
            const SizedBox(height: AppSpacing.xl),
            _buildOverdueNotice(context, snapshot),
          ],
          const SizedBox(height: AppSpacing.xl),
          SectionHeader(
            title: 'Recent sales',
            actionLabel: _canNavigateTo(1) ? 'View all' : null,
            onAction: _canNavigateTo(1) ? () => widget.onNavigateTo(1) : null,
          ),
          const SizedBox(height: AppSpacing.md),
          _buildRecentSales(snapshot),
          const SizedBox(height: AppSpacing.xl),
          _buildInventorySummary(context, snapshot),
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

  Widget _buildQuickActions() {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        if (_canNavigateTo(1))
          OutlinedButton.icon(
            onPressed: () => widget.onNavigateTo(1),
            icon: const Icon(Icons.add_shopping_cart_outlined),
            label: const Text('New sale'),
          ),
        if (_canNavigateTo(2))
          OutlinedButton.icon(
            onPressed: () => widget.onNavigateTo(2),
            icon: const Icon(Icons.inventory_2_outlined),
            label: const Text('Products'),
          ),
        if (_canNavigateTo(3))
          OutlinedButton.icon(
            onPressed: () => widget.onNavigateTo(3),
            icon: const Icon(Icons.person_add_alt_1_outlined),
            label: const Text('Customers'),
          ),
      ],
    );
  }

  bool _canNavigateTo(int legacyIndex) {
    return widget.canNavigateTo?.call(legacyIndex) ?? true;
  }

  Widget _buildOverdueNotice(
    BuildContext context,
    DashboardSnapshot snapshot,
  ) {
    final colors = AppColors.of(context);
    return AppCard(
      color: colors.warningContainer,
      padding: const EdgeInsets.all(AppSpacing.lg),
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

    return Column(
      children: [
        for (final invoice in snapshot.recentInvoices.take(5))
          RecentSaleTile(invoice: invoice),
      ],
    );
  }

  Widget _buildInventorySummary(
    BuildContext context,
    DashboardSnapshot snapshot,
  ) {
    final colors = AppColors.of(context);
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.infoContainer,
              borderRadius: AppRadius.mdAll,
            ),
            child: Icon(Icons.inventory_outlined, color: colors.info),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${snapshot.productCount} products tracked',
                  style: AppTextStyles.title(context).copyWith(fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  'Keep stock updated as sales are recorded.',
                  style: AppTextStyles.caption(context).copyWith(
                    color: colors.textMuted,
                  ),
                ),
              ],
            ),
          ),
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

class _ProtectedIndicator extends StatelessWidget {
  final AppColors colors;

  const _ProtectedIndicator({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: colors.successContainer,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: colors.success.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_outline_rounded, size: 15, color: colors.success),
          const SizedBox(width: 5),
          Text(
            'Protected',
            style: TextStyle(
              color: colors.onSuccessContainer,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
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
