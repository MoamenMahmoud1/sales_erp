import 'package:flutter/material.dart';

/// Central semantic color system used across the application.
///
/// Every widget reads colors from the active theme (via [Theme.of(context)])
/// rather than hardcoding raw values. Each [AppColors] instance holds the
/// full semantic palette for one of the three visual modes (light / mid / dark).
class AppColors {
  // Brand / primary
  final Color primary;
  final Color onPrimary;
  final Color primaryContainer;
  final Color onPrimaryContainer;
  final Color primaryDark;
  final Color primaryLight;

  // Secondary / muted brand
  final Color secondary;
  final Color onSecondary;

  // Warm accent (used for highlights & hero elements)
  final Color accent;
  final Color onAccent;
  final Color accentContainer;
  final Color onAccentContainer;

  // Semantic status colors
  final Color success;
  final Color onSuccess;
  final Color successContainer;
  final Color onSuccessContainer;
  final Color warning;
  final Color onWarning;
  final Color warningContainer;
  final Color onWarningContainer;
  final Color error;
  final Color onError;
  final Color errorContainer;
  final Color onErrorContainer;
  final Color info;
  final Color onInfo;
  final Color infoContainer;
  final Color onInfoContainer;

  // Surfaces
  final Color background;
  final Color surface;
  final Color surfaceElevated;
  final Color surfaceMuted;
  final Color scrim;

  // Lines
  final Color border;
  final Color divider;

  // Typography
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color textDisabled;

  const AppColors({
    required this.primary,
    required this.onPrimary,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.primaryDark,
    required this.primaryLight,
    required this.secondary,
    required this.onSecondary,
    required this.accent,
    required this.onAccent,
    required this.accentContainer,
    required this.onAccentContainer,
    required this.success,
    required this.onSuccess,
    required this.successContainer,
    required this.onSuccessContainer,
    required this.warning,
    required this.onWarning,
    required this.warningContainer,
    required this.onWarningContainer,
    required this.error,
    required this.onError,
    required this.errorContainer,
    required this.onErrorContainer,
    required this.info,
    required this.onInfo,
    required this.infoContainer,
    required this.onInfoContainer,
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.surfaceMuted,
    required this.scrim,
    required this.border,
    required this.divider,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.textDisabled,
});

