import 'package:flutter/material.dart';

/// Semantic colors shared across the Sales ERP application.
///
/// The brand uses a deep teal base with a restrained slate secondary and a
/// muted coral accent. Light, mid, and dark modes stay visually related while
/// status colors remain independent so color always communicates meaning.
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
    primary: Color(0xFF266F70),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFD7EEEC),
    onPrimaryContainer: Color(0xFF093C3D),
    primaryDark: Color(0xFF1B5A5B),
    primaryLight: Color(0xFF5B9695),
    secondary: Color(0xFF5B6F80),
    onSecondary: Color(0xFFFFFFFF),
    accent: Color(0xFFB96568),
    onAccent: Color(0xFFFFFFFF),
    accentContainer: Color(0xFFF3DCDD),
    onAccentContainer: Color(0xFF481B1D),
    success: Color(0xFF2F7B5D),
    onSuccess: Color(0xFFFFFFFF),
    successContainer: Color(0xFFD9EEE5),
    onSuccessContainer: Color(0xFF103B2B),
    warning: Color(0xFFA96D25),
    onWarning: Color(0xFFFFFFFF),
    warningContainer: Color(0xFFF4E5CB),
    onWarningContainer: Color(0xFF43290B),
    error: Color(0xFFB64B50),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFF4DADB),
    onErrorContainer: Color(0xFF461719),
    info: Color(0xFF3F7187),
    onInfo: Color(0xFFFFFFFF),
    infoContainer: Color(0xFFDCEAF0),
    onInfoContainer: Color(0xFF17353F),
    background: Color(0xFFF5F8F7),
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFFBFCFC),
    surfaceMuted: Color(0xFFECF2F1),
    scrim: Color(0x66000000),
    border: Color(0xFFCFDCDC),
    divider: Color(0xFFE0E8E7),
    textPrimary: Color(0xFF203234),
    textSecondary: Color(0xFF526568),
    textMuted: Color(0xFF78898C),
    textDisabled: Color(0xFFAAB7B8),
  );

  static const AppColors mid = AppColors(
    primary: Color(0xFF5DA9A6),
    onPrimary: Color(0xFF092D2D),
    primaryContainer: Color(0xFF285A5B),
    onPrimaryContainer: Color(0xFFD6EEEC),
    primaryDark: Color(0xFF438985),
    primaryLight: Color(0xFF85C2BF),
    secondary: Color(0xFFA1AFBD),
    onSecondary: Color(0xFF172028),
    accent: Color(0xFFD58A8C),
    onAccent: Color(0xFF30171A),
    accentContainer: Color(0xFF5A383A),
    onAccentContainer: Color(0xFFF1DADC),
    success: Color(0xFF76B996),
    onSuccess: Color(0xFF082316),
    successContainer: Color(0xFF2A4D3A),
    onSuccessContainer: Color(0xFFD9EF E4),
    warning: Color(0xFFD3A25E),
    onWarning: Color(0xFF2D1D0B),
    warningContainer: Color(0xFF504026),
    onWarningContainer: Color(0xFFF4E5CC),
    error: Color(0xFFE08388),
    onError: Color(0xFF2A0B0E),
    errorContainer: Color(0xFF542F34),
    onErrorContainer: Color(0xFFF5DADD),
    info: Color(0xFF82B6C9),
    onInfo: Color(0xFF0A262E),
    infoContainer: Color(0xFF2B4C58),
    onInfoContainer: Color(0xFFDCECF2),
    background: Color(0xFF202C2E),
    surface: Color(0xFF293739),
    surfaceElevated: Color(0xFF324346),
    surfaceMuted: Color(0xFF3A4C4E),
    scrim: Color(0x99000000),
    border: Color(0xFF465B5D),
    divider: Color(0xFF536A6C),
    textPrimary: Color(0xFFF1F7F6),
    textSecondary: Color(0xFFD1DDDC),
    textMuted: Color(0xFF9BAAA9),
    textDisabled: Color(0xFF6F7D7C),
  );

  static const AppColors dark = AppColors(
    primary: Color(0xFF72C1BE),
    onPrimary: Color(0xFF09282A),
    primaryContainer: Color(0xFF225252),
    onPrimaryContainer: Color(0xFFD3ECEA),
    primaryDark: Color(0xFF519A98),
    primaryLight: Color(0xFF98D3D0),
    secondary: Color(0xFF98A8B9),
    onSecondary: Color(0xFF111A22),
    accent: Color(0xFFD38286),
    onAccent: Color(0xFF2D1114),
    accentContainer: Color(0xFF4B2E32),
    onAccentContainer: Color(0xFFF2D7D9),
    success: Color(0xFF74BD95),
    onSuccess: Color(0xFF082216),
    successContainer: Color(0xFF244532),
    onSuccessContainer: Color(0xFFD4EDDF),
    warning: Color(0xFFD19E5A),
    onWarning: Color(0xFF2A1B08),
    warningContainer: Color(0xFF49381F),
    onWarningContainer: Color(0xFFF1E2C8),
    error: Color(0xFFD27D83),
    onError: Color(0xFF2B0B0E),
    errorContainer: Color(0xFF48292E),
    onErrorContainer: Color(0xFFF2D9DC),
    info: Color(0xFF7FB3C7),
    onInfo: Color(0xFF09242C),
    infoContainer: Color(0xFF274551),
    onInfoContainer: Color(0xFFD8EAF0),
    background: Color(0xFF0D1719),
    surface: Color(0xFF142022),
    surfaceElevated: Color(0xFF1B2A2D),
    surfaceMuted: Color(0xFF233437),
    scrim: Color(0xCC000000),
    border: Color(0xFF33474A),
    divider: Color(0xFF3E5558),
    textPrimary: Color(0xFFF2F7F6),
    textSecondary: Color(0xFFC7D4D3),
    textMuted: Color(0xFF91A3A1),
    textDisabled: Color(0xFF5F706F),
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
