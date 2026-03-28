import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Builds a [ThemeData] adjusted for the current accessibility settings.
///
/// [highContrast] — replaces subtler grays with near-black text and pure-white
/// backgrounds to maximise legibility for visually impaired users.
abstract final class AppTheme {
  // ── Normal theme ─────────────────────────────────────────────────────────

  static ThemeData normal() => _build(
        seedColor: AppColors.primaryBlue,
        background: AppColors.background,
        surface: AppColors.cardWhite,
        onSurface: AppColors.textDark,
        brightness: Brightness.light,
      );

  // ── High-contrast theme ───────────────────────────────────────────────────

  static ThemeData highContrast() => _build(
        seedColor: const Color(0xFF1D4ED8), // deeper blue
        background: Colors.white,
        surface: Colors.white,
        onSurface: Colors.black,
        brightness: Brightness.light,
        highContrast: true,
      );

  // ── Internal builder ──────────────────────────────────────────────────────

  static ThemeData _build({
    required Color seedColor,
    required Color background,
    required Color surface,
    required Color onSurface,
    required Brightness brightness,
    bool highContrast = false,
  }) {
    final cs = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    ).copyWith(
      surface: surface,
      onSurface: onSurface,
      // Make scaffold / card / dialog backgrounds match
      surfaceContainer: highContrast ? Colors.white : AppColors.cardWhite,
      surfaceContainerLow:
          highContrast ? const Color(0xFFF0F0F0) : AppColors.background,
    );

    return ThemeData(
      colorScheme: cs,
      useMaterial3: true,
      scaffoldBackgroundColor: background,
      // ── Card ───────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: highContrast ? Colors.white : AppColors.cardWhite,
        surfaceTintColor: Colors.transparent,
        elevation: highContrast ? 0 : 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: highContrast
              ? const BorderSide(color: Colors.black, width: 1.5)
              : BorderSide.none,
        ),
      ),
      // ── AppBar ─────────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: highContrast ? Colors.black : AppColors.textDark,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: highContrast ? Colors.black : AppColors.textDark,
          letterSpacing: -0.6,
        ),
      ),
      // ── Switch ─────────────────────────────────────────────────────────
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return highContrast ? Colors.black : AppColors.primaryBlue;
          }
          return highContrast ? Colors.black54 : null;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return highContrast
                ? Colors.black26
                : AppColors.primaryBlueLight.withValues(alpha: 0.4);
          }
          return null;
        }),
      ),
      // ── Text (global foreground shift for high contrast) ───────────────
      textTheme: highContrast
          ? _highContrastTextTheme()
          : null, // null = use Material default
      // ── Divider ────────────────────────────────────────────────────────
      dividerColor: highContrast ? Colors.black38 : AppColors.divider,
    );
  }

  static TextTheme _highContrastTextTheme() {
    const black = TextStyle(color: Colors.black);
    return TextTheme(
      displayLarge: black,
      displayMedium: black,
      displaySmall: black,
      headlineLarge: black,
      headlineMedium: black,
      headlineSmall: black,
      titleLarge: black,
      titleMedium: black,
      titleSmall: black,
      bodyLarge: black,
      bodyMedium: black,
      bodySmall: black,
      labelLarge: black,
      labelMedium: black,
      labelSmall: black,
    );
  }
}
