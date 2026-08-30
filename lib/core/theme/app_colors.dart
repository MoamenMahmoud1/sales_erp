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

/// Light theme — cool ivory + deep navy + muted indigo/purple.
  static const AppColors light = AppColors(
    primary: Color(0xFF344B8E),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFDDE3F5),
    onPrimaryContainer: Color(0xFF16224A),
    secondary: Color(0xFF625A86),
    onSecondary: Color(0xFFFFFFFF),
    accent: Color(0xFF625A86),
    onAccent: Color(0xFFFFFFFF),
    accentContainer: Color(0xFFE4E1F0),
    onAccentContainer: Color(0xFF241F3D),
    success: Color(0xFF34745A),
    onSuccess: Color(0xFFFFFFFF),
    successContainer: Color(0xFFD9EAE1),
    onSuccessContainer: Color(0xFF0E2E20),
    warning: Color(0xFFA56F2A),
    onWarning: Color(0xFFFFFFFF),
    warningContainer: Color(0xFFF2E4CB),
    onWarningContainer: Color(0xFF3A2708),
    error: Color(0xFFA9444B),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFF3DBDD),
    onErrorContainer: Color(0xFF421114),
    info: Color(0xFF3F6F8F),
    onInfo: Color(0xFFFFFFFF),
    infoContainer: Color(0xFFDAE7EF),
    onInfoContainer: Color(0xFF122B3B),
    background: Color(0xFFF4F6FA),
    surface: Color(0xFFFCFDFF),
    surfaceElevated: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFE8EBF2),
    scrim: Color(0x66000000),
    border: Color(0xFFD3D8E3),
    divider: Color(0xFFE1E4EB),
    textPrimary: Color(0xFF1D2433),
    textSecondary: Color(0xFF515A6B),
    textMuted: Color(0xFF7B8494),
    textDisabled: Color(0xFFA6ADBB),
  );
/// Mid theme — deep blue-charcoal + muted indigo + sophisticated violet.
  static const AppColors mid = AppColors(
    primary: Color(0xFF5E73C0),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFF2E3A66),
    onPrimaryContainer: Color(0xFFD6DEF7),
    secondary: Color(0xFF8A82AD),
    onSecondary: Color(0xFF161322),
    accent: Color(0xFF8A82AD),
    onAccent: Color(0xFF161322),
    accentContainer: Color(0xFF3A3752),
    onAccentContainer: Color(0xFFDCD8EC),
    success: Color(0xFF5E967A),
    onSuccess: Color(0xFF0B2016),
    successContainer: Color(0xFF254436),
    onSuccessContainer: Color(0xFFD6EBDF),
    warning: Color(0xFFC08B43),
    onWarning: Color(0xFF241804),
    warningContainer: Color(0xFF4A3A1B),
    onWarningContainer: Color(0xFFF2E3C8),
    error: Color(0xFFC96A70),
    onError: Color(0xFF2B090B),
    errorContainer: Color(0xFF4E2A2E),
    onErrorContainer: Color(0xFFF6DADC),
    info: Color(0xFF6792AE),
    onInfo: Color(0xFF0C1B26),
    infoContainer: Color(0xFF2C4457),
    onInfoContainer: Color(0xFFD9E8F2),
    background: Color(0xFF20232D),
    surface: Color(0xFF292D39),
    surfaceElevated: Color(0xFF323746),
    surfaceMuted: Color(0xFF3B4050),
    scrim: Color(0x99000000),
    border: Color(0xFF484E5D),
    divider: Color(0xFF525866),
    textPrimary: Color(0xFFF7F8FC),
    textSecondary: Color(0xFFD1D5E0),
    textMuted: Color(0xFF9BA2B2),
    textDisabled: Color(0xFF6A7181),
  );
/// Deep, sophisticated, near-black premium dark palette.
  static const AppColors dark = AppColors(
    primary: Color(0xFF7185D1),
    onPrimary: Color(0xFF0A1029),
    primaryContainer: Color(0xFF2B3663),
    onPrimaryContainer: Color(0xFFDDE4FA),
    secondary: Color(0xFF9189B7),
    onSecondary: Color(0xFF141126),
    accent: Color(0xFF9189B7),
    onAccent: Color(0xFF141126),
    accentContainer: Color(0xFF3C3954),
    onAccentContainer: Color(0xFFE0DCEF),
    success: Color(0xFF619A7D),
    onSuccess: Color(0xFF0B2016),
    successContainer: Color(0xFF274636),
    onSuccessContainer: Color(0xFFDAEEE2),
    warning: Color(0xFFC59047),
    onWarning: Color(0xFF241804),
    warningContainer: Color(0xFF4C3B1E),
    onWarningContainer: Color(0xFFF3E5CA),
    error: Color(0xFFC96B72),
    onError: Color(0xFF2B090B),
    errorContainer: Color(0xFF4F2A30),
    onErrorContainer: Color(0xFFF7DBDD),
    info: Color(0xFF6B94AE),
    onInfo: Color(0xFF0C1B26),
    infoContainer: Color(0xFF2C4457),
    onInfoContainer: Color(0xFFDAE9F3),
    background: Color(0xFF0F1118),
    surface: Color(0xFF171A24),
    surfaceElevated: Color(0xFF202431),
    surfaceMuted: Color(0xFF292D3B),
    scrim: Color(0xCC000000),
    border: Color(0xFF363B4A),
    divider: Color(0xFF414756),
    textPrimary: Color(0xFFF8F9FD),
    textSecondary: Color(0xFFD5D8E3),
    textMuted: Color(0xFF969EAF),
    textDisabled: Color(0xFF62687A),
  );

  /// Resolves the palette for the active theme via its [AppThemeExtension].
  static AppColors of(BuildContext context) {
    final extension = Theme.of(context).extension<AppThemeExtension>();
    return extension?.colors ?? light;
  }
}

/// Bridges the [AppColors] palette into Flutter's [ThemeExtension] system so
/// screens can resolve semantic colors without hardcoding values.
class AppThemeExtension extends ThemeExtension<AppThemeExtension> {
  const AppThemeExtension(this.colors);

  final AppColors colors;

  @override
  AppThemeExtension copyWith({AppColors? colors}) =>
      AppThemeExtension(colors ?? this.colors);

  @override
  AppThemeExtension lerp(AppThemeExtension? other, double t) {
    if (other == null) return this;
    return t < 0.5 ? this : other;
  }
}