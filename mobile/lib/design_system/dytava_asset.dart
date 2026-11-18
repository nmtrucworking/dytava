import 'dart:math' as math;

import 'package:excelcompare_core/excelcompare_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../domain/workflow.dart';
import 'dytava_colors.dart';
import 'dytava_icons.dart';
import 'dytava_illustrations.dart';

/// Displays the approved vector assets without decoding large 4K bitmaps.
class DytavaAsset extends StatelessWidget {
  const DytavaAsset(
    this.asset, {
    super.key,
    this.size = 24,
    this.width,
    this.height,
    this.color,
    this.label,
  });

  final String asset;
  final double size;
  final double? width;
  final double? height;
  final Color? color;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final resolvedAsset = asset.contains('/icons/svg/color/')
        ? asset.replaceFirst('/icons/svg/color/', '/icons/svg/glyph/')
        : asset;
    final effectiveColor =
        color ??
        (asset.contains('/icons/svg/')
            ? BrandIcon.defaultSemanticColor(asset, context)
            : null);

    return SvgPicture.asset(
      resolvedAsset,
      width: width ?? size,
      height: height ?? size,
      fit: BoxFit.contain,
      colorFilter: effectiveColor == null
          ? null
          : ColorFilter.mode(effectiveColor, BlendMode.srcIn),
      semanticsLabel: label,
      excludeFromSemantics: label == null,
    );
  }
}

/// Thành phần chuẩn hóa hiển thị Functional Icons, File Format Icons và Status Icons của Dytava.
/// - Tự động sử dụng bản `svg/glyph/` (`24×24` vector thuần) cho các functional icons trong UI
///   và tô màu ngữ nghĩa chuẩn Dytava v2.0 (thích ứng với `IconTheme` của nút bấm / AppBar).
/// - Giữ nguyên màu đa sắc gốc cho `brand/svg/` và `formats/svg/`.
class BrandIcon extends StatelessWidget {
  const BrandIcon(
    this.asset, {
    super.key,
    this.size = 20,
    this.width,
    this.height,
    this.color,
    this.semanticLabel,
  });

  final String asset;
  final double size;
  final double? width;
  final double? height;
  final Color? color;
  final String? semanticLabel;

  /// Biểu tượng định dạng tệp nguồn (`XLSX`, `CSV`, `TSV`, `PNG`, `JPEG`)
  factory BrandIcon.format(
    SourceFormat format, {
    Key? key,
    double size = 24,
    String? semanticLabel,
  }) => BrandIcon(
    DytavaIcons.forFormat(format),
    key: key,
    size: size,
    semanticLabel: semanticLabel,
  );

  /// Biểu tượng kết luận đối chiếu (`EXACT`, `EQUIVALENT`, `DIFFERENT`, `UNRESOLVED`)
  factory BrandIcon.decision(
    DecisionStatus status, {
    Key? key,
    double size = 18,
    String? semanticLabel,
  }) => BrandIcon(
    DytavaIcons.forDecision(status),
    key: key,
    size: size,
    semanticLabel: semanticLabel,
  );

  /// Biểu tượng kiểu dữ liệu ngữ nghĩa (`IDENTIFIER`, `DECIMAL`, `FREE_TEXT`, `BOOLEAN`, `PERCENTAGE`)
  factory BrandIcon.semanticType(
    SemanticType type, {
    Key? key,
    double size = 20,
    String? semanticLabel,
  }) => BrandIcon(
    DytavaIcons.forSemanticType(type),
    key: key,
    size: size,
    semanticLabel: semanticLabel,
  );

  /// Biểu tượng trạng thái nạp nguồn (`UNSELECTED`, `SELECTED`, `PREVIEW_READY`, `NEEDS_REVIEW`, ...)
  factory BrandIcon.inputState(
    InputState state, {
    Key? key,
    double size = 18,
    String? semanticLabel,
  }) => BrandIcon(
    DytavaIcons.forInputState(state),
    key: key,
    size: size,
    semanticLabel: semanticLabel,
  );

