import 'package:flutter/material.dart';
import 'dytava_colors.dart';
import 'dytava_typography.dart';

/// Cấu hình ThemeData chuẩn Flutter Material 3 cho Dytava
class DytavaTheme {
  DytavaTheme._();

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: DytavaColors.primary,
      scaffoldBackgroundColor: DytavaColors.background,
      fontFamily: DytavaTypography.primaryFont,
      fontFamilyFallback: const [DytavaTypography.fallbackFont],
      textTheme: DytavaTypography.textTheme,
      colorScheme: const ColorScheme.light(
        primary: DytavaColors.primary,
        secondary: DytavaColors.secondary,
        tertiary: DytavaColors.purple,
        surface: DytavaColors.white,
        error: DytavaColors.red,
        onPrimary: DytavaColors.white,
        onSecondary: DytavaColors.white,
        onSurface: DytavaColors.textPrimary,
        onError: DytavaColors.white,
      ),
      cardTheme: CardThemeData(
        color: DytavaColors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: DytavaColors.border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: DytavaColors.primary,
          foregroundColor: DytavaColors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: DytavaTypography.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: DytavaColors.textPrimary,
          side: const BorderSide(color: DytavaColors.border, width: 1),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: DytavaTypography.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: DytavaColors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: DytavaColors.border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: DytavaColors.border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: DytavaColors.primary, width: 2),
        ),
        hintStyle: const TextStyle(
          color: DytavaColors.textMuted,
          fontSize: 14,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: DytavaColors.white,
        indicatorColor: DytavaColors.softBlue,
        elevation: 2,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: DytavaColors.primary,
            );
          }
          return const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: DytavaColors.textSecondary,
          );
        }),
      ),
    );
  }
}
