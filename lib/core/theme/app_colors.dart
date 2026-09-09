import 'package:flutter/material.dart';

/// Semantic colors shared across the Sales ERP application.
///
/// Each visual mode has its own tonal identity while status colors remain
/// semantic. Dashboard hero colors are intentionally part of the theme so
/// the distinctive card adapts with the active mode instead of using fixed
/// presentation colors.
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
    primary: Color(0xFF1E7471),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFD6EFEC),
    onPrimaryContainer: Color(0xFF073D3C),
    primaryDark: Color(0xFF125B58),
    primaryLight: Color(0xFF4B9993),
    secondary: Color(0xFF5E7283),
    onSecondary: Color(0xFFFFFFFF),
    accent: Color(0xFF526FA5),
    onAccent: Color(0xFFFFFFFF),
    accentContainer: Color(0xFFDCE4F1),
    onAccentContainer: Color(0xFF1C2E4A),
    success: Color(0xFF2E7A5B),
    onSuccess: Color(0xFFFFFFFF),
    successContainer: Color(0xFFD9EEE5),
    onSuccessContainer: Color(0xFF103B2B),
    warning: Color(0xFFA76D27),
    onWarning: Color(0xFFFFFFFF),
    warningContainer: Color(0xFFF3E4CA),
    onWarningContainer: Color(0xFF43290B),
    error: Color(0xFFB64B50),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFF4DADB),
    onErrorContainer: Color(0xFF461719),
    info: Color(0xFF3F7187),
    onInfo: Color(0xFFFFFFFF),
    infoContainer: Color(0xFFDCEAF0),
    onInfoContainer: Color(0xFF17353F),
    background: Color(0xFFF4F8F7),
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFFBFCFC),
    surfaceMuted: Color(0xFFEBF2F1),
    scrim: Color(0x66000000),
    border: Color(0xFFCFDCDC),
    divider: Color(0xFFE0E8E7),
    textPrimary: Color(0xFF203234),
    textSecondary: Color(0xFF526568),
    textMuted: Color(0xFF78898C),
    textDisabled: Color(0xFFAAB7B8),
    heroStart: Color(0xFF3F9FC5),
    heroMiddle: Color(0xFF126E99),
    heroEnd: Color(0xFF073F68),
    heroHighlight: Color(0xFFD8F5FF),
  );

  static const AppColors mid = AppColors(
    primary: Color(0xFF35A894),
    onPrimary: Color(0xFF062A24),
    primaryContainer: Color(0xFF225A4F),
    onPrimaryContainer: Color(0xFFD3EFE8),
    primaryDark: Color(0xFF207D6D),
    primaryLight: Color(0xFF72C9B5),
    secondary: Color(0xFF69B6C5),
    onSecondary: Color(0xFF082630),
    accent: Color(0xFF67BCD1),
    onAccent: Color(0xFF06262D),
    accentContainer: Color(0xFF295866),
    onAccentContainer: Color(0xFFD8EEF4),
    success: Color(0xFF70C29D),
    onSuccess: Color(0xFF082419),
    successContainer: Color(0xFF28503D),
    onSuccessContainer: Color(0xFFD8F0E4),
    warning: Color(0xFFD2A15E),
    onWarning: Color(0xFF2D1D0A),
    warningContainer: Color(0xFF514026),
    onWarningContainer: Color(0xFFF3E5CC),
    error: Color(0xFFE08088),
    onError: Color(0xFF2A0A0E),
    errorContainer: Color(0xFF542E34),
    onErrorContainer: Color(0xFFF5D9DD),
    info: Color(0xFF75B7CC),
    onInfo: Color(0xFF09262E),
    infoContainer: Color(0xFF2A4D5A),
    onInfoContainer: Color(0xFFDDEEF3),
    background: Color(0xFF162A29),
    surface: Color(0xFF203736),
    surfaceElevated: Color(0xFF2A4543),
    surfaceMuted: Color(0xFF324E4C),
    scrim: Color(0x99000000),
    border: Color(0xFF435D5A),
    divider: Color(0xFF526E6B),
    textPrimary: Color(0xFFF0F7F5),
    textSecondary: Color(0xFFD0DDDB),
    textMuted: Color(0xFF9AA9A8),
    textDisabled: Color(0xFF6E7E7D),
    heroStart: Color(0xFF1AB1A0),
    heroMiddle: Color(0xFF087A63),
    heroEnd: Color(0xFF053F3A),
    heroHighlight: Color(0xFFC9F2EA),
  );

  static const AppColors dark = AppColors(
    primary: Color(0xFF5CAFCF),
    onPrimary: Color(0xFF061E27),
    primaryContainer: Color(0xFF1B4E60),
    onPrimaryContainer: Color(0xFFD3EDF5),
    primaryDark: Color(0xFF3C91AE),
    primaryLight: Color(0xFF86C9DC),
    secondary: Color(0xFF69A6C1),
    onSecondary: Color(0xFF071F27),
    accent: Color(0xFF6DB0C7),
    onAccent: Color(0xFF08242B),
    accentContainer: Color(0xFF294A57),
    onAccentContainer: Color(0xFFD8EDF3),
    success: Color(0xFF6EC08E),
    onSuccess: Color(0xFF062116),
    successContainer: Color(0xFF224333),
    onSuccessContainer: Color(0xFFD1EDE0),
    warning: Color(0xFFD29D56),
    onWarning: Color(0xFF291A07),
    warningContainer: Color(0xFF48371D),
    onWarningContainer: Color(0xFFF0E0C6),
    error: Color(0xFFD57D85),
    onError: Color(0xFF280B0E),
    errorContainer: Color(0xFF48282E),
    onErrorContainer: Color(0xFFF1D8DB),
    info: Color(0xFF6FAFC4),
    onInfo: Color(0xFF08232A),
    infoContainer: Color(0xFF24424E),
    onInfoContainer: Color(0xFFD7EAF0),
    background: Color(0xFF071426),
    surface: Color(0xFF0F1E31),
    surfaceElevated: Color(0xFF172940),
    surfaceMuted: Color(0xFF213852),
    scrim: Color(0xCC000000),
    border: Color(0xFF2E4762),
    divider: Color(0xFF395572),
    textPrimary: Color(0xFFF1F7F9),
    textSecondary: Color(0xFFC7D7DF),
    textMuted: Color(0xFF90A6B2),
    textDisabled: Color(0xFF5C6F7B),
    heroStart: Color(0xFF1559A8),
    heroMiddle: Color(0xFF08428C),
    heroEnd: Color(0xFF04285E),
    heroHighlight: Color(0xFFC1E2FF),
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
