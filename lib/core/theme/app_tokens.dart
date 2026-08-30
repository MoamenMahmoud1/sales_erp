import 'package:flutter/material.dart';

/// Centralized spacing scale. Use these instead of scattered magic numbers.
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  static const EdgeInsets zero = EdgeInsets.zero;
  static const EdgeInsets screen = EdgeInsets.symmetric(horizontal: lg);
  static const EdgeInsets card = EdgeInsets.all(lg);
  static const EdgeInsets cardCompact = EdgeInsets.all(md);
}

/// Centralized border-radius scale.
class AppRadius {
  AppRadius._();

  static const double xs = 8;
  static const double sm = 10;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double sheet = 28;

  static BorderRadius xsAll = BorderRadius.circular(xs);
  static BorderRadius smAll = BorderRadius.circular(sm);
  static BorderRadius mdAll = BorderRadius.circular(md);
  static BorderRadius lgAll = BorderRadius.circular(lg);
  static BorderRadius xlAll = BorderRadius.circular(xl);
  static BorderRadius xxlAll = BorderRadius.circular(xxl);
  static BorderRadius sheetTop = const BorderRadius.vertical(
    top: Radius.circular(sheet),
  );
}

/// Centralized animation durations.
class AppDurations {
  AppDurations._();

  static const Duration fast = Duration(milliseconds: 160);
  static const Duration normal = Duration(milliseconds: 280);
  static const Duration slow = Duration(milliseconds: 520);
}

/// Centralized typography helpers layered on the active [TextTheme].
class AppTextStyles {
  AppTextStyles._();

  static TextStyle display(BuildContext context) => Theme.of(context)
      .textTheme
      .displaySmall!
      .copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5);

  static TextStyle headline(BuildContext context) =>
      Theme.of(context).textTheme.headlineMedium!.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          );

  static TextStyle title(BuildContext context) =>
      Theme.of(context)
          .textTheme
          .titleMedium!
          .copyWith(fontWeight: FontWeight.w600);

  static TextStyle body(BuildContext context) =>
      Theme.of(context).textTheme.bodyMedium!;

  static TextStyle label(BuildContext context) =>
      Theme.of(context)
          .textTheme
          .labelMedium!
          .copyWith(fontWeight: FontWeight.w600);

  static TextStyle caption(BuildContext context) =>
      Theme.of(context).textTheme.bodySmall!;

  /// Large, scannable numeric values (KPI hero, totals).
  static TextStyle numeric(
    BuildContext context, {
    double size = 28,
    FontWeight weight = FontWeight.w800,
  }) =>
      Theme.of(context).textTheme.headlineMedium!.copyWith(
            fontSize: size,
            fontWeight: weight,
            letterSpacing: -0.5,
            fontFeatures: const [FontFeature.tabularFigures()],
          );
}