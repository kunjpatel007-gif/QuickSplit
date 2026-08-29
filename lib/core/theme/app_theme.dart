import 'package:flutter/material.dart';
import 'app_spacing.dart';

class AppTheme {
  AppTheme._();

  // ── Brand palette ──────────────────────────────────────────────
  static const _primaryColor = Color(0xFF4F46E5);   // Indigo 600
  static const _secondaryColor = Color(0xFF14B8A6);  // Teal 500 (muted from tealAccent)

  // ── Shared component themes ────────────────────────────────────
  static final _cardRadius = BorderRadius.circular(AppRadius.lg);
  static final _inputRadius = BorderRadius.circular(AppRadius.md);
  static final _buttonRadius = BorderRadius.circular(AppRadius.md);
  static final _dialogRadius = BorderRadius.circular(AppRadius.xl);
  static final _sheetRadius = BorderRadius.vertical(top: Radius.circular(AppRadius.xl));
  static final _snackBarRadius = BorderRadius.circular(AppRadius.sm);

  // ── Text theme (weight / size hierarchy) ───────────────────────
  static const _textTheme = TextTheme(
    displayLarge:  TextStyle(fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -0.5),
    displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.5),
    displaySmall:  TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
    headlineLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
    headlineMedium:TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
    headlineSmall: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
    titleLarge:    TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
    titleMedium:   TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
    titleSmall:    TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
    bodyLarge:     TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
    bodyMedium:    TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
    bodySmall:     TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
    labelLarge:    TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
    labelMedium:   TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
    labelSmall:    TextStyle(fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.5),
  );

  // ── Shared input decoration builder ────────────────────────────
  static InputDecorationTheme _inputDecoration(ColorScheme cs) =>
      InputDecorationTheme(
        filled: true,
        fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        border: OutlineInputBorder(
          borderRadius: _inputRadius,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: _inputRadius,
          borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: _inputRadius,
          borderSide: BorderSide(color: cs.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: _inputRadius,
          borderSide: BorderSide(color: cs.error),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
      );

  // ══════════════════════════════════════════════════════════════
  //  LIGHT THEME
  // ══════════════════════════════════════════════════════════════
  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.light(
      primary: _primaryColor,
      onPrimary: Colors.white,
      secondary: _secondaryColor,
      onSecondary: Colors.white,
      primaryContainer: const Color(0xFFE0E7FF),   // Indigo 100
      onPrimaryContainer: const Color(0xFF312E81),  // Indigo 900
      secondaryContainer: const Color(0xFFCCFBF1),  // Teal 100
      onSecondaryContainer: const Color(0xFF134E4A), // Teal 900
      tertiaryContainer: const Color(0xFFFEF3C7),   // Amber 100
      onTertiaryContainer: const Color(0xFF78350F),  // Amber 900
      surface: const Color(0xFFFAFAFA),
      onSurface: const Color(0xFF1A1A1A),
      surfaceContainerHighest: const Color(0xFFF3F4F6),
      onSurfaceVariant: const Color(0xFF6B7280),
      outline: const Color(0xFFD1D5DB),
      outlineVariant: const Color(0xFFE5E7EB),
      error: const Color(0xFFDC2626),
      onError: Colors.white,
      errorContainer: const Color(0xFFFEE2E2),
      onErrorContainer: const Color(0xFF991B1B),
      shadow: Colors.black,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: _textTheme,
      scaffoldBackgroundColor: colorScheme.surface,

      // AppBar — clean, surface-colored
      appBarTheme: AppBarTheme(
        centerTitle: true,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        surfaceTintColor: Colors.transparent,
      ),

      // Cards — flat with subtle elevation
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: _cardRadius),
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),

      // FAB
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: _cardRadius),
      ),

      // Buttons
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.md,
          ),
          shape: RoundedRectangleBorder(borderRadius: _buttonRadius),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.md,
          ),
          shape: RoundedRectangleBorder(borderRadius: _buttonRadius),
          side: BorderSide(color: colorScheme.outline),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          shape: RoundedRectangleBorder(borderRadius: _buttonRadius),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),

      // Input fields
      inputDecorationTheme: _inputDecoration(colorScheme),

      // Dialogs
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: _dialogRadius),
        surfaceTintColor: Colors.transparent,
      ),

      // Bottom sheets
      bottomSheetTheme: BottomSheetThemeData(
        shape: RoundedRectangleBorder(borderRadius: _sheetRadius),
        showDragHandle: true,
        surfaceTintColor: Colors.transparent,
      ),

      // Snackbar
      snackBarTheme: SnackBarThemeData(
        shape: RoundedRectangleBorder(borderRadius: _snackBarRadius),
        behavior: SnackBarBehavior.floating,
      ),

      // Chips
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      ),

      // Dividers — very subtle
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: 0.5,
        space: 0,
      ),

      // Page transitions
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  DARK THEME
  // ══════════════════════════════════════════════════════════════
  static ThemeData get darkTheme {
    final colorScheme = ColorScheme.dark(
      primary: const Color(0xFF3FB950),              // Green
      onPrimary: Colors.white,
      secondary: const Color(0xFFD29922),            // Amber
      onSecondary: Colors.white,
      primaryContainer: const Color(0xFF161B22),     // Surface
      onPrimaryContainer: const Color(0xFFE6EDF3),  // Text
      secondaryContainer: const Color(0xFF30363D),   // Border
      onSecondaryContainer: const Color(0xFF8B949E), // Muted
      tertiaryContainer: const Color(0xFF161B22),    // Surface
      onTertiaryContainer: const Color(0xFFE6EDF3),  // Text
      surface: const Color(0xFF0D1117),              // Background
      onSurface: const Color(0xFFE6EDF3),            // Text
      surfaceContainerHighest: const Color(0xFF161B22), // Surface
      onSurfaceVariant: const Color(0xFF8B949E),     // Muted
      outline: const Color(0xFF30363D),              // Border
      outlineVariant: const Color(0xFF30363D),
      error: const Color(0xFFCF222E),                // Red
      onError: Colors.white,
      errorContainer: const Color(0xFFCF222E),       // Red
      onErrorContainer: Colors.white,
      shadow: Colors.black,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: _textTheme,
      scaffoldBackgroundColor: colorScheme.surface,

      // AppBar — dark surface, not bright purple
      appBarTheme: AppBarTheme(
        centerTitle: true,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        surfaceTintColor: Colors.transparent,
      ),

      // Cards
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: _cardRadius),
        color: const Color(0xFF161B22),
        surfaceTintColor: Colors.transparent,
      ),

      // FAB
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: _cardRadius),
      ),

      // Buttons
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.md,
          ),
          shape: RoundedRectangleBorder(borderRadius: _buttonRadius),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.md,
          ),
          shape: RoundedRectangleBorder(borderRadius: _buttonRadius),
          side: BorderSide(color: colorScheme.outline),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          shape: RoundedRectangleBorder(borderRadius: _buttonRadius),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),

      // Input fields
      inputDecorationTheme: _inputDecoration(colorScheme),

      // Dialogs
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: _dialogRadius),
        surfaceTintColor: Colors.transparent,
      ),

      // Bottom sheets
      bottomSheetTheme: BottomSheetThemeData(
        shape: RoundedRectangleBorder(borderRadius: _sheetRadius),
        showDragHandle: true,
        surfaceTintColor: Colors.transparent,
      ),

      // Snackbar
      snackBarTheme: SnackBarThemeData(
        shape: RoundedRectangleBorder(borderRadius: _snackBarRadius),
        behavior: SnackBarBehavior.floating,
      ),

      // Chips
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      ),

      // Dividers
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: 0.5,
        space: 0,
      ),

      // Page transitions
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
    );
  }
}
