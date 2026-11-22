import 'package:flutter/material.dart';

/// Bảng màu chính thức của thương hiệu DYTAVA — Precision Workspace (Figma 2026 Baseline)
/// 7 màu chủ đạo chuẩn Figma:
/// 1. Primary: #107C41 (CTA, nút chính, tiến trình)
/// 2. Primary Dark: #185C37 (Splash screen, header, dark hero card)
/// 3. Primary Light: #E7F3EB (Nền nhấn nhẹ, badges, pills, progress track)
/// 4. Background: #F5F8F6 (Nền ứng dụng)
/// 5. Surface: #FFFFFF (Card, bottom sheet)
/// 6. Text Primary: #1F2937 (Nội dung chính)
/// 7. Text Secondary: #586761 (Mô tả, thông tin phụ)
class DytavaColors {
  DytavaColors._();

  // --- Official Figma 2026 Core Brand Palette ---
  static const Color primary = Color(
    0xFF107C41,
  ); // Excel Forest Green - CTA, nút chính, tiến trình
  static const Color primaryDark = Color(
    0xFF185C37,
  ); // Forest Green Dark - Splash, header, hero card
  static const Color primaryLight = Color(
    0xFFE7F3EB,
  ); // Soft Mint - Nền nhấn nhẹ, pills, badge
  static const Color background = Color(0xFFF5F8F6); // Nền ứng dụng thanh nhã
  static const Color surface = Color(
    0xFFFFFFFF,
  ); // Card, bottom sheet, elevated surface
  static const Color textPrimary = Color(
    0xFF1F2937,
  ); // Slate charcoal - Nội dung chính
  static const Color textSecondary = Color(
    0xFF586761,
  ); // Muted sage slate - Mô tả phụ

  // --- Status & Semantic Colors (Figma Precision Support) ---
  // Vàng cho Modified, xanh cho Added, đỏ cho Removed, xám cho Same
  static const Color modified = Color(0xFF855916); // Dark Amber text & border
  static const Color modifiedBg = Color(0xFFFFF4DD); // Soft Amber background
  static const Color modifiedTint = Color(
    0xFFFFFBEB,
  ); // Card container warm tint
  static const Color added = Color(0xFF107C41); // Primary green for Added
  static const Color addedBg = Color(
    0xFFE7F3EB,
  ); // Soft Mint background for Added
  static const Color removed = Color(0xFFA74238); // Crimson Red for Removed
  static const Color removedBg = Color(
    0xFFFCECE8,
  ); // Soft Red background for Removed
  static const Color same = Color(0xFF9CA3AF); // Neutral gray
  static const Color sameBg = Color(0xFFF3F4F6); // Neutral gray background

  // Hairline & border
  static const Color subtleBorder = Color(
    0xFFDCE3DC,
  ); // Viền hairline mỏng phân tách
  static const Color border = Color(0xFFDCE3DC);
  static const Color railLine = Color(0xFFCBD5E1);

  // On-color tokens
  static const Color onPrimary = Color(
    0xFFFFFFFF,
  ); // Chữ trên nền nút Primary là Trắng
  static const Color onPrimaryDark = Color(0xFFFFFFFF);
  static const Color onSurface = textPrimary; // #1F2937

  // Shared semantic aliases use the current Dytava palette.
  static const Color limePrimary = Color(0xFFE7F3EB);
  static const Color lime600 = Color(0xFF107C41);
  static const Color offWhite = Color(0xFFF5F8F6);
  static const Color warmSurface = Color(0xFFE7F3EB);
  static const Color graphite = Color(0xFF1F2937);
  static const Color graphite800 = Color(0xFF185C37);
  static const Color graphiteBorder = Color(0xFF2A3136);
  static const Color differenceCoral = Color(0xFFA74238);
  static const Color precisionNeutral = Color(0xFF607276);
  static const Color sourceBlue = Color(0xFF38BDF8);
  static const Color excelGreen = Color(0xFF107C41);
  static const Color signalLime = limePrimary;
  static const Color warmWhite = offWhite;
  static const Color warmCanvas = offWhite;
  static const Color graphiteSurface = graphite800;
  static const Color white = Color(0xFFFFFFFF);
  static const Color secondary = primaryDark;
  static const Color purple = Color(0xFF8B5CF6);
  static const Color cyan = Color(0xFF06B6D4);
  static const Color green = Color(0xFF107C41);
  static const Color amber = Color(0xFFF59E0B);
  static const Color red = Color(0xFFEF4444);
  static const Color textMuted = Color(0xFF9AA5A7);
  static const Color darkNavy = graphite;
  static const Color dark = graphite;

  // Soft Surface Pastels
  static const Color softBlue = Color(0xFFF0F9FF);
  static const Color softPurple = Color(0xFFF5F3FF);
  static const Color softCyan = Color(0xFFECFEFF);
  static const Color softGreen = primaryLight;
  static const Color softAmber = modifiedBg;
  static const Color softRed = removedBg;

  // 4 Trạng thái so sánh dữ liệu (Comparison States)
  static const Color exact = Color(0xFF107C41);
  static const Color equivalent = Color(0xFF107C41);
  static const Color different = Color(0xFFA74238);
  static const Color unresolved = Color(0xFFF59E0B);
  static const Color exactBg = Color(0xFFECFDF5);
  static const Color equivalentBg = Color(0xFFF4FDE8);
  static const Color differentBg = Color(0xFFFEF2F2);
  static const Color unresolvedBg = Color(0xFFFFFBEB);

  // Gradients
  static const LinearGradient brandGreenGradient = LinearGradient(
    colors: [primary, primaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient brandBlueGradient = LinearGradient(
    colors: [primary, Color(0xFF2E8540)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient logoSheetGradient = LinearGradient(
    colors: [primaryLight, primary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient purpleGradient = LinearGradient(
    colors: [Color(0xFFBAE6FD), sourceBlue],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
