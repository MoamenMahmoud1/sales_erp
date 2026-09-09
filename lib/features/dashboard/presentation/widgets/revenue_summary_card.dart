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
        borderRadius: AppRadius.xlAll,
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          stops: const [0.0, 0.48, 1.0],
          colors: [colors.heroStart, colors.heroMiddle, colors.heroEnd],
        ),
        boxShadow: [
          BoxShadow(
            color: colors.heroStart.withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: AppRadius.xlAll,
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(-1.04, -1.02),
                      radius: 1.08,
                      colors: [
                        colors.heroHighlight.withValues(alpha: 0.18),
                        colors.heroHighlight.withValues(alpha: 0.06),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.18, 0.56],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              top: 20,
              bottom: 20,
              width: 2,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.heroHighlight.withValues(alpha: 0.34),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
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
                                color: colors.onPrimary.withValues(alpha: 0.78),
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
                            const SizedBox(height: 5),
                            Text(
                              '${snapshot.invoiceCount} invoices · ${_money(snapshot.todayRevenue)} today',
                              style: TextStyle(
                                color: colors.onPrimary.withValues(alpha: 0.72),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                        decoration: BoxDecoration(
                          color: colors.onPrimary.withValues(alpha: 0.12),
                          borderRadius: AppRadius.mdAll,
                          border: Border.all(
                            color: colors.onPrimary.withValues(alpha: 0.18),
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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(child: _MiniBars(snapshot: snapshot)),
                      const SizedBox(width: AppSpacing.lg),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '7-day revenue',
                            style: TextStyle(
                              color: colors.onPrimary.withValues(alpha: 0.68),
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _money(snapshot.lastSevenDaysRevenue),
                            style: TextStyle(
                              color: colors.onPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniBars extends StatelessWidget {
  final DashboardSnapshot snapshot;

  const _MiniBars({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final maximum = snapshot.maximumDailyRevenue;

    return SizedBox(
      height: 52,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final point in snapshot.weeklyRevenue)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: FractionallySizedBox(
                  heightFactor: (point.revenue / maximum).clamp(0.08, 1),
                  alignment: Alignment.bottomCenter,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.onPrimary.withValues(alpha: 0.34),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(4),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
