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

  Color _withLightness(Color color, double delta) {
    final hsl = HSLColor.fromColor(color);
    final lightness = (hsl.lightness + delta).clamp(0.05, 0.94).toDouble();
    return hsl.withLightness(lightness).toColor();
  }

  List<Color> _featuredColors(BuildContext context) {
    final primary = AppColors.of(context).primary;
    final deepColor = _withLightness(primary, -0.18);
    final brightColor = _withLightness(primary, 0.18);

    return [deepColor, primary, brightColor];
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final theme = Theme.of(context);
    final radius = borderRadius ?? AppRadius.lgAll;
    final isFeatured =
        theme.extension<FeaturedCardTheme>()?.enabled == true && color != null;
    final featuredColors = isFeatured ? _featuredColors(context) : const <Color>[];
    final surfaceColor = color ?? (filled ? colors.surface : Colors.transparent);

    final decoration = BoxDecoration(
      color: isFeatured ? null : surfaceColor,
      gradient: isFeatured
          ? LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              stops: const [0.0, 0.5, 1.0],
              colors: featuredColors,
            )
          : null,
      borderRadius: radius,
      border: filled
          ? Border.all(
              color: isFeatured
                  ? Colors.white.withValues(alpha: 0.14)
                  : colors.divider,
            )
          : null,
      boxShadow: isFeatured
          ? [
              BoxShadow(
                color: featuredColors.first.withValues(alpha: 0.22),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ]
          : null,
    );

    final content = isFeatured
        ? ClipRRect(
            borderRadius: radius,
            child: Stack(
              children: [
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: const Alignment(-1.02, -0.92),
                          radius: 1.08,
                          colors: [
                            Colors.white.withValues(alpha: 0.16),
                            Colors.white.withValues(alpha: 0.05),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.20, 0.58],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned.fill(child: child),
              ],
            ),
          )
        : child;

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
            ? Colors.white.withValues(alpha: 0.08)
            : colors.primary.withValues(alpha: 0.08),
        highlightColor: isFeatured
            ? Colors.white.withValues(alpha: 0.04)
            : colors.primary.withValues(alpha: 0.04),
        child: card,
      ),
    );
  }
}
