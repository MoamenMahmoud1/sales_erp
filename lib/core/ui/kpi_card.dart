import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import 'app_card.dart';

/// Direction + magnitude of a trend. Trend direction is conveyed through both
/// color and the arrow so it's not color-only communication.
enum TrendDirection { up, down, flat }

/// A KPI card: title, prominent value, optional subtitle, icon and trend.
class KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData? icon;
  final TrendDirection? trend;
  final String? trendLabel;
  final Color? accentColor;

  const KpiCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    this.icon,
    this.trend,
    this.trendLabel,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final accent = accentColor ?? colors.primary;

    final trendIcon = switch (trend) {
      TrendDirection.up => Icons.trending_up_rounded,
      TrendDirection.down => Icons.trending_down_rounded,
      _ => Icons.trending_flat_rounded,
    };
    final trendColor = switch (trend) {
      TrendDirection.up => colors.success,
      TrendDirection.down => colors.error,
      _ => colors.textMuted,
    };

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (icon != null)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.14),
                    borderRadius: AppRadius.mdAll,
                  ),
                  child: Icon(icon, size: 18, color: accent),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.numeric(context, size: 26),
          ),
          if (subtitle != null || trendLabel != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (trend != null) ...[
                  Icon(trendIcon, size: 15, color: trendColor),
                  const SizedBox(width: 4),
                ],
                if (trendLabel != null)
                  Text(
                    trendLabel!,
                    style: TextStyle(
                      color: trendColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                if (subtitle != null) ...[
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: colors.textMuted, fontSize: 12),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}