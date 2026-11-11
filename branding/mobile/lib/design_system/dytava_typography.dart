import 'package:flutter/material.dart';

import 'dytava_colors.dart';

/// Hệ thống Typography chính thức của Dytava
/// Precision Core: display, giao diện tiếng Việt và dữ liệu kỹ thuật.
class DytavaTypography {
  DytavaTypography._();

  static const String displayFont = 'Plus Jakarta Sans';
  static const String primaryFont = 'Be Vietnam Pro';
  static const String dataFont = 'IBM Plex Mono';
  static const String fallbackFont = 'Roboto';

  static const TextStyle displayLarge = TextStyle(
    fontFamily: displayFont,
    fontFamilyFallback: [primaryFont, fallbackFont],
    fontSize: 32,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.8,
    color: DytavaColors.textPrimary,
    height: 1.3,
  );

  static const TextStyle displayMedium = TextStyle(
    fontFamily: displayFont,
    fontFamilyFallback: [primaryFont, fallbackFont],
    fontSize: 24,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    color: DytavaColors.textPrimary,
    height: 1.3,
  );

  static const TextStyle titleLarge = TextStyle(
    fontFamily: displayFont,
    fontFamilyFallback: [primaryFont, fallbackFont],
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: DytavaColors.textPrimary,
    height: 1.3,
  );

  static const TextStyle titleMedium = TextStyle(
    fontFamily: displayFont,
    fontFamilyFallback: [primaryFont, fallbackFont],
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: DytavaColors.textPrimary,
    height: 1.3,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontFamily: primaryFont,
    fontFamilyFallback: [fallbackFont],
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: DytavaColors.textPrimary,
    height: 1.5,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: primaryFont,
    fontFamilyFallback: [fallbackFont],
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: DytavaColors.textSecondary,
    height: 1.4,
  );

  static const TextStyle labelLarge = TextStyle(
    fontFamily: primaryFont,
    fontFamilyFallback: [fallbackFont],
    fontSize: 13,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.2,
  );

  static const TextStyle labelSmall = TextStyle(
    fontFamily: primaryFont,
    fontFamilyFallback: [fallbackFont],
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
  );

  static const TextStyle metricNumber = TextStyle(
    fontFamily: dataFont,
    fontFamilyFallback: [fallbackFont],
    fontSize: 22,
    fontWeight: FontWeight.w700,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const TextStyle dataMedium = TextStyle(
    fontFamily: dataFont,
    fontFamilyFallback: [primaryFont, fallbackFont],
    fontSize: 13,
    fontWeight: FontWeight.w400,
    fontFeatures: [FontFeature.tabularFigures()],
    height: 1.5,
  );

  static const TextTheme textTheme = TextTheme(
    displayLarge: displayLarge,
    displayMedium: displayMedium,
    displaySmall: displayMedium,
    headlineLarge: displayMedium,
    headlineMedium: displayMedium,
    headlineSmall: titleLarge,
    titleLarge: titleLarge,
    titleMedium: titleMedium,
    titleSmall: titleMedium,
    bodyLarge: bodyLarge,
    bodyMedium: bodyMedium,
    bodySmall: TextStyle(
      fontFamily: primaryFont,
      fontSize: 11,
      height: 1.5,
      color: DytavaColors.textSecondary,
    ),
    labelLarge: labelLarge,
    labelMedium: labelLarge,
    labelSmall: labelSmall,
  );
}
