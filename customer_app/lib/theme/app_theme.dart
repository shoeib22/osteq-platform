import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Central theme definition. Every screen should be able to rely on sane defaults from
/// here (AppBar, buttons, inputs, cards, nav) — new screens shouldn't need to hand-roll
/// their own colors/shapes to look consistent with the rest of the app.
final ThemeData appTheme = _build();

ThemeData _build() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: const ColorScheme.dark(
      brightness: Brightness.dark,
      primary: AppColors.gold,
      onPrimary: Color(0xFF1A1400),
      secondary: AppColors.goldMuted,
      onSecondary: AppColors.textPrimary,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      error: AppColors.error,
      onError: Colors.white,
      outline: AppColors.border,
    ),
  );

  final displayFont = GoogleFonts.playfairDisplayTextTheme(base.textTheme);
  final bodyFont = GoogleFonts.interTextTheme(base.textTheme);

  final textTheme = bodyFont.copyWith(
    displayLarge: displayFont.displayLarge?.copyWith(color: AppColors.textPrimary),
    displayMedium: displayFont.displayMedium?.copyWith(color: AppColors.textPrimary),
    displaySmall: displayFont.displaySmall?.copyWith(color: AppColors.textPrimary),
    headlineLarge: displayFont.headlineLarge?.copyWith(color: AppColors.textPrimary),
    headlineMedium: displayFont.headlineMedium?.copyWith(color: AppColors.textPrimary),
    headlineSmall: displayFont.headlineSmall?.copyWith(color: AppColors.textPrimary),
    titleLarge: displayFont.titleLarge?.copyWith(
      color: AppColors.textPrimary,
      fontWeight: FontWeight.w600,
    ),
    titleMedium: bodyFont.titleMedium?.copyWith(
      color: AppColors.textPrimary,
      fontWeight: FontWeight.w600,
    ),
    titleSmall: bodyFont.titleSmall?.copyWith(color: AppColors.textPrimary),
    bodyLarge: bodyFont.bodyLarge?.copyWith(color: AppColors.textPrimary),
    bodyMedium: bodyFont.bodyMedium?.copyWith(color: AppColors.textSecondary),
    bodySmall: bodyFont.bodySmall?.copyWith(color: AppColors.textSecondary),
    labelLarge: bodyFont.labelLarge?.copyWith(
      color: AppColors.textPrimary,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.3,
    ),
  );

  return base.copyWith(
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: textTheme.headlineSmall,
      iconTheme: const IconThemeData(color: AppColors.textPrimary),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      margin: EdgeInsets.zero,
    ),
    dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1, space: 32),
    listTileTheme: const ListTileThemeData(
      iconColor: AppColors.gold,
      textColor: AppColors.textPrimary,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.gold, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      labelStyle: const TextStyle(color: AppColors.textSecondary),
      hintStyle: const TextStyle(color: AppColors.textDisabled),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.gold,
        foregroundColor: const Color(0xFF1A1400),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.3),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        side: const BorderSide(color: AppColors.border),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: AppColors.gold),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: AppColors.textPrimary),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.surfaceRaised,
      labelStyle: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w600),
      side: const BorderSide(color: AppColors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.gold.withValues(alpha: 0.16),
      surfaceTintColor: Colors.transparent,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: states.contains(WidgetState.selected) ? AppColors.gold : AppColors.textSecondary,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected) ? AppColors.gold : AppColors.textSecondary,
        ),
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.surface,
      selectedItemColor: AppColors.gold,
      unselectedItemColor: AppColors.textSecondary,
      type: BottomNavigationBarType.fixed,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.gold,
      foregroundColor: Color(0xFF1A1400),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surfaceRaised,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.surfaceRaised,
      contentTextStyle: const TextStyle(color: AppColors.textPrimary),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      behavior: SnackBarBehavior.floating,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.gold),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? AppColors.gold : AppColors.textSecondary,
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? AppColors.gold : Colors.transparent,
      ),
      checkColor: const WidgetStatePropertyAll(Color(0xFF1A1400)),
    ),
  );
}
