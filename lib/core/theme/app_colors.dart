import 'package:flutter/material.dart';

/// Semantic color palette shared by every Sales ERP feature.
///
/// Brand colors stay in one restrained blue-teal family across light, mid,
/// and dark modes. Status colors communicate meaning independently of the
/// brand, and surfaces/lines remain neutral so business data stays dominant.
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
    );
  }

  static const AppColors light = AppColors(
    primary: Color(0xFF356A82),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFD9EAF1),
    onPrimaryContainer: Color(0xFF0D2C39),
    primaryDark: Color(0xFF2A596F),
    primaryLight: Color(0xFF5A879D),
    secondary: Color(0xFF60727C),
    onSecondary: Color(0xFFFFFFFF),
    accent: Color(0xFF60727C),
    onAccent: Color(0xFFFFFFFF),
    accentContainer: Color(0xFFE0E7EA),
    onAccentContainer: Color(0xFF202B31),
    success: Color(0xFF3F7C60),
    onSuccess: Color(0xFFFFFFFF),
    successContainer: Color(0xFFDCECE4),
    onSuccessContainer: Color(0xFF123525),
    warning: Color(0xFF9B6D34),
    onWarning: Color(0xFFFFFFFF),
    warningContainer: Color(0xFFF2E4CF),
    onWarningContainer: Color(0xFF3A270D),
    error: Color(0xFFB84F58),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFF3DADD),
    onErrorContainer: Color(0xFF45161A),
    info: Color(0xFF42738B),
    onInfo: Color(0xFFFFFFFF),
    infoContainer: Color(0xFFDCEAF0),
    onInfoContainer: Color(0xFF17323E),
    background: Color(0xFFF5F7F8),
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFEEF2F4),
    scrim: Color(0x66000000),
    border: Color(0xFFD0DADF),
    divider: Color(0xFFE1E6E9),
    textPrimary: Color(0xFF1F2D35),
    textSecondary: Color(0xFF4C5C65),
    textMuted: Color(0xFF74838C),
    textDisabled: Color(0xFFA9B3B9),
  );

  static const AppColors mid = AppColors(
    primary: Color(0xFF7FAEC2),
    onPrimary: Color(0xFF0A2029),
    primaryContainer: Color(0xFF2D5363),
    onPrimaryContainer: Color(0xFFE0F0F5),
    primaryDark: Color(0xFF5D91A7),
    primaryLight: Color(0xFFA7CDDA),
    secondary: Color(0xFFA5B5BC),
    onSecondary: Color(0xFF152027),
    accent: Color(0xFFA5B5BC),
    onAccent: Color(0xFF152027),
    accentContainer: Color(0xFF3C4B54),
    onAccentContainer: Color(0xFFE1E8EC),
    success: Color(0xFF78B395),
    onSuccess: Color(0xFF0C2419),
    successContainer: Color(0xFF294936),
    onSuccessContainer: Color(0xFFDDF0E6),
    warning: Color(0xFFD2A66A),
    onWarning: Color(0xFF2D1E0B),
    warningContainer: Color(0xFF4B3B22),
    onWarningContainer: Color(0xFFF3E5CC),
    error: Color(0xFFD47F87),
    onError: Color(0xFF2A0B0F),
    errorContainer: Color(0xFF533039),
    onErrorContainer: Color(0xFFF6DBDF),
    info: Color(0xFF80ACC3),
    onInfo: Color(0xFF0B2029),
    infoContainer: Color(0xFF304C5A),
    onInfoContainer: Color(0xFFDDECF2),
    background: Color(0xFF20292F),
    surface: Color(0xFF29343B),
    surfaceElevated: Color(0xFF323E46),
    surfaceMuted: Color(0xFF3A474F),
    scrim: Color(0x99000000),
    border: Color(0xFF4D5B64),
    divider: Color(0xFF56646D),
    textPrimary: Color(0xFFF3F6F8),
    textSecondary: Color(0xFFD1DBE0),
    textMuted: Color(0xFF9BA9B1),
    textDisabled: Color(0xFF6F7C84),
  );

  static const AppColors dark = AppColors(
    primary: Color(0xFF80B9D0),
    onPrimary: Color(0xFF0A1D25),
    primaryContainer: Color(0xFF284A5A),
    onPrimaryContainer: Color(0xFFDBEDF4),
    primaryDark: Color(0xFF5A91A8),
    primaryLight: Color(0xFFA6D0DF),
    secondary: Color(0xFF9AADB5),
    onSecondary: Color(0xFF111C22),
    accent: Color(0xFF9AADB5),
    onAccent: Color(0xFF111C22),
    accentContainer: Color(0xFF2D3A42),
    onAccentContainer: Color(0xFFDDE7EB),
    success: Color(0xFF78B395),
    onSuccess: Color(0xFF0A2016),
    successContainer: Color(0xFF263F31),
    onSuccessContainer: Color(0xFFD9EEE3),
    warning: Color(0xFFD0A064),
    onWarning: Color(0xFF2B1C08),
    warningContainer: Color(0xFF48381E),
    onWarningContainer: Color(0xFFF0E1C8),
    error: Color(0xFFD27B83),
    onError: Color(0xFF2B0B0E),
    errorContainer: Color(0xFF4D2A31),
    onErrorContainer: Color(0xFFF5D9DD),
    info: Color(0xFF7FAEC4),
    onInfo: Color(0xFF0A2029),
    infoContainer: Color(0xFF294654),
    onInfoContainer: Color(0xFFD9EAF1),
    background: Color(0xFF0E151B),
    surface: Color(0xFF151E25),
    surfaceElevated: Color(0xFF1D2831),
    surfaceMuted: Color(0xFF25323B),
    scrim: Color(0xCC000000),
    border: Color(0xFF34434D),
    divider: Color(0xFF40505A),
    textPrimary: Color(0xFFF5F8FA),
    textSecondary: Color(0xFFD1D9DE),
    textMuted: Color(0xFF98A5AD),
    textDisabled: Color(0xFF616E77),
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
