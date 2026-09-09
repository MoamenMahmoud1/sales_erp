import 'package:flutter/material.dart';

/// Semantic colors shared across the Sales ERP application.
///
/// Base theme palettes stay independent. Featured dashboard colors are also
/// theme-specific: each mode gets its own strong variant of its own primary
/// color, so the featured card follows the active theme without becoming a
/// shared accent across all modes.
class AppColors {
  final Color primary;
  final Color onPrimary;
  final Color primaryContainer;
  final Color onPrimaryContainer;
  final Color primaryDark;
  final Color primaryLight;

  final Color secondary;
  final Color onSecondary;
  final Color accent;
  final Color onAccent;
  final Color accentContainer;
  final Color onAccentContainer;

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

  final Color background;
  final Color surface;
  final Color surfaceElevated;
  final Color surfaceMuted;
  final Color scrim;

  final Color border;
  final Color divider;

  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color textDisabled;

  final Color heroStart;
  final Color heroMiddle;
  final Color heroEnd;
  final Color heroHighlight;

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
    required this.heroStart,
    required this.heroMiddle,
    required this.heroEnd,
    required this.heroHighlight,
  });

  static AppColors lerp(AppColors a, AppColors b, double t) {
    Color mix(Color first, Color second) => Color.lerp(first, second, t)!;

    return AppColors(
      primary: mix(a.primary, b.primary),
      onPrimary: mix(a.onPrimary, b.onPrimary),
      primaryContainer: mix(a.primaryContainer, b.primaryContainer),
      onPrimaryContainer: mix(a.onPrimaryContainer, b.onPrimaryContainer),
      primaryDark: mix(a.primaryDark, b.primaryDark),
      primaryLight: mix(a.primaryLight, b.primaryLight),
      secondary: mix(a.secondary, b.secondary),
      onSecondary: mix(a.onSecondary, b.onSecondary),
      accent: mix(a.accent, b.accent),
      onAccent: mix(a.onAccent, b.onAccent),
      accentContainer: mix(a.accentContainer, b.accentContainer),
      onAccentContainer: mix(a.onAccentContainer, b.onAccentContainer),
      success: mix(a.success, b.success),
      onSuccess: mix(a.onSuccess, b.onSuccess),
      successContainer: mix(a.successContainer, b.successContainer),
      onSuccessContainer: mix(a.onSuccessContainer, b.onSuccessContainer),
      warning: mix(a.warning, b.warning),
      onWarning: mix(a.onWarning, b.onWarning),
      warningContainer: mix(a.warningContainer, b.warningContainer),
      onWarningContainer: mix(a.onWarningContainer, b.onWarningContainer),
      error: mix(a.error, b.error),
      onError: mix(a.onError, b.onError),
      errorContainer: mix(a.errorContainer, b.errorContainer),
      onErrorContainer: mix(a.onErrorContainer, b.onErrorContainer),
      info: mix(a.info, b.info),
      onInfo: mix(a.onInfo, b.onInfo),
      infoContainer: mix(a.infoContainer, b.infoContainer),
      onInfoContainer: mix(a.onInfoContainer, b.onInfoContainer),
      background: mix(a.background, b.background),
      surface: mix(a.surface, b.surface),
      surfaceElevated: mix(a.surfaceElevated, b.surfaceElevated),
      surfaceMuted: mix(a.surfaceMuted, b.surfaceMuted),
      scrim: mix(a.scrim, b.scrim),
      border: mix(a.border, b.border),
      divider: mix(a.divider, b.divider),
      textPrimary: mix(a.textPrimary, b.textPrimary),
      textSecondary: mix(a.textSecondary, b.textSecondary),
      textMuted: mix(a.textMuted, b.textMuted),
      textDisabled: mix(a.textDisabled, b.textDisabled),
      heroStart: mix(a.heroStart, b.heroStart),
      heroMiddle: mix(a.heroMiddle, b.heroMiddle),
      heroEnd: mix(a.heroEnd, b.heroEnd),
      heroHighlight: mix(a.heroHighlight, b.heroHighlight),
    );
  }

  static const AppColors light = AppColors(
    primary: Color(0xFF356B57),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFD8E7DF),
    onPrimaryContainer: Color(0xFF123025),
    primaryDark: Color(0xFF23493C),
    primaryLight: Color(0xFF5B8D78),
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
    heroStart: Color(0xFF23493C),
    heroMiddle: Color(0xFF356B57),
    heroEnd: Color(0xFF5B8D78),
    heroHighlight: Color(0xFFF7FFFB),
  );

  static const AppColors mid = AppColors(
    primary: Color(0xFF76559A),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFF4A3660),
    onPrimaryContainer: Color(0xFFE9DCF5),
    primaryDark: Color(0xFF60437F),
    primaryLight: Color(0xFF9A7BB8),
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
    heroStart: Color(0xFF49336A),
    heroMiddle: Color(0xFF76559A),
    heroEnd: Color(0xFFA789C1),
    heroHighlight: Color(0xFFFAF7FF),
  );

  static const AppColors dark = AppColors(
    primary: Color(0xFF3F639F),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFF263A5E),
    onPrimaryContainer: Color(0xFFD6E1F4),
    primaryDark: Color(0xFF304D7E),
    primaryLight: Color(0xFF6987BB),
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
    heroStart: Color(0xFF05285E),
    heroMiddle: Color(0xFF08428C),
    heroEnd: Color(0xFF3976B8),
    heroHighlight: Color(0xFFF2F8FF),
  );

  static AppColors of(BuildContext context) {
    final extension = Theme.of(context).extension<AppThemeExtension>();
    return extension?.colors ?? light;
  }
}

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
