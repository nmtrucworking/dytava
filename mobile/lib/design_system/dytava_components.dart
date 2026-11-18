import 'dart:math' as math;

import 'package:excelcompare_core/excelcompare_core.dart';
import 'package:flutter/material.dart';

import '../domain/text_difference.dart';
import '../domain/workflow.dart';
import '../features/shared/text_difference_evidence.dart';
import 'dytava_asset.dart';
import 'dytava_colors.dart';
import 'dytava_icons.dart';
import 'dytava_illustrations.dart';
import 'dytava_typography.dart';

/// Huy hiệu trạng thái so sánh chuẩn thương hiệu Dytava v2.0
/// Sử dụng `BrandIcon` SVG chính thức và bổ sung Semantics đầy đủ cho TalkBack / VoiceOver.
class DytavaStatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final Color backgroundColor;
  final String? iconAsset;
  final IconData? iconData;
  final String? semanticLabel;

  const DytavaStatusBadge({
    super.key,
    required this.label,
    required this.color,
    required this.backgroundColor,
    this.iconAsset,
    this.iconData,
    this.semanticLabel,
  });

  factory DytavaStatusBadge.exact() => const DytavaStatusBadge(
    label: 'EXACT',
    color: DytavaColors.exact,
    backgroundColor: DytavaColors.exactBg,
    iconAsset: DytavaIcons.exact,
    semanticLabel: 'Trạng thái EXACT: Trùng khớp hoàn toàn',
  );

  factory DytavaStatusBadge.equivalent() => const DytavaStatusBadge(
    label: 'EQUIVALENT',
    color: DytavaColors.equivalent,
    backgroundColor: DytavaColors.equivalentBg,
    iconAsset: DytavaIcons.equivalent,
    semanticLabel: 'Trạng thái EQUIVALENT: Tương đương sau chuẩn hóa',
  );

  factory DytavaStatusBadge.different() => const DytavaStatusBadge(
    label: 'DIFFERENT',
    color: DytavaColors.different,
    backgroundColor: DytavaColors.differentBg,
    iconAsset: DytavaIcons.different,
    semanticLabel: 'Trạng thái DIFFERENT: Khác biệt giá trị',
  );

  factory DytavaStatusBadge.unresolved() => const DytavaStatusBadge(
    label: 'UNRESOLVED',
    color: DytavaColors.unresolved,
    backgroundColor: DytavaColors.unresolvedBg,
    iconAsset: DytavaIcons.unresolved,
    semanticLabel: 'Trạng thái UNRESOLVED: Chưa đủ căn cứ kết luận',
  );

  factory DytavaStatusBadge.added({String label = 'ROW_ADDED'}) =>
      DytavaStatusBadge(
        label: label,
        color: DytavaColors.exact,
        backgroundColor: DytavaColors.exactBg,
        iconAsset: DytavaIcons.added,
        semanticLabel: 'Trạng thái cấu trúc: Hàng được thêm ($label)',
      );

  factory DytavaStatusBadge.removed({String label = 'ROW_REMOVED'}) =>
      DytavaStatusBadge(
        label: label,
        color: DytavaColors.different,
        backgroundColor: DytavaColors.differentBg,
        iconAsset: DytavaIcons.removed,
        semanticLabel: 'Trạng thái cấu trúc: Hàng bị thiếu ($label)',
      );

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: semanticLabel ?? 'Trạng thái so sánh: $label',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.35), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (iconAsset != null) ...[
              BrandIcon(iconAsset!, size: 16),
              const SizedBox(width: 4),
            ] else if (iconData != null) ...[
              Icon(iconData, size: 14, color: color),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                label,
                style: DytavaTypography.labelSmall.copyWith(color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Thẻ "Phiên hiện tại — Tiếp tục phiên so sánh" trên màn hình Trang chủ (`SCR-01`).
/// Hiển thị khi đang có phiên làm việc hợp lệ trong bộ nhớ tạm để người dùng quay lại ngay.
class DytavaSessionResumeCard extends StatelessWidget {
  final String stageLabel;
  final String sourceSummary;
  final bool hasCompletedResult;
  final VoidCallback onResume;
  final VoidCallback? onCloseSession;

  const DytavaSessionResumeCard({
    super.key,
    required this.stageLabel,
    required this.sourceSummary,
    required this.onResume,
    this.hasCompletedResult = false,
    this.onCloseSession,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label:
          'Phiên hiện tại: $stageLabel. $sourceSummary. Chạm Tiếp tục phiên so sánh để mở lại.',
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: DytavaColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: DytavaColors.primary.withValues(alpha: 0.35),
            width: 1.2,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x08000000),
              offset: Offset(0, 2),
              blurRadius: 8,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: DytavaColors.softBlue,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: BrandIcon(
                    hasCompletedResult
                        ? DytavaIcons.success
                        : DytavaIcons.compareProgress,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Phiên hiện tại',
                        style: DytavaTypography.titleMedium,
                      ),
                      Text(
                        stageLabel,
                        style: DytavaTypography.bodySmall.copyWith(
                          color: DytavaColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: hasCompletedResult
                        ? DytavaColors.softGreen
                        : DytavaColors.softBlue,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    hasCompletedResult ? 'Đã có kết quả' : 'Đang mở',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: hasCompletedResult
                          ? DytavaColors.exact
                          : DytavaColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(sourceSummary, style: DytavaTypography.bodyMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      backgroundColor: DytavaColors.softBlue,
                      foregroundColor: DytavaColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: onResume,
                    icon: const BrandIcon(DytavaIcons.forward, size: 18),
                    label: const Text(
                      'Tiếp tục phiên so sánh',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                if (onCloseSession != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Đóng phiên hiện tại',
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    onPressed: onCloseSession,
                    icon: const BrandIcon(DytavaIcons.delete, size: 20),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Thanh hành động cố định ở cuối màn hình (Sticky Bottom Action Bar) cho Guided Mobile Workflow.
/// Giữ thao tác chính (Primary CTA) luôn trong tầm ngón cái mà không phải cuộn hết danh sách dài.
class DytavaStickyActionBar extends StatelessWidget {
  final String primaryLabel;
  final VoidCallback? onPrimaryPressed;
  final String? primaryIconAsset;
  final String? secondaryLabel;
  final VoidCallback? onSecondaryPressed;
  final String? helperText;

  const DytavaStickyActionBar({
    super.key,
    required this.primaryLabel,
    required this.onPrimaryPressed,
    this.primaryIconAsset,
    this.secondaryLabel,
    this.onSecondaryPressed,
    this.helperText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: DytavaColors.white,
        border: Border(top: BorderSide(color: DytavaColors.border, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Color(0x0A000000),
            offset: Offset(0, -2),
            blurRadius: 8,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (helperText != null) ...[
                Text(
                  helperText!,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: DytavaTypography.bodySmall.copyWith(
                    color: DytavaColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
              ],
              Row(
                children: [
                  if (secondaryLabel != null && onSecondaryPressed != null) ...[
                    Expanded(
                      flex: 2,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(48, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: onSecondaryPressed,
                        child: Text(
                          secondaryLabel!,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    flex: 3,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: DytavaColors.primary,
                        foregroundColor: DytavaColors.white,
                        minimumSize: const Size(48, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: onPrimaryPressed,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (primaryIconAsset != null) ...[
                            BrandIcon(primaryIconAsset!, size: 18),
                            const SizedBox(width: 8),
                          ],
                          Flexible(
                            child: Text(
                              primaryLabel,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: DytavaTypography.labelLarge,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Thẻ kết quả so sánh (Result Card) chuẩn Brand Showcase Dytava
/// Đã tối ưu phân cấp thông tin (P1):
/// - Hàng 1 (Ưu tiên cao): Ô khác biệt & Chưa kết luận (chữ lớn, rõ ràng, không thu nhỏ quá mức)
/// - Hàng 2 (Thông tin bổ trợ): Ô tương đồng, Tổng cặp ô & Tỷ lệ nhất quán
class DytavaResultCard extends StatelessWidget {
  final String fileA;
  final String fileB;
  final int totalPairs;
  final int equivalentCount;
  final int differentCount;
  final int unresolvedCount;
  final VoidCallback? onTap;

  const DytavaResultCard({
    super.key,
    required this.fileA,
    required this.fileB,
    required this.totalPairs,
    required this.equivalentCount,
    required this.differentCount,
    required this.unresolvedCount,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final matchedSame = math.max(
      0,
      totalPairs - differentCount - unresolvedCount,
    );
    final consistencyPct = totalPairs > 0
        ? ((matchedSame / totalPairs) * 100).toStringAsFixed(1)
        : '0.0';

    return Semantics(
      button: onTap != null,
      label:
          'Kết quả đối chiếu $fileA và $fileB. Hoàn thành. '
          '$differentCount ô khác biệt, $unresolvedCount ô chưa kết luận, '
          '$matchedSame ô tương đồng trên tổng số $totalPairs cặp ô. '
          'Tỷ lệ nhất quán $consistencyPct phần trăm.',
      child: Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: DytavaColors.softGreen,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: const BrandIcon(DytavaIcons.fileXlsx, size: 24),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Kết quả đối chiếu',
                              style: DytavaTypography.titleMedium,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$fileA ↔ $fileB',
                              style: DytavaTypography.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: DytavaColors.softGreen,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            BrandIcon(DytavaIcons.success, size: 16),
                            SizedBox(width: 4),
                            Text(
                              'Hoàn thành',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: DytavaColors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Hàng 1 (Ưu tiên cao): Chỉ số Sai khác & Chưa kết luận
                  Row(
                    children: [
                      Expanded(
                        child: _PriorityMetricBox(
                          count: '$differentCount',
                          label: 'Ô khác biệt',
                          color: DytavaColors.red,
                          bgColor: DytavaColors.softRed,
                          emphasized: differentCount > 0,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _PriorityMetricBox(
                          count: '$unresolvedCount',
                          label: 'Chưa kết luận',
                          color: DytavaColors.unresolved,
                          bgColor: DytavaColors.unresolvedBg,
                          emphasized: unresolvedCount > 0,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Hàng 2 (Bổ trợ): Ô tương đồng, Tương đương & Tỷ lệ nhất quán
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: DytavaColors.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: DytavaColors.border),
                    ),
                    child: Wrap(
                      spacing: 16,
                      runSpacing: 6,
                      alignment: WrapAlignment.spaceBetween,
                      children: [
                        _SecondaryMetricItem(
                          label: 'Ô tương đồng',
                          value: '$matchedSame/$totalPairs',
                          color: DytavaColors.exact,
                        ),
                        _SecondaryMetricItem(
                          label: 'Tương đương',
                          value: '$equivalentCount',
                          color: DytavaColors.equivalent,
                        ),
                        _SecondaryMetricItem(
                          label: 'Tỷ lệ nhất quán',
                          value: '$consistencyPct%',
                          color: DytavaColors.primary,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PriorityMetricBox extends StatelessWidget {
  final String count;
  final String label;
  final Color color;
  final Color bgColor;
  final bool emphasized;

  const _PriorityMetricBox({
    required this.count,
    required this.label,
    required this.color,
    required this.bgColor,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: emphasized ? 0.55 : 0.25),
          width: emphasized ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            count,
            style: DytavaTypography.metricNumber.copyWith(
              color: color,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: DytavaTypography.bodySmall.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _SecondaryMetricItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SecondaryMetricItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label: ',
            style: DytavaTypography.bodySmall.copyWith(
              color: DytavaColors.textSecondary,
            ),
          ),
          TextSpan(
            text: value,
            style: DytavaTypography.dataSmall.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Thẻ "Các khác biệt cần kiểm tra" (Data-first UX & Progressive Disclosure)
/// Giúp người dùng thấy ngay vấn đề, giá trị Nguồn A vs Nguồn B và nguyên nhân sai khác
/// trước khi phải thao tác với toàn bộ lưới bảng tính.
class DytavaPriorityDiffCard extends StatelessWidget {
  final CellDifference cell;
  final VoidCallback onInspectDetail;
  final VoidCallback onQuickBottomSheet;

  const DytavaPriorityDiffCard({
    super.key,
    required this.cell,
    required this.onInspectDetail,
    required this.onQuickBottomSheet,
  });

  static String summarizeCause(CellDifference cell) {
    final status = cell.decision.status;
    final rawA = cell.a.rawLexeme;
    final rawB = cell.b.rawLexeme;
    if (status == DecisionStatus.unresolved) {
      final reason = cell.decision.reason?.name ?? 'unresolved';
      return 'Chưa đủ căn cứ kết luận ($reason · kiểm tra kiểu dữ liệu/khóa)';
    }
    if (rawA != null && rawB != null && rawA != rawB) {
      final diff = TextDifference.between(rawA, rawB);
      if (diff != null) {
        if (diff.partA.trim().isEmpty && diff.partB.trim().isEmpty) {
          return 'Khác biệt ở khoảng trắng (${diff.description})';
        }
        return diff.description;
      }
    }
    if (status == DecisionStatus.equivalent) {
      return 'Khác biểu diễn thô nhưng tương đương sau chuẩn hóa (${cell.decision.ruleId})';
    }
    return 'Khác biệt giá trị sau chuẩn hóa (${cell.decision.ruleId})';
  }

  @override
  Widget build(BuildContext context) {
    final isDiff = cell.decision.status == DecisionStatus.different;
    final statusColor = isDiff
        ? DytavaColors.different
        : DytavaColors.unresolved;
    final statusBg = isDiff
        ? DytavaColors.differentBg
        : DytavaColors.unresolvedBg;
    final statusLabel = isDiff ? 'Khác biệt' : 'Chưa kết luận';
    final rawA = cell.a.rawLexeme ?? '[${cell.a.kind.name}]';
    final rawB = cell.b.rawLexeme ?? '[${cell.b.kind.name}]';
    final cause = summarizeCause(cell);

    return Semantics(
      container: true,
      label:
          'Hàng ${cell.rowA}, cột ${cell.mapping.fieldA}, trạng thái $statusLabel. '
          'Nguồn A: $rawA. Nguồn B: $rawB. Nguyên nhân: $cause.',
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: DytavaColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: statusColor.withValues(alpha: 0.45),
            width: 1.2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 6,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    BrandIcon.decision(cell.decision.status, size: 18),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Hàng ${cell.rowA} · Cột ${cell.mapping.fieldA}',
                        style: DytavaTypography.titleMedium,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    statusLabel,
                    style: DytavaTypography.labelSmall.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: DytavaColors.softBlue,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nguồn A (${cell.locationA ?? cell.rowA})',
                          style: DytavaTypography.labelSmall.copyWith(
                            color: DytavaColors.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          rawA,
                          style: DytavaTypography.dataMedium.copyWith(
                            fontWeight: FontWeight.w700,
                            color: DytavaColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nguồn B (${cell.locationB ?? cell.rowB})',
                          style: DytavaTypography.labelSmall.copyWith(
                            color: statusColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          rawB,
                          style: DytavaTypography.dataMedium.copyWith(
                            fontWeight: FontWeight.w700,
                            color: DytavaColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: DytavaColors.background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const BrandIcon(DytavaIcons.search, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      cause,
                      style: DytavaTypography.bodySmall.copyWith(
                        color: DytavaColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed: onQuickBottomSheet,
                  icon: const BrandIcon(DytavaIcons.preview, size: 18),
                  label: const Text('Xem nhanh (Sheet)'),
                ),
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed: onInspectDetail,
                  icon: const BrandIcon(DytavaIcons.openExternal, size: 18),
                  label: const Text('Xem chi tiết'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Hiển thị Bottom Sheet chi tiết ô so sánh (P0 — Mở chi tiết bằng Bottom Sheet & Hoàn thiện Result Detail)
Future<void> showDytavaCellDetailBottomSheet({
  required BuildContext context,
  required CellDifference cell,
  VoidCallback? onOpenFullDetail,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: DytavaColors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) {
      final rawA = cell.a.rawLexeme ?? '[không có lexeme]';
      final rawB = cell.b.rawLexeme ?? '[không có lexeme]';
      final canonA = cell.decision.left?.label ?? '[không đủ căn cứ]';
      final canonB = cell.decision.right?.label ?? '[không đủ căn cứ]';
      final statusBadge = switch (cell.decision.status) {
        DecisionStatus.exact => DytavaStatusBadge.exact(),
        DecisionStatus.equivalent => DytavaStatusBadge.equivalent(),
        DecisionStatus.different => DytavaStatusBadge.different(),
        DecisionStatus.unresolved => DytavaStatusBadge.unresolved(),
      };

      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.85,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    BrandIllustration.verdict(cell.decision.status, size: 44),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Chi tiết ô · ${cell.mapping.fieldA} ↔ ${cell.mapping.fieldB}',
                        style: DytavaTypography.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Đóng chi tiết ô',
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      icon: const BrandIcon(DytavaIcons.close, size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    statusBadge,
                    Text(
                      'Hàng ${cell.rowA} ↔ ${cell.rowB}',
                      style: DytavaTypography.dataSmall.copyWith(
                        color: DytavaColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                const Text(
                  '1. Phân biệt Giá trị gốc (Raw) & Sau chuẩn hóa (Canonical)',
                  style: DytavaTypography.titleMedium,
                ),
                const SizedBox(height: 8),
                _DetailSideComparisonBox(
                  sideLabel: 'Nguồn A',
                  location: cell.locationA ?? cell.rowA,
                  physicalKind: cell.a.kind.name,
                  rawText: rawA,
                  canonicalText: canonA,
                  accentColor: DytavaColors.primary,
                ),
                const SizedBox(height: 8),
                _DetailSideComparisonBox(
                  sideLabel: 'Nguồn B',
                  location: cell.locationB ?? cell.rowB,
                  physicalKind: cell.b.kind.name,
                  rawText: rawB,
                  canonicalText: canonB,
                  accentColor: DytavaColors.purple,
                ),
                if (cell.a.rawLexeme != null &&
                    cell.b.rawLexeme != null &&
                    cell.a.rawLexeme != cell.b.rawLexeme) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: DytavaColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: DytavaColors.border),
                    ),
                    child: TextDifferenceEvidence(
                      a: cell.a.rawLexeme!,
                      b: cell.b.rawLexeme!,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: DytavaColors.softBlue,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '2. Nguyên nhân & Căn cứ quyết định (Rationale)',
                        style: DytavaTypography.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DytavaPriorityDiffCard.summarizeCause(cell),
                        style: DytavaTypography.bodyMedium.copyWith(
                          color: DytavaColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Rule: ${cell.decision.ruleId}'
                        '${cell.decision.reason != null ? ' · Reason: ${cell.decision.reason!.name}' : ''}',
                        style: DytavaTypography.dataSmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(48, 48),
                        ),
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        child: const Text('Đóng'),
                      ),
                    ),
                    if (onOpenFullDetail != null) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: DytavaColors.primary,
                            minimumSize: const Size(48, 48),
                          ),
                          onPressed: () {
                            Navigator.of(sheetContext).pop();
                            onOpenFullDetail();
                          },
                          child: const Text('Mở trang chi tiết'),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _DetailSideComparisonBox extends StatelessWidget {
  final String sideLabel;
  final String location;
  final String physicalKind;
  final String rawText;
  final String canonicalText;
  final Color accentColor;

  const _DetailSideComparisonBox({
    required this.sideLabel,
    required this.location,
    required this.physicalKind,
    required this.rawText,
    required this.canonicalText,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DytavaColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Text(
                '$sideLabel · Vị trí: $location',
                style: DytavaTypography.labelLarge.copyWith(color: accentColor),
              ),
              Text(
                'Physical kind: $physicalKind',
                style: DytavaTypography.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 6),
          SelectableText(
            'Raw: $rawText',
            style: DytavaTypography.dataMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: DytavaColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          SelectableText(
            'Canonical: $canonicalText',
            style: DytavaTypography.dataSmall.copyWith(
              color: DytavaColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Hộp thoại / Bottom Sheet xác nhận cấu hình tổng hợp (P0 — Kiểm soát xác nhận cấu hình)
/// Hiển thị rõ:
/// 1. Khóa ghép & Chế độ ghép hàng
/// 2. Chính sách chuẩn hóa (Policy) từng cột
/// 3. Chiều so sánh (A → B hoặc B → A)
/// Không cho phép ngầm chấp thuận chính sách chưa được người dùng xác nhận.
Future<bool?> showDytavaConfigConfirmationSheet({
  required BuildContext context,
  required ComparisonConfiguration config,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: DytavaColors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) {
      final resolvedKeys =
          config.mode == MatchingMode.key && config.keys.isEmpty
          ? (config.mappings.any((m) => m.fieldA == 'id')
                ? const ['id']
                : (config.mappings.isNotEmpty
                      ? [config.mappings.first.fieldA]
                      : const <String>[]))
          : config.keys;
      final directionLabel = config.direction == ComparisonDirection.aToB
          ? 'A → B (Chỉ ở B: thêm · Chỉ ở A: thiếu)'
          : 'B → A (Chỉ ở A: thêm · Chỉ ở B: thiếu)';

      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.85,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const BrandIcon(DytavaIcons.policy, size: 24),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Xác nhận cấu hình đối chiếu tổng hợp',
                        style: DytavaTypography.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Đóng hộp thoại xác nhận',
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      onPressed: () => Navigator.of(sheetContext).pop(false),
                      icon: const BrandIcon(DytavaIcons.close, size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Vui lòng kiểm tra rõ khóa ghép, chính sách chuẩn hóa và chiều so sánh trước khi chạy đối chiếu.',
                  style: DytavaTypography.bodyMedium,
                ),
                const Divider(height: 24),
                // 1. Khóa ghép & Chế độ
                _ConfigSummaryItem(
                  iconAsset: DytavaIcons.key,
                  title: '1. Chế độ ghép hàng & Khóa định danh',
                  value: config.mode == MatchingMode.key
                      ? 'Ghép theo khóa (KEY) · Tuple khóa: ${resolvedKeys.isEmpty ? 'Chưa chọn' : resolvedKeys.join(' → ')}'
                      : 'Ghép theo thứ tự hàng (ROW_ORDER)',
                  confirmed: config.modeConfirmed,
                ),
                const SizedBox(height: 10),
                // 2. Chính sách chuẩn hóa từng cột
                _ConfigSummaryItem(
                  iconAsset: DytavaIcons.normalize,
                  title:
                      '2. Chính sách chuẩn hóa (${config.mappings.length} cột ánh xạ)',
                  value: [
                    for (final m in config.mappings)
                      () {
                        final r = config.rules[m.fieldA];
                        if (r == null) {
                          return '${m.fieldA} ↔ ${m.fieldB}: mặc định';
                        }
                        final extra =
                            (r.type == SemanticType.decimal ||
                                r.type == SemanticType.percentage)
                            ? ' (A:${r.separatorA} / B:${r.separatorB}, sai số: ${r.tolerance})'
                            : '';
                        return '• ${m.fieldA} ↔ ${m.fieldB}: ${r.type.name}${r.trim ? ', trim' : ''}$extra';
                      }(),
                  ].join('\n'),
                  confirmed: config.policyConfirmed,
                ),
                const SizedBox(height: 10),
                // 3. Chiều so sánh
                _ConfigSummaryItem(
                  iconAsset: DytavaIcons.compareFiles,
                  title: '3. Chiều so sánh',
                  value: directionLabel,
                  confirmed: config.directionConfirmed,
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(48, 48),
                        ),
                        onPressed: () => Navigator.of(sheetContext).pop(false),
                        child: const Text('Chỉnh sửa lại'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: DytavaColors.primary,
                          minimumSize: const Size(48, 48),
                        ),
                        onPressed: () => Navigator.of(sheetContext).pop(true),
                        icon: const BrandIcon(DytavaIcons.check, size: 18),
                        label: const Text('Xác nhận lần này & Chạy'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _ConfigSummaryItem extends StatelessWidget {
  final String iconAsset;
  final String title;
  final String value;
  final bool confirmed;

  const _ConfigSummaryItem({
    required this.iconAsset,
    required this.title,
    required this.value,
    required this.confirmed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DytavaColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: confirmed
              ? DytavaColors.exact.withValues(alpha: 0.4)
              : DytavaColors.unresolved.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              BrandIcon(iconAsset, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title, style: DytavaTypography.titleMedium),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: confirmed
                      ? DytavaColors.softGreen
                      : DytavaColors.softAmber,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  confirmed ? 'Đã duyệt' : 'Cần xác nhận',
                  style: DytavaTypography.labelSmall.copyWith(
                    color: confirmed
                        ? DytavaColors.exact
                        : DytavaColors.unresolved,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: DytavaTypography.dataSmall.copyWith(
              color: DytavaColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Thẻ quy tắc chuẩn hóa (Policy Card) chuẩn Brand Showcase Dytava
class DytavaPolicyCard extends StatelessWidget {
  final String policyId;
  final String subtitle;
  final bool active;
  final VoidCallback? onTap;

  const DytavaPolicyCard({
    super.key,
    required this.policyId,
    required this.subtitle,
    this.active = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      selected: active,
      label:
          'Mẫu quy tắc $policyId. $subtitle. ${active ? 'Đang dùng' : 'Chạm để chọn'}',
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: active ? DytavaColors.purple : DytavaColors.border,
            width: active ? 1.5 : 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: DytavaColors.softPurple,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: const BrandIcon(DytavaIcons.saveRule, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          policyId,
                          style: DytavaTypography.dataMedium.copyWith(
                            fontWeight: FontWeight.bold,
                            color: DytavaColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(subtitle, style: DytavaTypography.bodySmall),
                      ],
                    ),
                  ),
                  if (active)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: DytavaColors.softPurple,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'Đang dùng',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: DytavaColors.purple,
                        ),
                      ),
                    )
                  else
                    const BrandIcon(DytavaIcons.forward, size: 18),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Thẻ tệp nguồn (File Card) chuẩn Brand Showcase Dytava.
/// Tích hợp trực tiếp `BrandIcon.format(format)` từ kho formats/svg.
class DytavaFileCard extends StatelessWidget {
  final String fileName;
  final String metaText;
  final SourceFormat format;
  final bool verified;
  final VoidCallback? onTap;

  const DytavaFileCard({
    super.key,
    required this.fileName,
    required this.metaText,
    required this.format,
    this.verified = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final (badgeText, badgeBg) = switch (format) {
      SourceFormat.xlsx => ('XLSX', DytavaColors.softGreen),
      SourceFormat.csv => ('CSV', DytavaColors.softBlue),
      SourceFormat.tsv => ('TSV', DytavaColors.softCyan),
      SourceFormat.png || SourceFormat.jpeg => ('OCR', DytavaColors.softPurple),
    };
    return Semantics(
      button: onTap != null,
      label:
          'Tệp nguồn $fileName, định dạng $badgeText, $metaText, ${verified ? 'đã xác thực' : 'chưa xác thực'}',
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: DytavaColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: verified
                ? DytavaColors.exact.withValues(alpha: 0.4)
                : DytavaColors.border,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: BrandIcon.format(format, size: 24),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fileName,
                          style: DytavaTypography.titleMedium.copyWith(
                            fontSize: 14,
                          ),
                        ),
                        Text(metaText, style: DytavaTypography.bodySmall),
                      ],
                    ),
                  ),
                  if (verified)
                    const BrandIcon(
                      DytavaIcons.success,
                      size: 22,
                      semanticLabel: 'Đã xác thực hợp lệ',
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Thẻ lịch sử đối soát (History Card) chuẩn Brand Showcase Dytava
class DytavaHistoryCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String badgeText;
  final VoidCallback? onTap;

  const DytavaHistoryCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.badgeText = 'COMPLETED',
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      label: 'Lịch sử phiên $title, $subtitle, trạng thái $badgeText',
      child: Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: DytavaColors.softBlue,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: const BrandIcon(DytavaIcons.history, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: DytavaTypography.titleMedium),
                        const SizedBox(height: 2),
                        Text(subtitle, style: DytavaTypography.bodySmall),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: DytavaColors.softGreen,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      badgeText,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: DytavaColors.exact,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const BrandIcon(DytavaIcons.forward, size: 18),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Mục tính năng trong lưới tính năng chính Dytava
class DytavaFeatureItem {
  final String label;
  final String iconAsset;
  final Color bgColor;
  final VoidCallback? onTap;

  const DytavaFeatureItem({
    required this.label,
    required this.iconAsset,
    required this.bgColor,
    this.onTap,
  });
}

/// Lưới tính năng chính (Core Features Grid) chuẩn Brand Showcase Dytava
/// Đảm bảo vùng chạm ≥ 48×48dp và co giãn chiều rộng khi phóng to chữ 200%.
class DytavaFeatureGrid extends StatelessWidget {
  final List<DytavaFeatureItem> items;

  const DytavaFeatureGrid({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    final itemWidth = math.max(76.0, 74.0 * math.min(textScale, 1.45));

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final item in items)
          Semantics(
            button: true,
            label: item.label.replaceAll('\n', ' '),
            child: InkWell(
              onTap: item.onTap,
              borderRadius: BorderRadius.circular(12),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: itemWidth,
                  maxWidth: itemWidth + 24,
                  minHeight: 64,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 6,
                  ),
                  decoration: BoxDecoration(
                    color: DytavaColors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: DytavaColors.border),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: item.bgColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: BrandIcon(item.iconAsset, size: 22),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.label,
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: DytavaColors.textPrimary,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Thanh Tab / Bộ lọc danh mục (Filter / View Mode Tabs) chuẩn Brand Showcase
/// Đảm bảo vùng chạm tối thiểu 48dp và Semantics cho TalkBack.
class DytavaFilterTabs extends StatelessWidget {
  final List<String> tabs;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const DytavaFilterTabs({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: DytavaColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DytavaColors.border),
      ),
      child: Row(
        children: [
          for (var i = 0; i < tabs.length; i++)
            Expanded(
              child: Semantics(
                button: true,
                selected: selectedIndex == i,
                label: 'Chế độ xem ${tabs[i]}',
                child: InkWell(
                  onTap: () => onChanged(i),
                  borderRadius: BorderRadius.circular(9),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    constraints: const BoxConstraints(minHeight: 48),
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 6,
                    ),
                    decoration: BoxDecoration(
                      color: selectedIndex == i
                          ? DytavaColors.primary
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      tabs[i],
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: selectedIndex == i
                            ? FontWeight.w700
                            : FontWeight.w600,
                        color: selectedIndex == i
                            ? DytavaColors.white
                            : DytavaColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Thanh điều hướng dưới cùng (Bottom Navigation Bar) chuẩn Dytava Branding v2.0.
/// Sử dụng trực tiếp SVG `BrandIcon` (`navHome`, `navCompare`, `navHistory`, `navLearn`, `navSettings`)
/// thay cho Material Icons, đảm bảo vùng chạm ≥ 48×48dp và Semantics cho TalkBack.
class DytavaBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const DytavaBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  static const _items = [
    ('Trang chủ', DytavaIcons.navHome),
    ('So sánh', DytavaIcons.navCompare),
    ('Lịch sử', DytavaIcons.navHistory),
    ('Học tập', DytavaIcons.navLearn),
    ('Cài đặt', DytavaIcons.navSettings),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: DytavaColors.white,
        border: Border(top: BorderSide(color: DytavaColors.border, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Color(0x0A000000),
            offset: Offset(0, -2),
            blurRadius: 8,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Row(
            children: [
              for (var i = 0; i < _items.length; i++)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: currentIndex == i,
                    label: 'Tab ${_items[i].$1}',
                    child: InkWell(
                      onTap: () => onTap(i),
                      borderRadius: BorderRadius.circular(12),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        constraints: const BoxConstraints(minHeight: 48),
                        padding: const EdgeInsets.symmetric(
                          vertical: 6,
                          horizontal: 2,
                        ),
                        decoration: BoxDecoration(
                          color: currentIndex == i
                              ? DytavaColors.softBlue
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            BrandIcon(_items[i].$2, size: 20),
                            const SizedBox(height: 3),
                            Text(
                              _items[i].$1,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: currentIndex == i
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: currentIndex == i
                                    ? DytavaColors.primary
                                    : DytavaColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bảng xem trước trang tính (Spreadsheet Grid Preview) cho 1 nguồn dữ liệu (P0)
/// Đã thiết kế lại với:
/// - Cột định danh hàng (`#`) cố định bên trái
/// - Vùng dữ liệu cuộn ngang đồng bộ (`SingleChildScrollView(scrollDirection: Axis.horizontal)`)
/// - Chiều rộng cột có giới hạn rõ ràng (`148dp–220dp`) để bảng rộng nhiều cột không bị thu hẹp
/// - Mở Bottom Sheet xem chi tiết toàn bộ các trường của hàng khi chạm.
class DytavaSheetPreviewTable extends StatefulWidget {
  final String sheetTitle;
  final List<TableField> fields;
  final List<TableRecord> records;

  const DytavaSheetPreviewTable({
    super.key,
    required this.sheetTitle,
    required this.fields,
    required this.records,
  });

  @override
  State<DytavaSheetPreviewTable> createState() =>
      _DytavaSheetPreviewTableState();
}

class _DytavaSheetPreviewTableState extends State<DytavaSheetPreviewTable> {
  final List<ScrollController> _controllers = [];
  bool _syncing = false;

  void _ensureControllers(int count) {
    while (_controllers.length < count) {
      final c = ScrollController();
      c.addListener(() => _onScroll(c));
      _controllers.add(c);
    }
  }

  void _onScroll(ScrollController source) {
    if (_syncing || !source.hasClients) return;
    _syncing = true;
    final offset = source.offset;
    for (final c in _controllers) {
      if (c != source && c.hasClients && (c.offset - offset).abs() > 0.5) {
        c.jumpTo(offset.clamp(0.0, c.position.maxScrollExtent));
      }
    }
    _syncing = false;
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _showRowDetailBottomSheet(BuildContext context, TableRecord row) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: DytavaColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const BrandIcon(DytavaIcons.rows, size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${widget.sheetTitle} · Hàng #${row.ordinal + 1}',
                        style: DytavaTypography.titleLarge,
                      ),
                    ),
                    IconButton(
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      onPressed: () => Navigator.of(sheetCtx).pop(),
                      icon: const BrandIcon(DytavaIcons.close, size: 20),
                    ),
                  ],
                ),
                const Divider(height: 20),
                for (final f in widget.fields)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: DytavaColors.background,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${f.label} (${f.id})',
                            style: DytavaTypography.labelLarge.copyWith(
                              color: DytavaColors.primary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          SelectableText(
                            row.cells[f.id]?.rawLexeme ??
                                '[${row.cells[f.id]?.kind.name ?? 'null'}]',
                            style: DytavaTypography.dataMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final previewRows = widget.records.take(5).toList();
    _ensureControllers(previewRows.length + 1);

    return LayoutBuilder(
      builder: (context, constraints) {
        const pinnedWidth = 54.0;
        final availableWidth = math.max(
          200.0,
          constraints.maxWidth - pinnedWidth - 2,
        );
        final colCount = math.max(1, widget.fields.length);
        final colWidth = (availableWidth / colCount).clamp(148.0, 220.0);
        final isScrollable = colWidth * colCount > availableWidth + 4;

        return Container(
          decoration: BoxDecoration(
            color: DytavaColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: DytavaColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header bar của Sheet
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: const BoxDecoration(
                  color: DytavaColors.softBlue,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
                ),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const BrandIcon(DytavaIcons.workbook, size: 18),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            widget.sheetTitle,
                            style: DytavaTypography.labelLarge.copyWith(
                              color: DytavaColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${widget.records.length} hàng × ${widget.fields.length} cột${isScrollable ? ' · ↔ Cuộn ngang' : ''}',
                      style: DytavaTypography.bodySmall.copyWith(
                        color: DytavaColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              // Dòng tiêu đề cột (Cột # cố định + các cột dữ liệu cuộn ngang)
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: pinnedWidth,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 10,
                      ),
                      decoration: const BoxDecoration(
                        color: DytavaColors.background,
                        border: Border(
                          right: BorderSide(color: DytavaColors.border),
                          bottom: BorderSide(color: DytavaColors.border),
                        ),
                      ),
                      alignment: Alignment.centerLeft,
                      child: const Text(
                        '#',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: DytavaColors.textSecondary,
                        ),
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        controller: _controllers[0],
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final f in widget.fields)
                              Container(
                                width: colWidth,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 10,
                                ),
                                decoration: const BoxDecoration(
                                  color: DytavaColors.background,
                                  border: Border(
                                    right: BorderSide(
                                      color: DytavaColors.border,
                                    ),
                                    bottom: BorderSide(
                                      color: DytavaColors.border,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  '${f.label} (${f.id})',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: DytavaColors.textPrimary,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Các hàng dữ liệu
              for (var idx = 0; idx < previewRows.length; idx++)
                Builder(
                  builder: (context) {
                    final row = previewRows[idx];
                    return InkWell(
                      onTap: () => _showRowDetailBottomSheet(context, row),
                      child: IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              width: pinnedWidth,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 10,
                              ),
                              decoration: const BoxDecoration(
                                color: Color(0xFFF8FAFC),
                                border: Border(
                                  right: BorderSide(color: DytavaColors.border),
                                  bottom: BorderSide(
                                    color: DytavaColors.border,
                                  ),
                                ),
                              ),
                              alignment: Alignment.centerLeft,
                              child: Text(
                                '${row.ordinal + 1}',
                                style: DytavaTypography.dataMedium.copyWith(
                                  color: DytavaColors.textSecondary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Expanded(
                              child: SingleChildScrollView(
                                controller: _controllers[idx + 1],
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    for (final f in widget.fields)
                                      Container(
                                        width: colWidth,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 10,
                                        ),
                                        decoration: const BoxDecoration(
                                          border: Border(
                                            right: BorderSide(
                                              color: DytavaColors.border,
                                            ),
                                            bottom: BorderSide(
                                              color: DytavaColors.border,
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          row.cells[f.id]?.rawLexeme ??
                                              '[${row.cells[f.id]?.kind.name ?? 'null'}]',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: DytavaTypography.dataMedium
                                              .copyWith(
                                                color: DytavaColors.textPrimary,
                                              ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Chế độ hiển thị của Sheet Diff 2 Sheets
enum SheetDiffLayoutMode {
  /// Bảng đối chiếu hợp nhất 2 Sheets (Sheet A ↔ Sheet B trong từng ô của bảng)
  unified2Sheets,

  /// Đặt 2 bảng Sheet A và Sheet B song song đối xứng theo từng hàng
  sideBySide2Sheets,
}

/// Component nâng cao: Bảng đối chiếu 2 Sheets (`DytavaSheetDiffView`)
/// - Cố định cột định danh hàng & khóa (`Hàng / Khóa`) bên trái
/// - Cuộn ngang đồng bộ (`SingleChildScrollView(scrollDirection: Axis.horizontal)`) cho bảng rộng nhiều cột
/// - Chiều rộng cột có giới hạn (`172dp–240dp`), không bao giờ bị bóp nghẹt khi số cột tăng
/// - Hỗ trợ mở nhanh chi tiết ô bằng Bottom Sheet (`showDytavaCellDetailBottomSheet`) bên cạnh trang Detail đầy đủ.
class DytavaSheetDiffView extends StatefulWidget {
  final ComparisonResult result;
  final List<CellDifference> visibleCells;
  final void Function(String cellId) onSelectCell;

  const DytavaSheetDiffView({
    super.key,
    required this.result,
    required this.visibleCells,
    required this.onSelectCell,
  });

  @override
  State<DytavaSheetDiffView> createState() => _DytavaSheetDiffViewState();
}

class _DytavaSheetDiffViewState extends State<DytavaSheetDiffView> {
  SheetDiffLayoutMode _mode = SheetDiffLayoutMode.unified2Sheets;
  final List<ScrollController> _scrollControllers = [];
  bool _syncingScroll = false;

  void _ensureScrollControllers(int count) {
    while (_scrollControllers.length < count) {
      final controller = ScrollController();
      controller.addListener(() => _onHorizontalScroll(controller));
      _scrollControllers.add(controller);
    }
  }

  void _onHorizontalScroll(ScrollController source) {
    if (_syncingScroll || !source.hasClients) return;
    _syncingScroll = true;
    final offset = source.offset;
    for (final c in _scrollControllers) {
      if (c != source && c.hasClients && (c.offset - offset).abs() > 0.5) {
        c.jumpTo(offset.clamp(0.0, c.position.maxScrollExtent));
      }
    }
    _syncingScroll = false;
  }

  @override
  void dispose() {
    for (final c in _scrollControllers) {
      c.dispose();
    }
    super.dispose();
  }

  String _statusName(DecisionStatus s) => s.name
      .replaceAllMapped(RegExp('[A-Z]'), (m) => '_${m[0]}')
      .toUpperCase();

  (Color, Color) _statusColors(DecisionStatus s) => switch (s) {
    DecisionStatus.exact => (DytavaColors.exact, DytavaColors.exactBg),
    DecisionStatus.equivalent => (
      DytavaColors.equivalent,
      DytavaColors.equivalentBg,
    ),
    DecisionStatus.different => (
      DytavaColors.different,
      DytavaColors.differentBg,
    ),
    DecisionStatus.unresolved => (
      DytavaColors.unresolved,
      DytavaColors.unresolvedBg,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final mappings = widget.result.plan.config.mappings;
    final rowKeys = <String>[];
    final rowMap = <String, Map<String, CellDifference>>{};
    final rowLabels = <String, (String, String)>{};

    for (final cell in widget.visibleCells) {
      final key = '${cell.rowA}::${cell.rowB}';
      if (!rowMap.containsKey(key)) {
        rowKeys.add(key);
        rowMap[key] = {};
        rowLabels[key] = (cell.rowA, cell.rowB);
      }
      rowMap[key]![cell.mapping.fieldA] = cell;
    }

    _ensureScrollControllers(rowKeys.length + 2);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Thanh chuyển đổi chế độ Sheet Diff: Hợp nhất 2 Sheets vs Song song 2 Sheets
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: DytavaColors.softBlue,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: DytavaColors.primary.withValues(alpha: 0.25),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const BrandIcon(DytavaIcons.compareTable, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Sheet Diff: Sheet A (${widget.result.plan.a.records.length} hàng) ↔ Sheet B (${widget.result.plan.b.records.length} hàng)',
                      style: DytavaTypography.labelLarge.copyWith(
                        color: DytavaColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Cột định danh cố định bên trái · Cuộn ngang để xem nhiều cột · Chạm biểu tượng xem nhanh để mở Bottom Sheet.',
                style: DytavaTypography.bodySmall.copyWith(
                  color: DytavaColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _modeButton(
                      label: 'Bảng hợp nhất (A ↔ B)',
                      iconAsset: DytavaIcons.rows,
                      selected: _mode == SheetDiffLayoutMode.unified2Sheets,
                      onTap: () => setState(
                        () => _mode = SheetDiffLayoutMode.unified2Sheets,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _modeButton(
                      label: 'Song song 2 Sheets (A | B)',
                      iconAsset: DytavaIcons.columns,
                      selected: _mode == SheetDiffLayoutMode.sideBySide2Sheets,
                      onTap: () => setState(
                        () => _mode = SheetDiffLayoutMode.sideBySide2Sheets,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Chú giải màu (Legend) trên Sheet Diff
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _legendChip('EXACT (=)', DytavaColors.exact, DytavaColors.exactBg),
            _legendChip(
              'EQUIVALENT (≈)',
              DytavaColors.equivalent,
              DytavaColors.equivalentBg,
            ),
            _legendChip(
              'DIFFERENT (≠)',
              DytavaColors.different,
              DytavaColors.differentBg,
            ),
            _legendChip(
              'UNRESOLVED (?)',
              DytavaColors.unresolved,
              DytavaColors.unresolvedBg,
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_mode == SheetDiffLayoutMode.unified2Sheets)
          _buildUnifiedSheetDiff(mappings, rowKeys, rowMap, rowLabels)
        else
          _buildSideBySideSheets(mappings, rowKeys, rowMap, rowLabels),
      ],
    );
  }

  Widget _modeButton({
    required String label,
    required String iconAsset,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      selected: selected,
      label: 'Chế độ bảng $label',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            decoration: BoxDecoration(
              color: selected ? DytavaColors.primary : DytavaColors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected ? DytavaColors.primary : DytavaColors.border,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                BrandIcon(iconAsset, size: 16),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: selected
                          ? DytavaColors.white
                          : DytavaColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _legendChip(String text, Color fg, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: fg.withValues(alpha: 0.35)),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }

  String _extractPinnedKeyLabel(Map<String, CellDifference> cellsByField) {
    final keys = widget.result.plan.config.keys;
    if (keys.isNotEmpty) {
      for (final k in keys) {
        final c = cellsByField[k];
        if (c != null) {
          return '$k: ${c.a.rawLexeme ?? c.b.rawLexeme ?? '—'}';
        }
      }
    }
    if (cellsByField.containsKey('id')) {
      final c = cellsByField['id']!;
      return 'id: ${c.a.rawLexeme ?? c.b.rawLexeme ?? '—'}';
    }
    return '';
  }

  /// Chế độ 1: Bảng Sheet Diff hợp nhất 2 Sheets (Cột định danh cố định + Các cột dữ liệu cuộn ngang có giới hạn chiều rộng)
  Widget _buildUnifiedSheetDiff(
    List<FieldMapping> mappings,
    List<String> rowKeys,
    Map<String, Map<String, CellDifference>> rowMap,
    Map<String, (String, String)> rowLabels,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const pinnedColWidth = 74.0;
        final availableWidth = math.max(
          200.0,
          constraints.maxWidth - pinnedColWidth - 2,
        );
        final colCount = math.max(1, mappings.length);
        final colWidth = (availableWidth / colCount).clamp(172.0, 240.0);

        return Container(
          decoration: BoxDecoration(
            color: DytavaColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: DytavaColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header của bảng Sheet Diff (Cột Hàng/Khóa cố định + các cột cuộn ngang)
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: pinnedColWidth,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 10,
                      ),
                      decoration: const BoxDecoration(
                        color: DytavaColors.darkNavy,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(11),
                        ),
                      ),
                      alignment: Alignment.centerLeft,
                      child: const Text(
                        'Hàng /\nKhóa',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: DytavaColors.white,
                        ),
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        controller: _scrollControllers[0],
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final m in mappings)
                              Container(
                                width: colWidth,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 10,
                                ),
                                decoration: const BoxDecoration(
                                  color: DytavaColors.darkNavy,
                                  border: Border(
                                    left: BorderSide(color: Color(0xFF334155)),
                                  ),
                                ),
                                child: Text(
                                  'Cột ${m.fieldA} ↔ ${m.fieldB}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: DytavaColors.white,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Từng hàng của 2 Sheets đã ghép
              for (var rIdx = 0; rIdx < rowKeys.length; rIdx++)
                Builder(
                  builder: (context) {
                    final key = rowKeys[rIdx];
                    final cellsByField = rowMap[key]!;
                    final (rA, rB) = rowLabels[key]!;
                    final pinnedKeyLabel = _extractPinnedKeyLabel(cellsByField);

                    return IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Cột định danh cố định bên trái
                          Container(
                            width: pinnedColWidth,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 8,
                            ),
                            decoration: const BoxDecoration(
                              color: Color(0xFFF8FAFC),
                              border: Border(
                                right: BorderSide(color: DytavaColors.border),
                                bottom: BorderSide(color: DytavaColors.border),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: DytavaColors.softBlue,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '#${rIdx + 1}',
                                    style: DytavaTypography.dataSmall.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: DytavaColors.primary,
                                    ),
                                  ),
                                ),
                                if (pinnedKeyLabel.isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    pinnedKeyLabel,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: DytavaTypography.dataSmall.copyWith(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: DytavaColors.textPrimary,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 2),
                                Text(
                                  '$rA·$rB',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: DytavaColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Các ô dữ liệu cuộn ngang đồng bộ
                          Expanded(
                            child: SingleChildScrollView(
                              controller: _scrollControllers[rIdx + 1],
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  for (final m in mappings)
                                    Container(
                                      width: colWidth,
                                      padding: const EdgeInsets.all(6),
                                      decoration: const BoxDecoration(
                                        border: Border(
                                          right: BorderSide(
                                            color: DytavaColors.border,
                                          ),
                                          bottom: BorderSide(
                                            color: DytavaColors.border,
                                          ),
                                        ),
                                      ),
                                      child: cellsByField.containsKey(m.fieldA)
                                          ? _buildUnifiedDiffCell(
                                              context,
                                              cellsByField[m.fieldA]!,
                                            )
                                          : Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: DytavaColors.background,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              alignment: Alignment.centerLeft,
                                              child: const Text(
                                                '— (ẩn bởi bộ lọc)',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: DytavaColors.textMuted,
                                                ),
                                              ),
                                            ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              // Hiển thị các hàng thêm/bớt (ROW_ADDED / ROW_REMOVED) ngay dưới chân bảng Sheet Diff
              for (final s in widget.result.structural)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: s.kind.contains('ADDED')
                        ? DytavaColors.softGreen
                        : DytavaColors.softRed,
                    border: const Border(
                      bottom: BorderSide(color: DytavaColors.border),
                    ),
                  ),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          BrandIcon(
                            s.kind.contains('ADDED')
                                ? DytavaIcons.added
                                : DytavaIcons.removed,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              '${s.kind} · ${s.side.name.toUpperCase()} · ${s.recordId}',
                              style: DytavaTypography.dataMedium.copyWith(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: s.kind.contains('ADDED')
                                    ? DytavaColors.exact
                                    : DytavaColors.different,
                              ),
                            ),
                          ),
                        ],
                      ),
                      _legendChip(
                        s.side == SourceSide.b
                            ? 'Chỉ có ở Sheet B'
                            : 'Chỉ có ở Sheet A',
                        s.kind.contains('ADDED')
                            ? DytavaColors.exact
                            : DytavaColors.different,
                        DytavaColors.white,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUnifiedDiffCell(BuildContext context, CellDifference cell) {
    final (fg, bg) = _statusColors(cell.decision.status);
    final rawA = cell.a.rawLexeme ?? '[${cell.a.kind.name}]';
    final rawB = cell.b.rawLexeme ?? '[${cell.b.kind.name}]';
    final statusText = _statusName(cell.decision.status);

    return Semantics(
      button: true,
      label:
          'Cột ${cell.mapping.fieldA}, trạng thái $statusText. '
          'Giá trị A: $rawA. Giá trị B: $rawB. Chạm để xem chi tiết.',
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: fg.withValues(alpha: 0.45), width: 1),
        ),
        child: InkWell(
          onTap: () => widget.onSelectCell(cell.id),
          borderRadius: BorderRadius.circular(8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Expanded(
                        // Giữ đúng text '${fieldA}: ${STATUS}' cho kiểm thử & truy vết
                        child: Text(
                          '${cell.mapping.fieldA}: $statusText',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: fg,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () => showDytavaCellDetailBottomSheet(
                          context: context,
                          cell: cell,
                          onOpenFullDetail: () => widget.onSelectCell(cell.id),
                        ),
                        borderRadius: BorderRadius.circular(6),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: BrandIcon(
                            DytavaIcons.preview,
                            size: 16,
                            semanticLabel: 'Mở chi tiết nhanh bằng Bottom Sheet',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'A: $rawA · B: $rawB',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: DytavaTypography.dataSmall.copyWith(
                      fontWeight: FontWeight.w600,
                      color: DytavaColors.textPrimary,
                    ),
                  ),
                  if (cell.decision.status == DecisionStatus.equivalent)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        'Chuẩn hóa: ${cell.decision.left?.label ?? rawA}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: fg),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Chế độ 2: Đặt 2 bảng Sheet A và Sheet B song song cạnh nhau (Side-by-Side 2 Sheets)
  /// Hỗ trợ cuộn ngang khi màn hình hẹp hoặc nhiều cột.
  Widget _buildSideBySideSheets(
    List<FieldMapping> mappings,
    List<String> rowKeys,
    Map<String, Map<String, CellDifference>> rowMap,
    Map<String, (String, String)> rowLabels,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final singleSheetWidth = math.max(
          260.0,
          (constraints.maxWidth - 8) / 2,
        );
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: singleSheetWidth,
                child: _buildSingleSideSheet(
                  context: context,
                  title: 'SHEET A ( gốc )',
                  headerColor: DytavaColors.primary,
                  isSideA: true,
                  mappings: mappings,
                  rowKeys: rowKeys,
                  rowMap: rowMap,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: singleSheetWidth,
                child: _buildSingleSideSheet(
                  context: context,
                  title: 'SHEET B ( đối chiếu )',
                  headerColor: DytavaColors.purple,
                  isSideA: false,
                  mappings: mappings,
                  rowKeys: rowKeys,
                  rowMap: rowMap,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSingleSideSheet({
    required BuildContext context,
    required String title,
    required Color headerColor,
    required bool isSideA,
    required List<FieldMapping> mappings,
    required List<String> rowKeys,
    required Map<String, Map<String, CellDifference>> rowMap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: DytavaColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: DytavaColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: headerColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(9),
              ),
            ),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: DytavaColors.white,
              ),
            ),
          ),
          for (var rIdx = 0; rIdx < rowKeys.length; rIdx++)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: DytavaColors.border)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hàng #${rIdx + 1}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: DytavaColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  for (final m in mappings)
                    if (rowMap[rowKeys[rIdx]]?[m.fieldA] case final cell?)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: InkWell(
                          onTap: () => showDytavaCellDetailBottomSheet(
                            context: context,
                            cell: cell,
                            onOpenFullDetail: () =>
                                widget.onSelectCell(cell.id),
                          ),
                          borderRadius: BorderRadius.circular(6),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 40),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: _statusColors(cell.decision.status).$2,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: _statusColors(
                                    cell.decision.status,
                                  ).$1.withValues(alpha: 0.4),
                                ),
                              ),
                              child: Text(
                                isSideA
                                    ? '${m.fieldA}: ${cell.a.rawLexeme ?? '—'} (${_statusName(cell.decision.status)})'
                                    : '${m.fieldB}: ${cell.b.rawLexeme ?? '—'}',
                                style: DytavaTypography.dataSmall.copyWith(
                                  color: DytavaColors.textPrimary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Trạng thái rỗng chuẩn thương hiệu (Empty State — P1)
/// Sử dụng `BrandIllustration` và `BrandIcon` theo ngữ cảnh.
class DytavaEmptyState extends StatelessWidget {
  final String title;
  final String message;
  final String illustrationAsset;
  final String? actionLabel;
  final VoidCallback? onImport;
  final VoidCallback? onOcr;

  const DytavaEmptyState({
    super.key,
    this.title = 'Sẵn sàng đối chiếu',
    this.message = 'Nhập hai giá trị ở trên rồi bấm So sánh để xem kết quả.',
    this.illustrationAsset = DytavaIllustrations.emptyComparisons,
    this.actionLabel,
    this.onImport,
    this.onOcr,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BrandIllustration(illustrationAsset, size: 120),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: DytavaTypography.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: DytavaTypography.bodyMedium,
            ),
            if (onImport != null || onOcr != null) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  if (onImport != null)
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: DytavaColors.primary,
                        minimumSize: const Size(48, 48),
                      ),
                      onPressed: onImport,
                      icon: const BrandIcon(DytavaIcons.upload, size: 18),
                      label: Text(actionLabel ?? 'Chọn nguồn dữ liệu'),
                    ),
                  if (onOcr != null)
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(48, 48),
                      ),
                      onPressed: onOcr,
                      icon: const BrandIcon(DytavaIcons.ocr, size: 18),
                      label: const Text('Quét OCR mẫu'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