  /// Smoothly interpolates every semantic color between two palettes.
  /// Used by the global theme transition so switching themes animates
  /// all colors coherently instead of cutting abruptly.
  static AppColors lerp(AppColors a, AppColors b, double t) {
    Color c(Color x, Color y) => Color.lerp(x, y, t)!;
    return AppColors(
      primary: c(a.primary, b.primary),
      onPrimary: c(a.onPrimary, b.onPrimary),
      primaryContainer: c(a.primaryContainer, b.primaryContainer),
      onPrimaryContainer: c(a.onPrimaryContainer, b.onPrimaryContainer),
      primaryDark: c(a.primaryDark, b.primaryDark),
      primaryLight: c(a.primaryLight, b.primaryLight),
      secondary: c(a.secondary, b.secondary),
      onSecondary: c(a.onSecondary, b.onSecondary),
      accent: c(a.accent, b.accent),
      onAccent: c(a.onAccent, b.onAccent),
      accentContainer: c(a.accentContainer, b.accentContainer),
      onAccentContainer: c(a.onAccentContainer, b.onAccentContainer),
      success: c(a.success, b.success),
      onSuccess: c(a.onSuccess, b.onSuccess),
      successContainer: c(a.successContainer, b.successContainer),
      onSuccessContainer: c(a.onSuccessContainer, b.onSuccessContainer),
      warning: c(a.warning, b.warning),
      onWarning: c(a.onWarning, b.onWarning),
      warningContainer: c(a.warningContainer, b.warningContainer),
      onWarningContainer: c(a.onWarningContainer, b.onWarningContainer),
      error: c(a.error, b.error),
      onError: c(a.onError, b.onError),
      errorContainer: c(a.errorContainer, b.errorContainer),
      onErrorContainer: c(a.onErrorContainer, b.onErrorContainer),
      info: c(a.info, b.info),
      onInfo: c(a.onInfo, b.onInfo),
      infoContainer: c(a.infoContainer, b.infoContainer),
      onInfoContainer: c(a.onInfoContainer, b.onInfoContainer),
      background: c(a.background, b.background),
      surface: c(a.surface, b.surface),
      surfaceElevated: c(a.surfaceElevated, b.surfaceElevated),
      surfaceMuted: c(a.surfaceMuted, b.surfaceMuted),
      scrim: c(a.scrim, b.scrim),
      border: c(a.border, b.border),
      divider: c(a.divider, b.divider),
      textPrimary: c(a.textPrimary, b.textPrimary),
      textSecondary: c(a.textSecondary, b.textSecondary),
      textMuted: c(a.textMuted, b.textMuted),
      textDisabled: c(a.textDisabled, b.textDisabled),
    );
  }

/// Light theme — deep premium GREEN + refined ivory/neutral surfaces.
  static const AppColors light = AppColors(
    primary: Color(0xFF356B57),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFD8E7DF),
    primaryDark: Color(0xFF23493C),
    primaryLight: Color(0xFF5B8D78),
    onPrimaryContainer: Color(0xFF123025),
    secondary: Color(0xFF596B61),
    onSecondary: Color(0xFFFFFFFF),
    accent: Color(0xFF596B61),
    onAccent: Color(0xFFFFFFFF),
    accentContainer: Color(0xFFDEE5E0),
    onAccentContainer: Color(0xFF222B25),
    success: Color(0xFF397052),
    onSuccess: Color(0xFFFFFFFF),
    successContainer: Color(0xFFDAEAE1),
    onSuccessContainer: Color(0xFF0F2E1E),
    warning: Color(0xFFA56F2A),
    onWarning: Color(0xFFFFFFFF),
    warningContainer: Color(0xFFF2E4CB),
    onWarningContainer: Color(0xFF3A2708),
    error: Color(0xFFA9444B),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFF3DBDD),
    onErrorContainer: Color(0xFF421114),
    info: Color(0xFF466F78),
    onInfo: Color(0xFFFFFFFF),
    infoContainer: Color(0xFFD9E8EB),
    onInfoContainer: Color(0xFF12282C),
    background: Color(0xFFF3F6F2),
    surface: Color(0xFFFBFDFC),
    surfaceElevated: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFE5ECE6),
    scrim: Color(0x66000000),
    border: Color(0xFFD0DAD3),
    divider: Color(0xFFDEE5E0),
    textPrimary: Color(0xFF202823),
    textSecondary: Color(0xFF505D55),
    textMuted: Color(0xFF7D8982),
    textDisabled: Color(0xFFAAB4AD),
  );
/// Mid theme — deep charcoal + rich PURPLE / plum / muted lavender.
  static const AppColors mid = AppColors(
    primary: Color(0xFF76559A),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFF4A3660),
    primaryDark: Color(0xFF60437F),
    primaryLight: Color(0xFF9A7BB8),
    onPrimaryContainer: Color(0xFFE9DCF5),
    secondary: Color(0xFF9587A5),
    onSecondary: Color(0xFF241D2B),
    accent: Color(0xFF9587A5),
    onAccent: Color(0xFF241D2B),
    accentContainer: Color(0xFF453D52),
    onAccentContainer: Color(0xFFE6DEEE),
    success: Color(0xFF629277),
    onSuccess: Color(0xFF0B2016),
    successContainer: Color(0xFF27402F),
    onSuccessContainer: Color(0xFFD9EBDF),
    warning: Color(0xFFC08A43),
    onWarning: Color(0xFF241804),
    warningContainer: Color(0xFF4A3A1B),
    onWarningContainer: Color(0xFFF2E3C8),
    error: Color(0xFFC96A70),
    onError: Color(0xFF2B090B),
    errorContainer: Color(0xFF4E2A2E),
    onErrorContainer: Color(0xFFF6DADC),
    info: Color(0xFF6C91A5),
    onInfo: Color(0xFF0C1B26),
    infoContainer: Color(0xFF2C4457),
    onInfoContainer: Color(0xFFD9E8F2),
    background: Color(0xFF24212A),
    surface: Color(0xFF2E2935),
    surfaceElevated: Color(0xFF383140),
    surfaceMuted: Color(0xFF433A4C),
    scrim: Color(0x99000000),
    border: Color(0xFF51485A),
    divider: Color(0xFF5D5266),
    textPrimary: Color(0xFFF8F5FA),
    textSecondary: Color(0xFFD8D0DE),
    textMuted: Color(0xFFA79CAA),
    textDisabled: Color(0xFF736A7D),
  );
