import 'package:flutter/material.dart';
import 'app_colors.dart';

// Ported from ui/theme/Theme.kt + Type.kt
// dynamicColor is intentionally not offered (kept false in the original)
// so the brand green always shows.
class EkrushiTheme {
  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: leafGreen40,
      brightness: Brightness.light,
      primary: leafGreen40,
      onPrimary: Colors.white,
      primaryContainer: leafGreen80,
      secondary: soil40,
      secondaryContainer: soil80,
      tertiary: amber,
      error: redColor,
      background: backgroundColor,
      surface: surfaceLight,
      onSurface: onSurfaceDark,
    );

    return _buildTheme(colorScheme);
  }

  static ThemeData dark() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: leafGreen80,
      brightness: Brightness.dark,
      primary: leafGreen80,
      secondary: soil80,
      tertiary: amber,
      error: redColor,
    );

    return _buildTheme(colorScheme);
  }

  static ThemeData _buildTheme(ColorScheme colorScheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.background,
      textTheme: const TextTheme(
        headlineMedium: TextStyle(fontWeight: FontWeight.bold, fontSize: 28),
        titleLarge: TextStyle(fontWeight: FontWeight.w600, fontSize: 22),
        titleMedium: TextStyle(fontWeight: FontWeight.w500, fontSize: 18),
        bodyLarge: TextStyle(fontWeight: FontWeight.normal, fontSize: 16),
        bodyMedium: TextStyle(fontWeight: FontWeight.normal, fontSize: 14),
        labelLarge: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.primary,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
