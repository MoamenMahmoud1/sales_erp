import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../theme/featured_card_theme.dart';

/// Standard content surface for ERP screens.
///
/// Shared cards stay neutral by default. A screen can explicitly opt into the
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
    return hsl
        .withLightness((hsl.lightness + delta).clamp(0.04, 0.96))
        .toColor();
  }

  List<Color> _featuredColors(BuildContext context) {
    final colors = AppColors.of(context);
    final brightness = Theme.of(context).brightness;
    final base = brightness == Brightness.dark
        ? const Color(0xFF08428C)
        : _withLightness(colors.primary, -0.14);

    return [
      _withLightness(base, -0.10),
      base,
      _withLightness(base, 0.14),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final theme = Theme.of(context);
    final radius = borderRadius ?? AppRadius.lgAll;
    final scope = theme.extension<FeaturedCardTheme>();
    final useFeaturedStyle =
        scope?.enabled == true && color == theme.colorScheme.secondaryContainer;
    final surfaceColor = color ?? (filled ? colors.surface : Colors.transparent);
    final featuredColors = useFeaturedStyle ? _featuredColors(context) : null;

    final decoration = BoxDecoration(
      color: featuredColors == null ? surfaceColor : null,
      gradient: featuredColors == null
          ? null
          : LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              stops: const [0.0, 0.5, 1.0],
              colors: featuredColors,
            ),
      borderRadius: radius,
      border: filled
          ? Border.all(
              color: useFeaturedStyle
                  ? Colors.white.withValues(alpha: 0.14)
                  : colors.divider,
            )
          : null,
      boxShadow: useFeaturedStyle
          ? [
              BoxShadow(
                color: featuredColors!.first.withValues(alpha: 0.24),
                blurRadius: 18,
                offset: const Offset(0, 8),
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
      child: useFeaturedStyle
          ? ClipRRect(
              borderRadius: radius,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: const Alignment(-1.02, -1.02),
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
                  child,
                ],
              ),
            )
          : child,
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
        splashColor: useFeaturedStyle
            ? Colors.white.withValues(alpha: 0.08)
            : colors.primary.withValues(alpha: 0.08),
        highlightColor: useFeaturedStyle
            ? Colors.white.withValues(alpha: 0.04)
            : colors.primary.withValues(alpha: 0.04),
        child: card,
      ),
    );
  }
}
