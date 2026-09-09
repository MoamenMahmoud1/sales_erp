import 'package:flutter/material.dart';

/// Semantic colors shared across the Sales ERP application.
///
/// The palette uses a deep teal/ink brand with a restrained warm accent.
/// Product states keep their own semantic colors so branding never changes
/// the meaning of success, warning, error, or information.
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
      onWarning: mix(a.warning, b.warning),
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
    primary: Color(0xFF167174),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFD6EFED),
    onPrimaryContainer: Color(0xFF063B3D),
    primaryDark: Color(0xFF105B5D),
    primaryLight: Color(0xFF4F9596),
    secondary: Color(0xFF725945),
    onSecondary: Color(0xFFFFFFFF),
    accent: Color(0xFFC1814A),
    onAccent: Color(0xFFFFFFFF),
    accentContainer: Color(0xFFF4E0CC),
    onAccentContainer: Color(0xFF4A2B14),
    success: Color(0xFF2F7D5B),
    onSuccess: Color(0xFFFFFFFF),
    successContainer: Color(0xFFD9EEE5),
    onSuccessContainer: Color(0xFF103B2A),
    warning: Color(0xFFA86F25),
    onWarning: Color(0xFFFFFFFF),
    warningContainer: Color(0xFFF5E5C9),
    onWarningContainer: Color(0xFF462B0B),
    error: Color(0xFFB64B50),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFF5D9DA),
    onErrorContainer: Color(0xFF481719),
    info: Color(0xFF3E7185),
    onInfo: Color(0xFFFFFFFF),
    infoContainer: Color(0xFFDCEAF0),
    onInfoContainer: Color(0xFF143640),
    background: Color(0xFFF5F8F7),
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFFBFCFC),
    surfaceMuted: Color(0xFFEDF3F2),
    scrim: Color(0x66000000),
    border: Color(0xFFD1DEDD),
    divider: Color(0xFFE1E9E8),
    textPrimary: Color(0xFF203234),
    textSecondary: Color(0xFF536568),
    textMuted: Color(0xFF798B8D),
    textDisabled: Color(0xFFABB8B9),
  );

  static const AppColors mid = AppColors(
    primary: Color(0xFF53A7A7),
    onPrimary: Color(0xFF062D2E),
    primaryContainer: Color(0xFF26595A),
    onPrimaryContainer: Color(0xFFD5EFEE),
    primaryDark: Color(0xFF3E898A),
    primaryLight: Color(0xFF84C1C0),
    secondary: Color(0xFFB9A18C),
    onSecondary: Color(0xFF2B2118),
    accent: Color(0xFFD39A66),
    onAccent: Color(0xFF30200F),
    accentContainer: Color(0xFF58432C),
    onAccentContainer: Color(0xFFF2DEC8),
    success: Color(0xFF73BB96),
    onSuccess: Color(0xFF092517),
    successContainer: Color(0xFF2A4F3B),
    onSuccessContainer: Color(0xFFD8F0E4),
    warning: Color(0xFFD6A35D),
    onWarning: Color(0xFF30200B),
    warningContainer: Color(0xFF514127),
    onWarningContainer: Color(0xFFF4E5CC),
    error: Color(0xFFE08388),
    onError: Color(0xFF2C0C0F),
    errorContainer: Color(0xFF552E34),
    onErrorContainer: Color(0xFFF5D9DC),
    info: Color(0xFF81B6C8),
    onInfo: Color(0xFF0A272F),
    infoContainer: Color(0xFF2B4C57),
    onInfoContainer: Color(0xFFDDEDF2),
    background: Color(0xFF192729),
    surface: Color(0xFF223234),
    surfaceElevated: Color(0xFF2A3B3D),
    surfaceMuted: Color(0xFF314447),
    scrim: Color(0x99000000),
    border: Color(0xFF455A5C),
    divider: Color(0xFF53686A),
    textPrimary: Color(0xFFF2F7F6),
    textSecondary: Color(0xFFD1DEDC),
    textMuted: Color(0xFF9CA9A8),
    textDisabled: Color(0xFF6F7C7C),
  );

  static const AppColors dark = AppColors(
    primary: Color(0xFF69BCBB),
    onPrimary: Color(0xFF062B2D),
    primaryContainer: Color(0xFF1F5051),
    onPrimaryContainer: Color(0xFFD1EDEC),
    primaryDark: Color(0xFF4B9D9D),
    primaryLight: Color(0xFF91D0CD),
    secondary: Color(0xFFC5AA94),
    onSecondary: Color(0xFF2C1F16),
    accent: Color(0xFFD4A06D),
    onAccent: Color(0xFF2E2114),
    accentContainer: Color(0xFF4E3926),
    onAccentContainer: Color(0xFFF0DDC7),
    success: Color(0xFF6FC091),
    onSuccess: Color(0xFF082317),
    successContainer: Color(0xFF244533),
    onSuccessContainer: Color(0xFFD3EEDC),
    warning: Color(0xFFD4A15E),
    onWarning: Color(0xFF2C1D0A),
    warningContainer: Color(0xFF4B3A22),
    onWarningContainer: Color(0xFFF1E2C9),
    error: Color(0xFFD98288),
    onError: Color(0xFF2B0B0E),
    errorContainer: Color(0xFF49282E),
    onErrorContainer: Color(0xFFF2D8DB),
    info: Color(0xFF78B0C2),
    onInfo: Color(0xFF09242C),
    infoContainer: Color(0xFF274552),
    onInfoContainer: Color(0xFFD7EAF0),
    background: Color(0xFF0B1718),
    surface: Color(0xFF111F20),
    surfaceElevated: Color(0xFF17292A),
    surfaceMuted: Color(0xFF1E3334),
    scrim: Color(0xCC000000),
    border: Color(0xFF304747),
    divider: Color(0xFF395353),
    textPrimary: Color(0xFFF2F7F6),
    textSecondary: Color(0xFFC8D5D3),
    textMuted: Color(0xFF94A5A2),
    textDisabled: Color(0xFF5F706E),
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
