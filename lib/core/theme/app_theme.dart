import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_tokens.dart';

/// Surfaces the active [AppColors] palette through the theme so any widget
/// can resolve semantic colors via `AppColors.of(context)`.
class AppThemeExtension extends ThemeExtension<AppThemeExtension> {
  final AppColors colors;
  const AppThemeExtension(this.colors);

  @override
  AppThemeExtension copyWith({AppColors? colors}) {
    return AppThemeExtension(colors ?? this.colors);
  }

  @override
  AppThemeExtension lerp(covariant AppThemeExtension? other, double t) {
    if (other == null) return this;
    return AppThemeExtension(AppColors.lerp(colors, other.colors, t));
  }
}

/// Builds the three visual modes (light / mid / dark) on top of the semantic
/// [AppColors] palettes and shared design tokens.
class AppTheme {
  static ThemeData light() => _build(AppColors.light, Brightness.light);
  static ThemeData mid() => _build(AppColors.mid, Brightness.dark);
  static ThemeData dark() => _build(AppColors.dark, Brightness.dark);

  static ThemeData _build(AppColors c, Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: c.primary,
      brightness: brightness,
    ).copyWith(
      primary: c.primary,
      onPrimary: c.onPrimary,
      primaryContainer: c.primaryContainer,
      onPrimaryContainer: c.onPrimaryContainer,
      secondary: c.accent,
      onSecondary: c.onAccent,
      secondaryContainer: c.accentContainer,
      onSecondaryContainer: c.onAccentContainer,
      tertiary: c.secondary,
      onTertiary: c.onSecondary,
      error: c.error,
      onError: c.onError,
      errorContainer: c.errorContainer,
      onErrorContainer: c.onErrorContainer,
      surface: c.surface,
      onSurface: c.textPrimary,
      surfaceContainerHighest: c.surfaceElevated,
      surfaceContainerHigh: c.surfaceElevated,
      surfaceContainer: c.surface,
      surfaceContainerLow: c.surfaceMuted,
      surfaceContainerLowest: c.background,
      outline: c.border,
      outlineVariant: c.divider,
      scrim: c.scrim,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.background,
    );

    final inputDecoration = InputDecorationTheme(
      filled: true,
      fillColor: c.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 14),
      hintStyle: TextStyle(color: c.textMuted, fontSize: 15),
      labelStyle: TextStyle(color: c.textSecondary, fontSize: 15),
      floatingLabelStyle: TextStyle(color: c.primary, fontWeight: FontWeight.w600),
      prefixIconColor: c.textMuted,
      suffixIconColor: c.textMuted,
      border: OutlineInputBorder(borderRadius: AppRadius.mdAll, borderSide: BorderSide(color: c.border)),
      enabledBorder: OutlineInputBorder(borderRadius: AppRadius.mdAll, borderSide: BorderSide(color: c.border)),
      focusedBorder: OutlineInputBorder(borderRadius: AppRadius.mdAll, borderSide: BorderSide(color: c.primary, width: 2)),
      errorBorder: OutlineInputBorder(borderRadius: AppRadius.mdAll, borderSide: BorderSide(color: c.error)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: AppRadius.mdAll, borderSide: BorderSide(color: c.error, width: 2)),
      errorStyle: TextStyle(color: c.error),
    );

    final radius = AppRadius.lgAll;
    final border = BorderSide(color: c.border);

    return base.copyWith(
      extensions: [AppThemeExtension(c)],
      splashFactory: InkSparkle.splashFactory,
      textTheme: base.textTheme.apply(bodyColor: c.textPrimary, displayColor: c.textPrimary),
      appBarTheme: AppBarTheme(
        backgroundColor: c.background,
        foregroundColor: c.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: c.textPrimary),
        iconTheme: IconThemeData(color: c.textSecondary),
      ),
      dividerTheme: DividerThemeData(color: c.divider, thickness: 1, space: 1),
      cardTheme: CardThemeData(
        color: c.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: radius, side: BorderSide(color: c.divider, width: 1)),
      ),
      inputDecorationTheme: inputDecoration,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 50),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 50),
          side: border,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
          foregroundColor: c.textPrimary,
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: c.primary, shape: RoundedRectangleBorder(borderRadius: AppRadius.smAll), textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
      ),
      iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(foregroundColor: c.textSecondary)),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: c.surfaceMuted,
        disabledColor: c.surfaceMuted,
        selectedColor: c.primaryContainer,
        labelStyle: TextStyle(color: c.textSecondary, fontWeight: FontWeight.w600),
        secondaryLabelStyle: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.xlAll, side: BorderSide(color: c.border)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: c.primary,
        foregroundColor: c.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
        elevation: 4,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: c.primary, linearTrackColor: c.primaryContainer),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.surfaceElevated,
        contentTextStyle: TextStyle(color: c.textPrimary),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll, side: BorderSide(color: c.divider)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.xlAll),
        titleTextStyle: base.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: c.textPrimary),
        contentTextStyle: base.textTheme.bodyMedium?.copyWith(color: c.textSecondary),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet))),
        showDragHandle: true,
        dragHandleColor: c.divider,
      ),
      listTileTheme: ListTileThemeData(iconColor: c.textSecondary, textColor: c.textPrimary, subtitleTextStyle: TextStyle(color: c.textMuted)),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? c.onPrimary : c.surface),
        trackColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? c.primary : c.surfaceMuted),
      ),
    );
  }
}

enum AppThemeMode { light, mid, dark }

class AppThemeController extends ChangeNotifier {
  AppThemeMode mode = AppThemeMode.mid;

  void setMode(AppThemeMode value) {
    if (mode == value) return;
    mode = value;
    notifyListeners();
  }
}
