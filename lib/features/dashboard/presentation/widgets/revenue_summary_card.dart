import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../domain/dashboard_snapshot.dart';

class RevenueSummaryCard extends StatelessWidget {
  final DashboardSnapshot snapshot;

  const RevenueSummaryCard({super.key, required this.snapshot});

  String _money(double value) => 'EGP ${value.toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final trend = snapshot.revenueTrendPercentage;
    final isPositive = trend >= 0;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.primary,
        borderRadius: AppRadius.xlAll,
        border: Border.all(
          color: colors.onPrimary.withValues(alpha: 0.10),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total revenue',
                        style: TextStyle(
                          color: colors.onPrimary.withValues(alpha: 0.72),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _money(snapshot.totalRevenue),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.numeric(
                          context,
                          size: 32,
                          weight: FontWeight.w900,
                        ).copyWith(color: colors.onPrimary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: colors.onPrimary.withValues(alpha: 0.10),
                    borderRadius: AppRadius.mdAll,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPositive
                            ? Icons.arrow_upward_rounded
                            : Icons.arrow_downward_rounded,
                        size: 14,
                        color: colors.onPrimary,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${trend.abs().toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: colors.onPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.lg,
              runSpacing: AppSpacing.sm,
              children: [
                _Metric(
                  label: 'Invoices',
                  value: '${snapshot.invoiceCount}',
                  colors: colors,
                ),
                _Metric(
                  label: 'Today',
                  value: _money(snapshot.todayRevenue),
                  colors: colors,
                ),
                _Metric(
                  label: 'Last 7 days',
                  value: _money(snapshot.lastSevenDaysRevenue),
                  colors: colors,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final AppColors colors;

  const _Metric({
    required this.label,
    required this.value,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: colors.onPrimary.withValues(alpha: 0.60),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            color: colors.onPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
