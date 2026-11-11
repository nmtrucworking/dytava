import 'package:flutter/material.dart';

/// Bảng màu chính thức của thương hiệu Dytava v2.0
/// Khớp chuẩn với Brand Guidelines và Design System UI Assets.
class DytavaColors {
  DytavaColors._();

  // Core Palette
  static const Color primary = Color(0xFF2563EB); // Royal Blue
  static const Color secondary = Color(0xFF3B82F6); // Sky Blue
  static const Color purple = Color(0xFF8B5CF6); // Purple Accent
  static const Color cyan = Color(0xFF06B6D4); // Cyan Accent
  static const Color green = Color(0xFF10B981); // Emerald Green / Excel
  static const Color amber = Color(0xFFF59E0B); // Amber Warning
  static const Color red = Color(0xFFEF4444); // Crimson Danger
  static const Color background = Color(0xFFF3F4F6); // Light Gray Background
  static const Color border = Color(0xFFE5E7EB); // Border / Line Gray
  static const Color white = Color(0xFFFFFFFF); // Pure White

  // Dark & Neutral Shades
  static const Color darkNavy = Color(0xFF0F172A);
  static const Color dark = Color(0xFF142253);
  static const Color textPrimary = Color(0xFF1E293B);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textMuted = Color(0xFF94A3B8);

  // Soft Surface Pastels (cho Thẻ, Chip, Badge, Container)
  static const Color softBlue = Color(0xFFEFF6FF);
  static const Color softPurple = Color(0xFFF5F3FF);
  static const Color softCyan = Color(0xFFECFEFF);
  static const Color softGreen = Color(0xFFECFDF5);
  static const Color softAmber = Color(0xFFFFFBEB);
  static const Color softRed = Color(0xFFFEF2F2);

  // 4 Trạng thái so sánh dữ liệu (Comparison States)
  static const Color exact = Color(0xFF10B981); // Giống hoàn toàn
  static const Color equivalent = Color(0xFF2563EB); // Tương đương theo quy tắc
  static const Color different = Color(0xFFEF4444); // Khác biệt
  static const Color unresolved = Color(0xFFF59E0B); // Chưa xác định / Cần kiểm tra

  // Soft Background cho các trạng thái so sánh
  static const Color exactBg = Color(0xFFECFDF5);
  static const Color equivalentBg = Color(0xFFEFF6FF);
  static const Color differentBg = Color(0xFFFEF2F2);
  static const Color unresolvedBg = Color(0xFFFFFBEB);

  // Gradients
  static const LinearGradient brandBlueGradient = LinearGradient(
    colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient logoSheetGradient = LinearGradient(
    colors: [Color(0xFF38BDF8), Color(0xFF2563EB)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient purpleGradient = LinearGradient(
    colors: [Color(0xFFA855F7), Color(0xFF7C3AED)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
