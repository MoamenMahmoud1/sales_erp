import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';

/// Standard content surface for ERP screens.
///
/// Shared cards stay neutral. A single intentionally prominent dashboard card
/// may use the narrow featured signature without changing its child tree.
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
    final theme = Theme.of(context);
    final radius = borderRadius ?? AppRadius.lgAll;
    final surfaceColor = color ?? (filled ? colors.surface : Colors.transparent);
    final isFeatured =
        filled &&
        radius == AppRadius.xlAll &&
        padding == const EdgeInsets.all(17) &&
        color == theme.colorScheme.secondaryContainer;

    final decoration = BoxDecoration(
      color: isFeatured ? null : surfaceColor,
      gradient: isFeatured
          ? LinearGradient(
              begin: Alignment.bottomLeft,
              end: Alignment.topRight,
              stops: const [0.0, 0.56, 1.0],
              colors: [
                colors.featuredStart,
                colors.featuredMiddle,
                colors.featuredEnd,
              ],
            )
          : null,
      borderRadius: radius,
      border: filled
          ? Border.all(
              color: isFeatured
                  ? colors.featuredHighlight.withValues(alpha: 0.16)
                  : colors.divider,
            )
          : null,
      boxShadow: isFeatured
          ? [
              BoxShadow(
                color: colors.featuredStart.withValues(alpha: 0.18),
                blurRadius: 16,
                offset: const Offset(0, 7),
              ),
            ]
          : null,
    );

    final card = AnimatedContainer(
      duration: AppDurations.normal,
      curve: Curves.easeOut,
      margin: margin,
      padding: padding,
      decoration: decoration,
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
        splashColor: isFeatured
            ? colors.featuredHighlight.withValues(alpha: 0.08)
            : colors.primary.withValues(alpha: 0.08),
        highlightColor: isFeatured
            ? colors.featuredHighlight.withValues(alpha: 0.04)
            : colors.primary.withValues(alpha: 0.04),
        child: card,
      ),
    );
  }
}
