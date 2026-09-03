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
    final scheme = Theme.of(context).colorScheme;
    final radius = borderRadius ?? AppRadius.lgAll;
    final surface = color ?? (filled ? colors.surface : Colors.transparent);
    final gradientCard =
        gradient != null ||
        (filled && color == scheme.secondaryContainer && radius == AppRadius.xlAll);

    final bool isLight = scheme.brightness == Brightness.light;
    final Color buyingStart = isLight
        ? Color.lerp(colors.info, colors.infoContainer, .48)!
        : colors.infoContainer;
    final Color buyingEnd = isLight
        ? Color.lerp(colors.info, colors.infoContainer, .66)!
        : Color.lerp(colors.infoContainer, colors.info, .42)!;

    final cardGradient = gradient ??
        (gradientCard
            ? LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                stops: const [0.0, 0.55, 1.0],
                colors: [buyingStart, Color.lerp(buyingStart, buyingEnd, .55)!, buyingEnd],
              )
            : null);

    final card = AnimatedContainer(
      duration: AppDurations.normal,
      curve: Curves.easeOut,
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: cardGradient == null ? surface : null,
        gradient: cardGradient,
        borderRadius: radius,
        border: filled
            ? Border.all(
                color: gradientCard
                    ? colors.info.withValues(alpha: .30)
                    : colors.divider,
                width: 1,
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: gradientCard
                ? colors.info.withValues(alpha: .14)
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