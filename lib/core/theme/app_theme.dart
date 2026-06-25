import 'package:flutter/material.dart';

import 'package:app_skeleton/core/theme/app_colors.dart';
import 'package:app_skeleton/core/theme/app_spacing.dart';
import 'package:app_skeleton/core/theme/app_typography.dart';

abstract final class AppTheme {
  static ThemeData dark() {
    const cs = ColorScheme.dark(
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      secondary: AppColors.secondary,
      onSecondary: AppColors.onSecondary,
      surface: AppColors.bgCard,
      onSurface: AppColors.textPrimary,
      error: AppColors.error,
    );
    return _base(cs, AppColors.bgBase, AppColors.bgCard);
  }

  static ThemeData light() {
    const cs = ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      secondary: AppColors.secondary,
      onSecondary: AppColors.onSecondary,
      surface: AppColors.lightBgCard,
      onSurface: AppColors.lightTextPrimary,
      error: AppColors.error,
    );
    return _base(cs, AppColors.lightBgBase, AppColors.lightBgCard);
  }

  static ThemeData _base(ColorScheme cs, Color bg, Color card) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      scaffoldBackgroundColor: bg,
      fontFamily: AppTypography.fontFamily,
      textTheme: const TextTheme(
        displayLarge: AppTypography.display,
        headlineMedium: AppTypography.h1,
        headlineSmall: AppTypography.h2,
        titleMedium: AppTypography.title,
        bodyMedium: AppTypography.body,
        labelMedium: AppTypography.caption,
        labelSmall: AppTypography.overline,
      ),
      dividerColor: cs.outline,
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: cs.onSurface,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: cs.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: cs.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: cs.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
      ),
    );
  }
}
