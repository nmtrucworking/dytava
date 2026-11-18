import 'package:flutter/material.dart';

/// Bảng màu chính thức của thương hiệu DYTAVA — Precision Workspace (v3.2 Baseline)
/// Khớp chuẩn với UI Mockup Set, Design Tokens và Web Visual Language.
class DytavaColors {
  DytavaColors._();

  // --- DYTAVA — Precision Workspace Core Palette ---
  static const Color limePrimary = Color(0xFFC8FF4A); // Nút chính (CTA), active switch, tiến trình nổi bật
  static const Color lime600 = Color(0xFF86E63A); // Điểm nhấn viền active, hover state, rail active
  static const Color offWhite = Color(0xFFF7F6F2); // Nền canvas sáng mặc định, thanh nhã và êm mắt
  static const Color warmSurface = Color(0xFFEDEBE4); // Bề mặt card, container phụ, vùng nhập liệu
  static const Color graphite = Color(0xFF0F1A1C); // Màu chữ chính, nút phụ tương phản cao, header kỹ thuật
  static const Color graphite800 = Color(0xFF1B2426); // Bề mặt tối cho dark mode, container Focus Diff, status pill
  static const Color graphiteBorder = Color(0xFF2A3136); // Hairline graphite border trong dark container
  static const Color subtleBorder = Color(0xFFD8D5CC); // Viền hairline mỏng phân tách cấu trúc
  static const Color differenceCoral = Color(0xFFE97965); // Dữ liệu sai khác (DIFFERENT), alert
  static const Color precisionNeutral = Color(0xFF607276); // Đường ray kết nối, trạng thái chờ
  static const Color sourceBlue = Color(0xFF38BDF8); // Phân định luồng dữ liệu Nguồn B
  static const Color excelGreen = Color(0xFF107C41); // Màu icon tệp Excel

  // --- Aliases for UI & Backwards Compatibility ---
  static const Color signalLime = limePrimary; // 0xFFC8FF4A
  static const Color warmWhite = offWhite; // 0xFFF7F6F2
  static const Color warmCanvas = offWhite; // 0xFFF7F6F2
  static const Color graphiteSurface = graphite800; // 0xFF1B2426
  static const Color background = offWhite; // 0xFFF7F6F2
  static const Color border = subtleBorder; // 0xFFD8D5CC
  static const Color railLine = Color(0xFFCBD5E1); // Comparison rail connecting line
  static const Color white = Color(0xFFFFFFFF); // Pure White

  // Primary & Secondary Brand Tokens
  static const Color primary = limePrimary; // Màu thương hiệu hành động chính là Lime Primary
  static const Color primaryDark = lime600;
  static const Color onPrimary = graphite; // Văn bản trên nền Lime Primary là Graphite
  static const Color secondary = graphite;
  static const Color purple = Color(0xFF8B5CF6);
  static const Color cyan = Color(0xFF06B6D4);
  static const Color green = Color(0xFF10B981); // Emerald Green
  static const Color amber = Color(0xFFF59E0B); // Amber Warning
  static const Color red = Color(0xFFEF4444); // Crimson Danger

  // Typography & Text Shades
  static const Color textPrimary = graphite; // 0xFF0F1A1C
  static const Color textSecondary = Color(0xFF5F6B6D);
  static const Color textMuted = Color(0xFF9AA5A7);
  static const Color darkNavy = graphite;
  static const Color dark = graphite;

  // Soft Surface Pastels (cho Thẻ, Chip, Badge, Container)
  static const Color softBlue = Color(0xFFF0F9FF);
  static const Color softPurple = Color(0xFFF5F3FF);
  static const Color softCyan = Color(0xFFECFEFF);
  static const Color softGreen = Color(0xFFF0FDF4);
  static const Color softAmber = Color(0xFFFFFBEB);
  static const Color softRed = Color(0xFFFEF2F2);

  // 4 Trạng thái so sánh dữ liệu (Comparison States)
  static const Color exact = Color(0xFF10B981); // Trùng khớp hoàn toàn
  static const Color equivalent = Color(0xFF86E63A); // Tương đương theo quy tắc (Lime-600)
  static const Color different = Color(0xFFE97965); // Sai khác (Difference Coral)
  static const Color unresolved = Color(0xFFF59E0B); // Cần xem xét (Amber Warning)

  // Soft Background cho các trạng thái so sánh
  static const Color exactBg = Color(0xFFECFDF5);
  static const Color equivalentBg = Color(0xFFF4FDE8);
  static const Color differentBg = Color(0xFFFEF2F2);
  static const Color unresolvedBg = Color(0xFFFFFBEB);

  // Gradients
  static const LinearGradient brandBlueGradient = LinearGradient(
    colors: [limePrimary, lime600],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient logoSheetGradient = LinearGradient(
    colors: [Color(0xFFE2FF85), limePrimary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient purpleGradient = LinearGradient(
    colors: [Color(0xFFBAE6FD), sourceBlue],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
