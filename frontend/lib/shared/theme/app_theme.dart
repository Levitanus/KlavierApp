import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class AppTheme {
  static ThemeData light() => _buildTheme(
        brightness: Brightness.light,
        background: const Color(0xFFF6F2EC),
        surface: Colors.white,
        primary: const Color(0xFF2F9C94),
        secondary: const Color(0xFF4FB3A6),
        tertiary: const Color(0xFFF2C94C),
        error: const Color(0xFFC82128),
      );

  static ThemeData dark() => _buildTheme(
        brightness: Brightness.dark,
        background: const Color(0xFF1F1B1A),
        surface: const Color(0xFF2A2422),
        primary: const Color(0xFF3BA79D),
        secondary: const Color(0xFF4FB3A6),
        tertiary: const Color(0xFFF07C76),
        error: const Color(0xFFED1C24),
      );

  static ThemeData _buildTheme({
    required Brightness brightness,
    required Color background,
    required Color surface,
    required Color primary,
    required Color secondary,
    required Color tertiary,
    required Color error,
  }) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: brightness,
        surface: surface,
      ).copyWith(
        primary: primary,
        onPrimary: Colors.white,
        secondary: secondary,
        tertiary: tertiary,
        error: error,
        surface: surface,
        onSurface: brightness == Brightness.dark
            ? const Color(0xFFE9E1D7)
            : const Color(0xFF231F20),
      ),
    );

    final textTheme = GoogleFonts.getTextTheme('Jost', base.textTheme).apply(
      bodyColor: base.colorScheme.onSurface,
      displayColor: base.colorScheme.onSurface,
    );

    return base.copyWith(
      textTheme: brightness == Brightness.light
          ? textTheme.copyWith(
              bodyLarge: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
              bodyMedium: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
              titleLarge: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
              titleMedium: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              labelLarge: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
            )
          : textTheme,
      appBarTheme: base.appBarTheme.copyWith(
        centerTitle: false,
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: base.colorScheme.onSurface,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: brightness == Brightness.dark ? const Color(0xFF322B29) : Colors.white,
        prefixIconColor: primary,
        suffixIconColor: primary,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      cardTheme: base.cardTheme.copyWith(
        elevation: 0,
        color: brightness == Brightness.dark ? const Color(0xFF2A2422) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        margin: EdgeInsets.zero,
      ),
      dialogTheme: base.dialogTheme.copyWith(
        backgroundColor: brightness == Brightness.dark ? const Color(0xFF2A2422) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }
}
