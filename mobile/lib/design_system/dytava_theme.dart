import 'package:flutter/material.dart';

import 'dytava_colors.dart';
import 'dytava_typography.dart';

/// Cấu hình ThemeData chuẩn Flutter Material 3 cho DYTAVA (Figma 2026 Baseline)
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
        secondary: DytavaColors.primaryDark,
        tertiary: DytavaColors.primaryLight,
        surface: DytavaColors.surface,
        error: DytavaColors.removed,
        onPrimary: DytavaColors.onPrimary,
        onSecondary: DytavaColors.onPrimaryDark,
        onSurface: DytavaColors.textPrimary,
        onError: Colors.white,
      ),
      dividerColor: DytavaColors.border,
      dividerTheme: const DividerThemeData(
        color: DytavaColors.border,
        thickness: 1,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: DytavaColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        showDragHandle: true,
      ),
      cardTheme: CardThemeData(
        color: DytavaColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: DytavaColors.subtleBorder, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: DytavaColors.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: DytavaColors.textPrimary,
        centerTitle: false,
        elevation: 0,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: DytavaColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontFamily: DytavaTypography.primaryFont,
            fontWeight: FontWeight.w600,
            fontSize: 15,
            letterSpacing: -0.2,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: DytavaColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontFamily: DytavaTypography.primaryFont,
            fontWeight: FontWeight.w600,
            fontSize: 15,
            letterSpacing: -0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: DytavaColors.textPrimary,
          backgroundColor: DytavaColors.surface,
          side: const BorderSide(color: DytavaColors.subtleBorder, width: 1),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontFamily: DytavaTypography.primaryFont,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: DytavaColors.primary,
          textStyle: const TextStyle(
            fontFamily: DytavaTypography.primaryFont,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
      chipTheme: const ChipThemeData(
        backgroundColor: DytavaColors.white,
        selectedColor: DytavaColors.primaryLight,
        labelStyle: TextStyle(
          color: DytavaColors.textPrimary,
          fontFamily: DytavaTypography.primaryFont,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        secondaryLabelStyle: TextStyle(
          color: DytavaColors.primary,
          fontFamily: DytavaTypography.primaryFont,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
        side: BorderSide(color: DytavaColors.subtleBorder, width: 1),
        shape: StadiumBorder(),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: DytavaColors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: DytavaColors.subtleBorder,
            width: 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: DytavaColors.subtleBorder,
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: DytavaColors.primary, width: 2),
        ),
        hintStyle: const TextStyle(
          color: DytavaColors.textSecondary,
          fontSize: 14,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          return DytavaColors.textSecondary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return DytavaColors.primary;
          }
          return DytavaColors.sameBg;
        }),
        trackOutlineColor: WidgetStateProperty.all(DytavaColors.subtleBorder),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: DytavaColors.surface,
        indicatorColor: DytavaColors.primaryLight,
        elevation: 0,
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
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: DytavaColors.primary, size: 22);
          }
          return const IconThemeData(
            color: DytavaColors.textSecondary,
            size: 22,
          );
        }),
      ),
    );
  }

  static ThemeData get darkTheme => lightTheme;
}