/// Deep, sophisticated, near-black premium dark palette.
  static const AppColors dark = AppColors(
    primary: Color(0xFF3F639F),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFF263A5E),
    primaryDark: Color(0xFF304D7E),
    primaryLight: Color(0xFF6987BB),
    onPrimaryContainer: Color(0xFFD6E1F4),
    secondary: Color(0xFF697A98),
    onSecondary: Color(0xFF101724),
    accent: Color(0xFF697A98),
    onAccent: Color(0xFF101724),
    accentContainer: Color(0xFF2C3648),
    onAccentContainer: Color(0xFFD9E0EB),
    success: Color(0xFF60967A),
    onSuccess: Color(0xFF0B2016),
    successContainer: Color(0xFF243D2F),
    onSuccessContainer: Color(0xFFD8EBE0),
    warning: Color(0xFFC58E47),
    onWarning: Color(0xFF241804),
    warningContainer: Color(0xFF4C3B1E),
    onWarningContainer: Color(0xFFF3E5CA),
    error: Color(0xFFC96B72),
    onError: Color(0xFF2B090B),
    errorContainer: Color(0xFF4F2A30),
    onErrorContainer: Color(0xFFF7DBDD),
    info: Color(0xFF6590AD),
    onInfo: Color(0xFF0C1B26),
    infoContainer: Color(0xFF294254),
    onInfoContainer: Color(0xFFD9E9F3),
    background: Color(0xFF0E131B),
    surface: Color(0xFF151C27),
    surfaceElevated: Color(0xFF1D2633),
    surfaceMuted: Color(0xFF263242),
    scrim: Color(0xCC000000),
    border: Color(0xFF344150),
    divider: Color(0xFF3F4C5B),
    textPrimary: Color(0xFFF7F9FC),
    textSecondary: Color(0xFFD1D7E0),
    textMuted: Color(0xFF96A0AF),
    textDisabled: Color(0xFF5F6B7A),
  );

  /// Resolves the palette for the active theme via its [AppThemeExtension].
  static AppColors of(BuildContext context) {
    final extension = Theme.of(context).extension<AppThemeExtension>();
    return extension?.colors ?? light;
  }
}

/// Bridges the [AppColors] palette into Flutter's [ThemeExtension] system so
/// screens can resolve semantic colors without hardcoding values.
/// This is the SINGLE authoritative extension — its lerp performs real
/// per-color interpolation so theme transitions pass through intermediate
/// colors instead of snapping.
class AppThemeExtension extends ThemeExtension<AppThemeExtension> {
  const AppThemeExtension(this.colors);

  final AppColors colors;

  @override
  AppThemeExtension copyWith({AppColors? colors}) =>
      AppThemeExtension(colors ?? this.colors);

  @override
  AppThemeExtension lerp(AppThemeExtension? other, double t) {
    if (other == null) return this;
    return AppThemeExtension(AppColors.lerp(colors, other.colors, t));
  }
}