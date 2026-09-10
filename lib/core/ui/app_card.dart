import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../theme/featured_card_theme.dart';

/// Standard content surface for ERP screens.
///
/// Shared cards are neutral by default. A screen may explicitly enable the
/// featured-card scope when one surface needs stronger visual emphasis.
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
    final scope = theme.extension<FeaturedCardTheme>();
    final isFeatured =
        scope?.enabled == true && color == theme.colorScheme.secondaryContainer;
    final surfaceColor = color ?? (filled ? colors.surface : Colors.transparent);

    final decoration = BoxDecoration(
      color: isFeatured ? null : surfaceColor,
      gradient: isFeatured
          ? LinearGradient(
              begin: Alignment.bottomLeft,
              end: Alignment.topRight,
              stops: const [0.0, 0.58, 1.0],
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
                color: colors.featuredStart.withValues(alpha: 0.24),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ]
          : null,
    );

    Widget content = child;
    if (isFeatured) {
      final featuredScheme = theme.colorScheme.copyWith(
        secondary: colors.featuredMiddle,
        onSecondary: Colors.white,
        secondaryContainer: colors.featuredMiddle,
        onSecondaryContainer: Colors.white,
      );
      content = Theme(
        data: theme.copyWith(colorScheme: featuredScheme),
        child: ClipRRect(
          borderRadius: radius,
          child: Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0.92, -0.92),
                        radius: 1.05,
                        colors: [
                          colors.featuredHighlight.withValues(alpha: 0.18),
                          colors.featuredHighlight.withValues(alpha: 0.06),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.24, 0.64],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned.fill(child: child),
            ],
          ),
        ),
      );
    }

    final card = AnimatedContainer(
      duration: AppDurations.normal,
      curve: Curves.easeOut,
      margin: margin,
      padding: padding,
      decoration: decoration,
      child: content,
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
