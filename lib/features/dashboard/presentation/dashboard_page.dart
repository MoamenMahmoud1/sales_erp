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
      builder: (context, _) {
        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: RefreshIndicator(
              onRefresh: widget.controller.load,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: _buildHeader(context)),
                  SliverToBoxAdapter(child: _buildContent(context)),
                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
                ],
              ),
            ),
          ),
        );
      },
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
        AppSpacing.sm,
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
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text('Sales overview', style: AppTextStyles.headline(context)),
                const SizedBox(height: 3),
                Text(
                  _formatDate(now),
                  style: AppTextStyles.caption(context).copyWith(
                    color: colors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: colors.surfaceMuted,
              borderRadius: AppRadius.mdAll,
              border: Border.all(color: colors.divider),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline_rounded, size: 16, color: colors.success),
                const SizedBox(width: 6),
                Text(
                  'Protected',
                  style: AppTextStyles.label(context).copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final controller = widget.controller;
    switch (controller.status) {
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
            message: controller.errorMessage ?? 'Please try again.',
            actionLabel: 'Retry',
            onAction: controller.load,
          ),
        );
      case DashboardStatus.ready:
        final snapshot = controller.snapshot!;
        return _buildDashboard(context, snapshot);
    }
  }

  Widget _buildDashboard(
    BuildContext context,
    DashboardSnapshot snapshot,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRevenueSummary(context, snapshot),
          const SizedBox(height: AppSpacing.md),
          _buildKpis(snapshot),
          const SizedBox(height: AppSpacing.xl),
          SectionHeader(
            title: 'Revenue — last 7 days',
            subtitle: _money(snapshot.lastSevenDaysRevenue),
          ),
          const SizedBox(height: AppSpacing.md),
          _buildRevenueChart(context, snapshot),
          const SizedBox(height: AppSpacing.xl),
          const SectionHeader(title: 'Quick actions'),
          const SizedBox(height: AppSpacing.md),
          _buildQuickActions(context),
          if (snapshot.overdueInvoiceCount > 0) ...[
            const SizedBox(height: AppSpacing.xl),
            _buildOverdueNotice(context, snapshot),
          ],
          const SizedBox(height: AppSpacing.xl),
          SectionHeader(
            title: 'Recent sales',
            actionLabel: 'View all',
            onAction: () => widget.onNavigateTo(1),
          ),
          const SizedBox(height: AppSpacing.md),
          _buildRecentSales(context, snapshot),
          const SizedBox(height: AppSpacing.xl),
          _buildInventorySummary(context, snapshot),
        ],
      ),
    );
  }

  Widget _buildRevenueSummary(
    BuildContext context,
    DashboardSnapshot snapshot,
  ) {
    final colors = AppColors.of(context);
    final isPositive = snapshot.revenueTrendPercentage >= 0;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      color: colors.surface,
      borderRadius: AppRadius.lgAll,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total revenue',
                  style: AppTextStyles.label(context).copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _money(snapshot.totalRevenue, 2),
                  style: AppTextStyles.numeric(context, size: 32),
                ),
                const SizedBox(height: 6),
                Text(
                  '${snapshot.invoiceCount} invoices · ${_money(snapshot.todayRevenue, 2)} today',
                  style: AppTextStyles.caption(context).copyWith(
                    color: colors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(
              color: isPositive ? colors.successContainer : colors.errorContainer,
              borderRadius: AppRadius.mdAll,
              border: Border.all(
                color: (isPositive ? colors.success : colors.error)
                    .withValues(alpha: .35),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isPositive
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded,
                  size: 14,
                  color: isPositive ? colors.success : colors.error,
                ),
                const SizedBox(width: 3),
                Text(
                  '${snapshot.revenueTrendPercentage.abs().toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: isPositive ? colors.success : colors.error,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpis(DashboardSnapshot snapshot) {
    return Row(
      children: [
        Expanded(
          child: KpiCard(
            title: 'Products',
            value: '${snapshot.productCount}',
            icon: Icons.inventory_2_outlined,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: KpiCard(
            title: 'Customers',
            value: '${snapshot.customerCount}',
            icon: Icons.people_outline_rounded,
          ),
        ),
      ],
    );
  }

  Widget _buildRevenueChart(
    BuildContext context,
    DashboardSnapshot snapshot,
  ) {
    final colors = AppColors.of(context);
    final maximumRevenue = snapshot.maximumDailyRevenue;

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
                      height: 72,
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          width: 12,
                          height: (point.revenue / maximumRevenue).clamp(.02, 1) * 72,
                          decoration: BoxDecoration(
                            color: colors.primary,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
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

  Widget _buildQuickActions(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        OutlinedButton.icon(
          onPressed: () => widget.onNavigateTo(1),
          icon: const Icon(Icons.add_shopping_cart_outlined),
          label: const Text('New sale'),
        ),
        OutlinedButton.icon(
          onPressed: () => widget.onNavigateTo(2),
          icon: const Icon(Icons.inventory_2_outlined),
          label: const Text('Products'),
        ),
        OutlinedButton.icon(
          onPressed: () => widget.onNavigateTo(3),
          icon: const Icon(Icons.person_add_alt_1_outlined),
          label: const Text('Customers'),
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
                  style: TextStyle(color: colors.onWarningContainer, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentSales(
    BuildContext context,
    DashboardSnapshot snapshot,
  ) {
    if (snapshot.recentInvoices.isEmpty) {
      return const EmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'No sales yet',
        message: 'Create your first sale to see activity here.',
      );
    }

    return Column(
      children: [
        for (final invoice in snapshot.recentInvoices)
          _RecentSaleTile(invoice: invoice),
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
            padding: const EdgeInsets.all(9),
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
    const monthNames = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return monthNames[month - 1];
  }

  String _weekdayLabel(DateTime date) {
    const weekdayNames = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return weekdayNames[date.weekday - 1];
  }
}

class _RecentSaleTile extends StatelessWidget {
  final DashboardInvoiceSummary invoice;

  const _RecentSaleTile({required this.invoice});

  StatusType _statusType(String? status) => switch (status) {
        'paid' => StatusType.success,
        'pending' => StatusType.warning,
        'overdue' => StatusType.error,
        _ => StatusType.neutral,
      };

  String _statusLabel(String? status) => switch (status) {
        'paid' => 'Paid',
        'pending' => 'Pending',
        'overdue' => 'Overdue',
        _ => 'Unknown',
      };

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: colors.divider),
      ),
      child: Row(
        children: [
          Text(
            '#${invoice.id}',
            style: AppTextStyles.label(context).copyWith(
              color: colors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  invoice.customerName,
                  style: AppTextStyles.title(context).copyWith(fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  '${invoice.createdAt.toLocal().month}/${invoice.createdAt.toLocal().day}',
                  style: AppTextStyles.caption(context).copyWith(
                    color: colors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'EGP ${invoice.total.toStringAsFixed(0)}',
                style: AppTextStyles.label(context).copyWith(fontSize: 13),
              ),
              const SizedBox(height: 4),
              StatusBadge(
                type: _statusType(invoice.paymentStatus),
                label: _statusLabel(invoice.paymentStatus),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
