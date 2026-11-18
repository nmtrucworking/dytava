import 'package:flutter/material.dart';

import 'dytava_colors.dart';
import 'dytava_typography.dart';

/// Cấu hình ThemeData chuẩn Flutter Material 3 cho DYTAVA — Precision Workspace
class DytavaTheme {
  DytavaTheme._();

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: DytavaColors.limePrimary,
      scaffoldBackgroundColor: DytavaColors.offWhite,
      fontFamily: DytavaTypography.primaryFont,
      fontFamilyFallback: const [DytavaTypography.fallbackFont],
      textTheme: DytavaTypography.textTheme,
      colorScheme: const ColorScheme.light(
        primary: DytavaColors.limePrimary,
        secondary: DytavaColors.graphite,
        tertiary: DytavaColors.lime600,
        surface: DytavaColors.white,
        error: DytavaColors.differenceCoral,
        onPrimary: DytavaColors.graphite,
        onSecondary: DytavaColors.white,
        onSurface: DytavaColors.graphite,
        onError: DytavaColors.white,
      ),
      cardTheme: CardThemeData(
        color: DytavaColors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: DytavaColors.subtleBorder, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: DytavaColors.offWhite,
        surfaceTintColor: Colors.transparent,
        foregroundColor: DytavaColors.graphite,
        centerTitle: false,
        elevation: 0,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: DytavaColors.limePrimary,
          foregroundColor: DytavaColors.graphite,
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontFamily: DytavaTypography.editorialFont,
            fontWeight: FontWeight.w800,
            fontSize: 15,
            letterSpacing: -0.2,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: DytavaColors.limePrimary,
          foregroundColor: DytavaColors.graphite,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontFamily: DytavaTypography.editorialFont,
            fontWeight: FontWeight.w800,
            fontSize: 15,
            letterSpacing: -0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: DytavaColors.graphite,
          backgroundColor: DytavaColors.warmSurface,
          side: const BorderSide(color: DytavaColors.subtleBorder, width: 1),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontFamily: DytavaTypography.editorialFont,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
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
          borderSide: const BorderSide(color: DytavaColors.subtleBorder, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: DytavaColors.subtleBorder, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: DytavaColors.lime600, width: 2),
        ),
        hintStyle: const TextStyle(color: DytavaColors.textMuted, fontSize: 14),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return DytavaColors.graphite;
          }
          return DytavaColors.precisionNeutral;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return DytavaColors.limePrimary;
          }
          return DytavaColors.warmSurface;
        }),
        trackOutlineColor: WidgetStateProperty.all(DytavaColors.subtleBorder),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: DytavaColors.offWhite,
        indicatorColor: DytavaColors.limePrimary,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: DytavaColors.graphite,
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