  /// Phân giải màu ngữ nghĩa chuẩn DYTAVA — Precision Workspace cho các functional icons
  static Color defaultSemanticColor(String asset, BuildContext context) {
    final ambientColor = IconTheme.of(context).color;
    // Nếu đang nằm trong FilledButton nền đậm (chữ/icon trắng hoặc đen), ưu tiên màu ambient của nút
    if (ambientColor == Colors.white || ambientColor == DytavaColors.white) {
      return DytavaColors.white;
    }
    if (ambientColor == DytavaColors.graphite) {
      return DytavaColors.graphite;
    }
    if (asset.endsWith('/exact.svg') ||
        asset.endsWith('/success.svg') ||
        asset.endsWith('/added.svg') ||
        asset.endsWith('/shield.svg')) {
      return DytavaColors.exact;
    }
    if (asset.endsWith('/different.svg') ||
        asset.endsWith('/error.svg') ||
        asset.endsWith('/delete.svg') ||
        asset.endsWith('/removed.svg') ||
        asset.endsWith('/differences.svg')) {
      return DytavaColors.different;
    }
    if (asset.endsWith('/unresolved.svg') ||
        asset.endsWith('/warning.svg') ||
        asset.endsWith('/duplicate.svg')) {
      return DytavaColors.unresolved;
    }
    if (asset.endsWith('/equivalent.svg')) {
      return DytavaColors.lime600;
    }
    // Mặc định các icon chức năng mang màu Graphite chuẩn Data Instrument
    return DytavaColors.graphite;
  }

  @override
  Widget build(BuildContext context) {
    final isFunctionalIcon = asset.contains('/icons/svg/');
    final resolvedAsset = asset.contains('/icons/svg/color/')
        ? asset.replaceFirst('/icons/svg/color/', '/icons/svg/glyph/')
        : (asset.contains('/icons/svg/outline/')
              ? asset.replaceFirst('/icons/svg/outline/', '/icons/svg/glyph/')
              : asset);
    final effectiveColor =
        color ??
        (isFunctionalIcon ? defaultSemanticColor(asset, context) : null);

    return SvgPicture.asset(
      resolvedAsset,
      width: width ?? size,
      height: height ?? size,
      fit: BoxFit.contain,
      colorFilter: effectiveColor == null
          ? null
          : ColorFilter.mode(effectiveColor, BlendMode.srcIn),
      semanticsLabel: semanticLabel,
      excludeFromSemantics: semanticLabel == null,
    );
  }
}

/// Thành phần chuẩn hóa hiển thị Illustration Library v1.0 của Dytava theo trạng thái nghiệp vụ.
/// - Tự động thích ứng kích thước theo chiều rộng thiết bị (320dp / 360dp / 412dp / tablet) và tỷ lệ chữ.
/// - Illustration trang trí mặc định loại khỏi thứ tự đọc màn hình (`excludeFromSemantics: true`)
///   để không làm nhiễu TalkBack; chỉ công bố nhãn ngữ nghĩa khi truyền `semanticLabel`.
class BrandIllustration extends StatelessWidget {
  const BrandIllustration(
    this.asset, {
    super.key,
    this.size = 96,
    this.maxHeight,
    this.semanticLabel,
  });

  final String asset;
  final double size;
  final double? maxHeight;
  final String? semanticLabel;

  /// Hero illustration cho màn hình Trang chủ (`SCR-01`)
  factory BrandIllustration.hero({
    Key? key,
    bool hasActiveSession = false,
    double maxHeight = 148,
    String? semanticLabel,
  }) => BrandIllustration(
    hasActiveSession
        ? DytavaIllustrations.heroEmptyWorkspace
        : DytavaIllustrations.heroGetStarted,
    key: key,
    size: maxHeight,
    maxHeight: maxHeight,
    semanticLabel: semanticLabel,
  );

  /// Empty illustration khi chưa chọn tệp nguồn hoặc ảnh OCR (`SCR-02`)
  factory BrandIllustration.emptySource({
    Key? key,
    bool isImage = false,
    double size = 76,
    String? semanticLabel,
  }) => BrandIllustration(
    isImage ? DytavaIllustrations.emptyOcr : DytavaIllustrations.emptyFiles,
    key: key,
    size: size,
    semanticLabel: semanticLabel,
  );

