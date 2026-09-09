import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';

/// Standard content surface for ERP screens.
///
/// Visual treatment stays deliberately restrained: solid surface, compact
/// radius, and a subtle border. Feature-specific decoration belongs in the
/// feature widget rather than in the shared card primitive.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final BorderRadius? borderRadius;
  final bool filled;
  final EdgeInsets? margin;
  final Gradient? gradient;

  const AppCard({
    super.key,
    required this.child,
    this.padding = AppSpacing.card,
    this.onTap,
    this.color,
    this.borderRadius,
    this.filled = true,
    this.margin,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final radius = borderRadius ?? AppRadius.lgAll;
    final surfaceColor = color ?? (filled ? colors.surface : Colors.transparent);

    final card = AnimatedContainer(
      duration: AppDurations.normal,
      curve: Curves.easeOut,
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null ? surfaceColor : null,
        gradient: gradient,
        borderRadius: radius,
        border: filled ? Border.all(color: colors.divider) : null,
      ),
      child: child,
    );

    if (onTap == null) {
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
