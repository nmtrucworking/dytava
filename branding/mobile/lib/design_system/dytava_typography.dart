import 'package:flutter/material.dart';
import 'dytava_colors.dart';

/// Hệ thống Typography chính thức của Dytava
/// Chuẩn Font: Inter (ưu tiên) hoặc Roboto (Material fallback).
class DytavaTypography {
  DytavaTypography._();

  static const String primaryFont = 'Inter';
  static const String fallbackFont = 'Roboto';

  static const TextStyle displayLarge = TextStyle(
    fontFamily: primaryFont,
    fontFamilyFallback: [fallbackFont],
    fontSize: 32,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.8,
    color: DytavaColors.textPrimary,
  );

  static const TextStyle displayMedium = TextStyle(
    fontFamily: primaryFont,
    fontFamilyFallback: [fallbackFont],
    fontSize: 24,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    color: DytavaColors.textPrimary,
  );

  static const TextStyle titleLarge = TextStyle(
    fontFamily: primaryFont,
    fontFamilyFallback: [fallbackFont],
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: DytavaColors.textPrimary,
  );

  static const TextStyle titleMedium = TextStyle(
    fontFamily: primaryFont,
    fontFamilyFallback: [fallbackFont],
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: DytavaColors.textPrimary,
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
    fontFamily: primaryFont,
    fontFamilyFallback: [fallbackFont],
    fontSize: 22,
    fontWeight: FontWeight.w800,
  );
}
