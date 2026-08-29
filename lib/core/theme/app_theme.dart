import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_spacing.dart';

class AppTheme {
  AppTheme._();

  static final _cardRadius = BorderRadius.circular(4.0);
  static final _inputRadius = BorderRadius.circular(4.0);
  static final _buttonRadius = BorderRadius.circular(4.0);
  static final _dialogRadius = BorderRadius.circular(8.0);
  static final _sheetRadius = const BorderRadius.vertical(top: Radius.circular(12.0));
  static final _snackBarRadius = BorderRadius.circular(4.0);

  // ── Text theme (weight / size hierarchy) ───────────────────────
  static TextTheme get _textTheme {
    return TextTheme(
      // display-lg
      displayLarge: GoogleFonts.jetBrainsMono(fontSize: 48, fontWeight: FontWeight.w700, letterSpacing: -0.04 * 48, height: 1.1),
      displayMedium: GoogleFonts.jetBrainsMono(fontSize: 40, fontWeight: FontWeight.w700, letterSpacing: -0.03 * 40, height: 1.1),
      displaySmall: GoogleFonts.jetBrainsMono(fontSize: 36, fontWeight: FontWeight.w700, letterSpacing: -0.02 * 36, height: 1.2),
      // headline-lg
      headlineLarge: GoogleFonts.jetBrainsMono(fontSize: 32, fontWeight: FontWeight.w600, letterSpacing: -0.02 * 32, height: 1.2),
      // headline-md
      headlineMedium: GoogleFonts.jetBrainsMono(fontSize: 24, fontWeight: FontWeight.w600, height: 1.3),
      headlineSmall: GoogleFonts.jetBrainsMono(fontSize: 20, fontWeight: FontWeight.w600, height: 1.3),
      titleLarge: GoogleFonts.jetBrainsMono(fontSize: 18, fontWeight: FontWeight.w600, height: 1.4),
      titleMedium: GoogleFonts.hankenGrotesk(fontSize: 16, fontWeight: FontWeight.w600, height: 1.5),
      titleSmall: GoogleFonts.hankenGrotesk(fontSize: 14, fontWeight: FontWeight.w600, height: 1.5),
      // body-lg
      bodyLarge: GoogleFonts.hankenGrotesk(fontSize: 18, fontWeight: FontWeight.w400, height: 1.6),
      // body-md
      bodyMedium: GoogleFonts.hankenGrotesk(fontSize: 16, fontWeight: FontWeight.w400, height: 1.5),
      bodySmall: GoogleFonts.hankenGrotesk(fontSize: 14, fontWeight: FontWeight.w400, height: 1.5),
      // mono-data
      labelLarge: GoogleFonts.jetBrainsMono(fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: -0.01 * 14, height: 1.0),
      // label-caps
      labelMedium: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.1 * 12, height: 1.0),
      labelSmall: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.1 * 11, height: 1.0),
    );
  }

  static ThemeData get lightTheme {
    return darkTheme; // Enforce dark theme exclusively
  }

  static ThemeData get darkTheme {
    final colorScheme = const ColorScheme.dark(
      surface: Color(0xFF131314),
      onSurface: Color(0xFFe5e2e3),
      surfaceContainerHighest: Color(0xFF353436),
      onSurfaceVariant: Color(0xFFd5c4ab),
      primary: Color(0xFFffdca1),
      onPrimary: Color(0xFF412d00),
      primaryContainer: Color(0xFFffb800),
      onPrimaryContainer: Color(0xFF6b4c00),
      secondary: Color(0xFFb8c3ff),
      onSecondary: Color(0xFF002388),
      secondaryContainer: Color(0xFF0043eb),
      onSecondaryContainer: Color(0xFFc6ceff),
      error: Color(0xFFffb4ab),
      onError: Color(0xFF690005),
      errorContainer: Color(0xFF93000a),
      onErrorContainer: Color(0xFFffdad6),
      outline: Color(0xFF9e8f78),
      outlineVariant: Color(0xFF514532),
      shadow: Colors.black,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: _textTheme,
      scaffoldBackgroundColor: colorScheme.surface,

      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: const Color(0xFF201f20), // surface-container
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: Border(bottom: BorderSide(color: colorScheme.outline, width: 1)),
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: _cardRadius,
          side: BorderSide(color: colorScheme.outlineVariant, width: 1),
        ),
        color: const Color(0xFF201f20), // surface-container
        surfaceTintColor: Colors.transparent,
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: _cardRadius),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.md),
          shape: RoundedRectangleBorder(borderRadius: _buttonRadius),
          textStyle: _textTheme.labelMedium,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.md),
          shape: RoundedRectangleBorder(borderRadius: _buttonRadius),
          side: BorderSide(color: colorScheme.outline),
          textStyle: _textTheme.labelMedium,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
          shape: RoundedRectangleBorder(borderRadius: _buttonRadius),
          textStyle: _textTheme.labelMedium,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF131314), // surface-dim
        border: OutlineInputBorder(
          borderRadius: _inputRadius,
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: _inputRadius,
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: _inputRadius,
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: _inputRadius,
          borderSide: BorderSide(color: colorScheme.error),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      ),

      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: _dialogRadius),
        backgroundColor: const Color(0xFF201f20),
        surfaceTintColor: Colors.transparent,
      ),

      bottomSheetTheme: BottomSheetThemeData(
        shape: RoundedRectangleBorder(borderRadius: _sheetRadius),
        backgroundColor: const Color(0xFF201f20),
        showDragHandle: true,
        surfaceTintColor: Colors.transparent,
      ),

      snackBarTheme: SnackBarThemeData(
        shape: RoundedRectangleBorder(borderRadius: _snackBarRadius),
        backgroundColor: const Color(0xFF353436),
        behavior: SnackBarBehavior.floating,
      ),

      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: 1.0,
        space: 1.0,
      ),
    );
  }
}
