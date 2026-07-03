import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class AppTheme {
  static ThemeData light() {
    const accent = Color(0xFFC4161D);
    const surface = Color(0xFFF6F2EC);

    final base = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: accent,
        brightness: Brightness.light,
        surface: surface,
      ),
      useMaterial3: true,
      scaffoldBackgroundColor: surface,
    );

    return base.copyWith(
      textTheme: GoogleFonts.sourceSans3TextTheme(base.textTheme),
      appBarTheme: base.appBarTheme.copyWith(
        centerTitle: false,
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        foregroundColor: const Color(0xFF1F1B16),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      cardTheme: base.cardTheme.copyWith(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}
