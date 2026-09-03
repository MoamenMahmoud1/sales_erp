import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';

/// The base elevated surface used for KPIs, analytics, products, invoices and
/// other important content. Provides consistent radius, padding and border.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final BorderRadius? borderRadius;
  final bool filled;
  final EdgeInsets? margin;

  const AppCard({
    super.key,
    required this.child,
    this.padding = AppSpacing.card,
    this.onTap,
    this.color,
    this.borderRadius,
    this.filled = true,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final radius = borderRadius ?? AppRadius.lgAll;
    final surface = color ?? (filled ? colors.surface : Colors.transparent);
    final gradientCard =
        filled && color == colors.secondaryContainer && radius == AppRadius.xlAll;

    final card = AnimatedContainer(
      duration: AppDurations.normal,
      curve: Curves.easeOut,
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: gradientCard ? null : surface,
        gradient: gradientCard
            ? const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                stops: [0.0, 0.30, 0.68, 1.0],
                colors: [
                  Color(0xFF1976D2),
                  Color(0xFF64B5F6),
                  Color(0xFFDCEEFF),
                  Color(0xFFF7FBFF),
                ],
              )
            : null,
        borderRadius: radius,
        border: filled
            ? Border.all(
                color: gradientCard
                    ? const Color(0xFF1976D2).withValues(alpha: .16)
                    : colors.divider,
                width: 1,
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: gradientCard
                ? const Color(0xFF1976D2).withValues(alpha: .10)
                : colors.scrim.withValues(alpha: 0.04),
            blurRadius: gradientCard ? 18 : 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );

    if (onTap == null) {
      // Wrap in a transparent Material so ListTiles/Inkwells inside the card
      // paint their ripple on this surface instead of a distant ancestor.
      return Material(
        type: MaterialType.transparency,
        child: card,
      );
    }
    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        splashColor: colors.primary.withValues(alpha: 0.08),
        highlightColor: colors.primary.withValues(alpha: 0.04),
        child: card,
      ),
    );
  }
}