  /// Empty illustration khi chưa ghép cột nào (`SCR-05`)
  factory BrandIllustration.emptyMapping({
    Key? key,
    double size = 80,
    String? semanticLabel,
  }) => BrandIllustration(
    DytavaIllustrations.emptyMapping,
    key: key,
    size: size,
    semanticLabel: semanticLabel,
  );

  /// Empty illustration khi bộ lọc trạng thái không có kết quả (`SCR-08`)
  factory BrandIllustration.emptyFilter({
    Key? key,
    double size = 84,
    String? semanticLabel,
  }) => BrandIllustration(
    DytavaIllustrations.emptyFilter,
    key: key,
    size: size,
    semanticLabel: semanticLabel,
  );

  /// Illustration trạng thái đang xử lý theo giai đoạn (`SCR-03`, `SCR-04`, `SCR-07`, `SCR-10`)
  factory BrandIllustration.processing({
    Key? key,
    required String asset,
    double size = 92,
    String? semanticLabel,
  }) => BrandIllustration(
    asset,
    key: key,
    size: size,
    semanticLabel: semanticLabel,
  );

  /// Illustration xác nhận tác vụ hoàn tất (`successImport`, `successCompare`)
  factory BrandIllustration.success({
    Key? key,
    required String asset,
    double size = 64,
    String? semanticLabel,
  }) => BrandIllustration(
    asset,
    key: key,
    size: size,
    semanticLabel: semanticLabel,
  );

  /// Illustration cho 4 trạng thái quyết định (`EXACT`, `EQUIVALENT`, `DIFFERENT`, `UNRESOLVED`)
  factory BrandIllustration.verdict(
    DecisionStatus status, {
    Key? key,
    double size = 60,
    String? semanticLabel,
  }) => BrandIllustration(
    DytavaIllustrations.forVerdict(status),
    key: key,
    size: size,
    semanticLabel: semanticLabel,
  );

  /// Illustration phản ánh lỗi hoặc cảnh báo từ `WorkflowIssue`
  factory BrandIllustration.issue(
    WorkflowIssue issue, {
    Key? key,
    double size = 60,
    String? semanticLabel,
  }) => BrandIllustration(
    DytavaIllustrations.forIssueCode(issue.code),
    key: key,
    size: size,
    semanticLabel: semanticLabel,
  );

  /// Illustration hướng dẫn ngữ cảnh (`onboardingImport`, `onboardingMapping`, `onboardingPolicy`, `onboardingReport`)
  factory BrandIllustration.onboarding(
    String asset, {
    Key? key,
    double maxHeight = 92,
    String? semanticLabel,
  }) => BrandIllustration(
    asset,
    key: key,
    size: maxHeight,
    maxHeight: maxHeight,
    semanticLabel: semanticLabel,
  );

  /// Illustration bảo mật xử lý cục bộ trên thiết bị (`securityLocal`)
  factory BrandIllustration.securityLocal({
    Key? key,
    double size = 56,
    String? semanticLabel,
  }) => BrandIllustration(
    DytavaIllustrations.securityLocal,
    key: key,
    size: size,
    semanticLabel: semanticLabel,
  );

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    // Thu gọn nhẹ kích thước illustration trên màn hình nhỏ (320dp) hoặc khi font phóng to 200%
    final compactFactor = screenWidth < 350
        ? 0.80
        : (textScale > 1.5 ? 0.85 : 1.0);
    final isWide = DytavaIllustrations.isWide(asset);
    final effectiveHeight = (maxHeight ?? size) * compactFactor;
    final effectiveWidth = isWide
        ? math.min(screenWidth - 48, effectiveHeight * (16 / 9))
        : effectiveHeight;

    return SvgPicture.asset(
      asset,
      width: effectiveWidth,
      height: effectiveHeight,
      fit: BoxFit.contain,
      semanticsLabel: semanticLabel,
      excludeFromSemantics: semanticLabel == null,
    );
  }
}
