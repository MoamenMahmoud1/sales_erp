import 'package:flutter/material.dart';

class AppTheme {
  static const _brand = Color(0xFF147D73);
  static const _accent = Color(0xFFE19A3E);

  static ThemeData light() => _build(
        Brightness.light,
        const Color(0xFFF7F9F8),
        const Color(0xFFFFFFFF),
      );

  static ThemeData mid() => _build(
      Brightness.dark,
      const Color(0xFF1D302E),
      const Color(0xFF29413E),
        mid: true,
      );

  static ThemeData dark() => _build(
        Brightness.dark,
        const Color(0xFF101A19),
        const Color(0xFF182523),
      );

  static ThemeData _build(
    Brightness brightness,
    Color scaffold,
    Color surface, {
    bool mid = false,
  }) {
    final scheme = ColorScheme.fromSeed(
      seedColor: mid ? const Color(0xFF356B67) : _brand,
      brightness: brightness,
      surface: surface,
    ).copyWith(
      secondary: _accent,
      surface: surface,
    );
    final base = ThemeData(
      colorScheme: scheme,
      brightness: brightness,
      useMaterial3: true,
      scaffoldBackgroundColor: scaffold,
    );
    return base.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: scaffold,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: brightness == Brightness.dark ? 0 : 1,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: .45),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
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
