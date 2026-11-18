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
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      backgroundColor: DytavaColors.limePrimary,
                      foregroundColor: DytavaColors.graphite,
                      elevation: 0,
                      shape: const StadiumBorder(),
                    ),
                    onPressed: onResume,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            'Tiếp tục phiên so sánh',
                            style: TextStyle(
                              fontFamily: DytavaTypography.editorialFont,
                              fontWeight: FontWeight.w800,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: 8),
                        BrandIcon(DytavaIcons.forward, size: 18),
                      ],
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
                          foregroundColor: DytavaColors.graphite,
                          side: const BorderSide(color: DytavaColors.subtleBorder),
                          shape: const StadiumBorder(),
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
                        backgroundColor: DytavaColors.limePrimary,
                        foregroundColor: DytavaColors.graphite,
                        elevation: 0,
                        minimumSize: const Size(48, 48),
                        shape: const StadiumBorder(),
                        textStyle: const TextStyle(
                          fontFamily: DytavaTypography.editorialFont,
                          fontWeight: FontWeight.w800,
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
                              '$fileA → $fileB',
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
    if (cell.decision.explanation != null) return cell.decision.explanation!;
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
                        'Chi tiết ô · ${cell.mapping.fieldA} → ${cell.mapping.fieldB}',
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
                      'Hàng ${cell.rowA} → ${cell.rowB}',
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
                          return '${m.fieldA} → ${m.fieldB}: mặc định';
                        }
                        final extra =
                            (r.type == SemanticType.decimal ||
                                r.type == SemanticType.percentage)
                            ? ' (A:${r.separatorA} / B:${r.separatorB}, sai số: ${r.tolerance})'
                            : '';
                        return '• ${m.fieldA} → ${m.fieldB}: ${r.type.name}${r.trim ? ', trim' : ''}$extra';
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
      SourceFormat.json => ('JSON', DytavaColors.softPurple),
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
          color: DytavaColors.warmSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: verified
                ? DytavaColors.exact.withValues(alpha: 0.5)
                : DytavaColors.subtleBorder,
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

/// Bộ lọc trạng thái hàng theo chuẩn giao diện Table Diff của ExcelCompare.org
enum ExcelDiffRowFilter {
  all,
  added,
  deleted,
  unchanged,
  modified,
}

/// Phân loại trạng thái từng hàng đã căn chỉnh trên bảng đối chiếu 2 Sheets
enum ExcelDiffRowKind {
  header,
  unchanged,
  modified,
  added,
  deleted,
}

/// Mô hình một cột trong bảng Table Diff chuẩn ExcelCompare.org (`A`, `B`, `C`...)
final class _ExcelDiffColumn {
  final int index;
  final String letter;
  final String? fieldA;
  final String? fieldB;
  final String labelA;
  final String labelB;

  const _ExcelDiffColumn({
    required this.index,
    required this.letter,
    required this.fieldA,
    required this.fieldB,
    required this.labelA,
    required this.labelB,
  });

  bool get isMapped => fieldA != null && fieldB != null;

  static String indexToColumnLetter(int index) {
    var n = index;
    final buf = StringBuffer();
    while (n >= 0) {
      buf.writeCharCode(65 + (n % 26));
      n = (n ~/ 26) - 1;
    }
    return buf.toString().split('').reversed.join();
  }
}

/// Mô hình một hàng đã căn chỉnh song song giữa Sheet A (Trái) và Sheet B (Phải)
final class _ExcelDiffAlignedRow {
  final int alignedIndex;
  final ExcelDiffRowKind kind;
  final int? rowNumberA;
  final int? rowNumberB;
  final TableRecord? recordA;
  final TableRecord? recordB;
  final Map<String, CellDifference> cellsByFieldA;

  const _ExcelDiffAlignedRow({
    required this.alignedIndex,
    required this.kind,
    this.rowNumberA,
    this.rowNumberB,
    this.recordA,
    this.recordB,
    this.cellsByFieldA = const {},
  });
}

/// Bảng dữ liệu căn chỉnh đã được tính toán trước (Precomputed Immutable View-Model)
/// giúp cuộn ảo hóa (Virtualized Scrolling) và chọn ô đạt 60/120fps trên thiết bị di động.
final class _ExcelDiffPrecomputedTable {
  final List<_ExcelDiffColumn> columns;
  final _ExcelDiffAlignedRow headerRow;
  final List<_ExcelDiffAlignedRow> allDataRows;
  final int addedCount;
  final int deletedCount;
  final int unchangedCount;
  final int modifiedCount;

  const _ExcelDiffPrecomputedTable({
    required this.columns,
    required this.headerRow,
    required this.allDataRows,
    required this.addedCount,
    required this.deletedCount,
    required this.unchangedCount,
    required this.modifiedCount,
  });

  int get totalCount => allDataRows.length;

  factory _ExcelDiffPrecomputedTable.build(ComparisonResult result) {
    final fieldsAById = {
      for (final f in result.plan.a.fields) f.id: f,
    };
    final fieldsBById = {
      for (final f in result.plan.b.fields) f.id: f,
    };

    final cols = <_ExcelDiffColumn>[];
    final mappedA = <String>{};
    final mappedB = <String>{};

    for (final m in result.plan.config.mappings) {
      final idx = cols.length;
      mappedA.add(m.fieldA);
      mappedB.add(m.fieldB);
      cols.add(
        _ExcelDiffColumn(
          index: idx,
          letter: _ExcelDiffColumn.indexToColumnLetter(idx),
          fieldA: m.fieldA,
          fieldB: m.fieldB,
          labelA: fieldsAById[m.fieldA]?.label ?? m.fieldA,
          labelB: fieldsBById[m.fieldB]?.label ?? m.fieldB,
        ),
      );
    }

    for (final f in result.plan.a.fields) {
      if (!mappedA.contains(f.id)) {
        final idx = cols.length;
        cols.add(
          _ExcelDiffColumn(
            index: idx,
            letter: _ExcelDiffColumn.indexToColumnLetter(idx),
            fieldA: f.id,
            fieldB: null,
            labelA: f.label,
            labelB: '(trống)',
          ),
        );
      }
    }

    for (final f in result.plan.b.fields) {
      if (!mappedB.contains(f.id)) {
        final idx = cols.length;
        cols.add(
          _ExcelDiffColumn(
            index: idx,
            letter: _ExcelDiffColumn.indexToColumnLetter(idx),
            fieldA: null,
            fieldB: f.id,
            labelA: '(trống)',
            labelB: f.label,
          ),
        );
      }
    }

    if (cols.isEmpty) {
      cols.add(
        const _ExcelDiffColumn(
          index: 0,
          letter: 'A',
          fieldA: 'id',
          fieldB: 'id',
          labelA: 'id',
          labelB: 'id',
        ),
      );
    }

    final headerRow = const _ExcelDiffAlignedRow(
      alignedIndex: 0,
      kind: ExcelDiffRowKind.header,
      rowNumberA: 1,
      rowNumberB: 1,
    );

    final recordsAById = {
      for (final r in result.plan.a.records) r.id: r,
    };
    final recordsBById = {
      for (final r in result.plan.b.records) r.id: r,
    };

    final pairOrder = <(String, String)>[];
    final pairCells = <String, Map<String, CellDifference>>{};
    final matchedRowIdsA = <String>{};
    final matchedRowIdsB = <String>{};

    for (final c in result.cells) {
      final key = '${c.rowA}::${c.rowB}';
      if (!pairCells.containsKey(key)) {
        pairOrder.add((c.rowA, c.rowB));
        pairCells[key] = {};
      }
      pairCells[key]![c.mapping.fieldA] = c;
      matchedRowIdsA.add(c.rowA);
      matchedRowIdsB.add(c.rowB);
    }

    final dataRows = <_ExcelDiffAlignedRow>[];
    var addedCount = 0;
    var deletedCount = 0;
    var unchangedCount = 0;
    var modifiedCount = 0;

    for (final (rAId, rBId) in pairOrder) {
      final key = '$rAId::$rBId';
      final cellsMap = pairCells[key]!;
      final recA = recordsAById[rAId];
      final recB = recordsBById[rBId];

      var hasModification = false;
      for (final col in cols) {
        if (col.isMapped) {
          final cell = cellsMap[col.fieldA];
          if (cell != null) {
            final st = cell.decision.status;
            final rawDiff = (cell.a.rawLexeme ?? '') != (cell.b.rawLexeme ?? '');
            if (st == DecisionStatus.different ||
                st == DecisionStatus.unresolved ||
                (st == DecisionStatus.equivalent && rawDiff)) {
              hasModification = true;
              break;
            }
          }
        } else if (col.fieldA != null) {
          final lex = recA?.cells[col.fieldA]?.rawLexeme;
          if (lex != null && lex.isNotEmpty) {
            hasModification = true;
            break;
          }
        } else if (col.fieldB != null) {
          final lex = recB?.cells[col.fieldB]?.rawLexeme;
          if (lex != null && lex.isNotEmpty) {
            hasModification = true;
            break;
          }
        }
      }

      final kind = hasModification
          ? ExcelDiffRowKind.modified
          : ExcelDiffRowKind.unchanged;
      if (hasModification) {
        modifiedCount++;
      } else {
        unchangedCount++;
      }

      dataRows.add(
        _ExcelDiffAlignedRow(
          alignedIndex: dataRows.length + 1,
          kind: kind,
          rowNumberA: (recA?.ordinal ?? dataRows.length) + 2,
          rowNumberB: (recB?.ordinal ?? dataRows.length) + 2,
          recordA: recA,
          recordB: recB,
          cellsByFieldA: cellsMap,
        ),
      );
    }

    // Thêm các hàng bị xóa (chỉ có ở Sheet A) và các hàng được thêm (chỉ có ở Sheet B)
    final handledStructuralA = <String>{};
    final handledStructuralB = <String>{};

    for (final s in result.structural) {
      if (s.kind != 'ROW_ADDED' && s.kind != 'ROW_REMOVED') continue;
      if (s.side == SourceSide.a && !matchedRowIdsA.contains(s.recordId)) {
        handledStructuralA.add(s.recordId);
        final recA = recordsAById[s.recordId];
        deletedCount++;
        dataRows.add(
          _ExcelDiffAlignedRow(
            alignedIndex: dataRows.length + 1,
            kind: ExcelDiffRowKind.deleted,
            rowNumberA: (recA?.ordinal ?? dataRows.length) + 2,
            rowNumberB: null,
            recordA: recA,
            recordB: null,
          ),
        );
      } else if (s.side == SourceSide.b &&
          !matchedRowIdsB.contains(s.recordId)) {
        handledStructuralB.add(s.recordId);
        final recB = recordsBById[s.recordId];
        addedCount++;
        dataRows.add(
          _ExcelDiffAlignedRow(
            alignedIndex: dataRows.length + 1,
            kind: ExcelDiffRowKind.added,
            rowNumberA: null,
            rowNumberB: (recB?.ordinal ?? dataRows.length) + 2,
            recordA: null,
            recordB: recB,
          ),
        );
      }
    }

    for (final recA in result.plan.a.records) {
      if (!matchedRowIdsA.contains(recA.id) &&
          !handledStructuralA.contains(recA.id)) {
        deletedCount++;
        dataRows.add(
          _ExcelDiffAlignedRow(
            alignedIndex: dataRows.length + 1,
            kind: ExcelDiffRowKind.deleted,
            rowNumberA: recA.ordinal + 2,
            rowNumberB: null,
            recordA: recA,
          ),
        );
      }
    }

    for (final recB in result.plan.b.records) {
      if (!matchedRowIdsB.contains(recB.id) &&
          !handledStructuralB.contains(recB.id)) {
        addedCount++;
        dataRows.add(
          _ExcelDiffAlignedRow(
            alignedIndex: dataRows.length + 1,
            kind: ExcelDiffRowKind.added,
            rowNumberA: null,
            rowNumberB: recB.ordinal + 2,
            recordB: recB,
          ),
        );
      }
    }

    return _ExcelDiffPrecomputedTable(
      columns: List.unmodifiable(cols),
      headerRow: headerRow,
      allDataRows: List.unmodifiable(dataRows),
      addedCount: addedCount,
      deletedCount: deletedCount,
      unchangedCount: unchangedCount,
      modifiedCount: modifiedCount,
    );
  }
}

/// Bộ điều phối đồng bộ cuộn O(1) không tạo vòng lặp phản hồi (Zero-feedback Scroll Sync Group)
final class _SyncScrollControllerGroup {
  final List<ScrollController> _controllers = [];
  bool _syncing = false;
  double _lastOffset = 0.0;

  ScrollController create() {
    final controller = ScrollController(initialScrollOffset: _lastOffset);
    controller.addListener(() => _onScroll(controller));
    _controllers.add(controller);
    return controller;
  }

  void _onScroll(ScrollController source) {
    if (_syncing || !source.hasClients) return;
    _syncing = true;
    final offset = source.offset;
    _lastOffset = offset;
    for (final c in _controllers) {
      if (!identical(c, source) && c.hasClients) {
        final maxExtent = c.position.maxScrollExtent;
        final target = offset.clamp(0.0, maxExtent);
        if ((c.offset - target).abs() > 0.5) {
          c.jumpTo(target);
        }
      }
    }
    _syncing = false;
  }

  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    _controllers.clear();
  }
}

/// CustomPainter vẽ sọc chéo 45° cho hàng trống đối xứng (`add-line-shadow` & `delete-line-shadow` của ExcelCompare.org)
final class _DiagonalHatchPainter extends CustomPainter {
  final Color stripeColor;
  static const double _spacing = 8.0;

  const _DiagonalHatchPainter({required this.stripeColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final paint = Paint()
      ..color = stripeColor
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final maxDim = size.width + size.height;
    for (double x = -size.height; x < maxDim; x += _spacing) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height, size.height),
        paint,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _DiagonalHatchPainter oldDelegate) =>
      oldDelegate.stripeColor != stripeColor;
}

/// Giao diện Table Diff chuẩn ExcelCompare.org được tối ưu hiệu năng cho Dytava Mobile:
/// - Thanh công cụ Ribbon với 5 nút lọc kèm hộp đếm inline (`All`, `Added`, `Deleted`, `Unchanged`, `Modified`)
///   và các nút tiện ích (`Export`, `Fullscreen`, chuyển bố cục `A | B` / `A / B`).
/// - Hai bảng tính song song (Side-by-Side Dual Grid: Sheet A & Sheet B) với:
///   + Cột `#` cố định bên trái (Sticky Row Number) & hàng tiêu đề chữ cái `A, B, C...` cố định phía trên (Sticky Column Header).
///   + Kéo thay đổi độ rộng cột đồng bộ thời gian thực trên cả 2 bảng.
///   + Cuộn dọc và cuộn ngang đồng bộ mượt mà (Virtualized `ListView.builder` với `itemExtent` cố định, không dùng `IntrinsicHeight`).
///   + Tô màu ô sửa đổi (`#FCEDC5` nền vàng kem / `#D83431` chữ đỏ đậm), hàng thêm (`#DEEBD4` xanh lá nhạt),
///     hàng xóa (`#FFDDE1` hồng đỏ nhạt) và hàng giữ chỗ sọc chéo 45° (`add-line-shadow` / `delete-line-shadow`).
///   + Chạm chọn ô đồng bộ khung viền xanh lục bảo (`ring-emerald-500`) cùng highlight cột/hàng tương ứng ở cả 2 bảng.
class DytavaSheetDiffView extends StatefulWidget {
  final ComparisonResult result;
  final List<CellDifference> visibleCells;
  final void Function(String cellId) onSelectCell;
  final String? sourceALabel;
  final String? sourceBLabel;
  final SourceFormat? sourceAFormat;
  final SourceFormat? sourceBFormat;
  final VoidCallback? onExport;

  const DytavaSheetDiffView({
    super.key,
    required this.result,
    required this.visibleCells,
    required this.onSelectCell,
    this.sourceALabel,
    this.sourceBLabel,
    this.sourceAFormat,
    this.sourceBFormat,
    this.onExport,
  });

  @override
  State<DytavaSheetDiffView> createState() => _DytavaSheetDiffViewState();
}

class _DytavaSheetDiffViewState extends State<DytavaSheetDiffView> {
  // Màu sắc chuẩn giao diện Table Diff trên ExcelCompare.org kết hợp nhận diện Dytava
  static const Color _excelGreen = Color(0xFF217346);
  static const Color _excelActionBlue = DytavaColors.primary;
  static const Color _gridBorder = Color(0xFFC0C0C0);
  static const Color _headerBg = Color(0xFFF3F4F6);
  static const Color _activeHeaderBg = Color(0xFFD1D5DB);
  static const Color _activeEmerald = Color(0xFF10B981);
  static const Color _activeEmeraldDark = Color(0xFF047857);
  static const Color _modifiedBg = Color(0xFFFCEDC5);
  static const Color _modifiedFg = Color(0xFFD83431);
  static const Color _addedBg = Color(0xFFDEEBD4);
  static const Color _addedFg = Color(0xFF217346);
  static const Color _deletedBg = Color(0xFFFFDDE1);
  static const Color _deletedFg = Color(0xFFBE5014);

  static const double _rowHeight = 30.0;
  static const double _headerHeight = 30.0;
  static const double _indexColWidth = 44.0;
  static const double _defaultColWidth = 124.0;

  late _ExcelDiffPrecomputedTable _table;
  ExcelDiffRowFilter _rowFilter = ExcelDiffRowFilter.all;
  final Map<int, double> _colWidths = {};
  int? _selectedAlignedRowIndex;
  int? _selectedColIndex;
  bool _forceVerticalStackOnNarrow = false;

  late _SyncScrollControllerGroup _hScrollGroup;
  late _SyncScrollControllerGroup _vScrollGroup;
  late ScrollController _hHeaderA;
  late ScrollController _hBodyA;
  late ScrollController _hHeaderB;
  late ScrollController _hBodyB;
  late ScrollController _vNumA;
  late ScrollController _vBodyA;
  late ScrollController _vNumB;
  late ScrollController _vBodyB;

  @override
  void initState() {
    super.initState();
    _initScrollGroups();
    _rebuildTableAndSelection();
  }

  void _initScrollGroups() {
    _hScrollGroup = _SyncScrollControllerGroup();
    _vScrollGroup = _SyncScrollControllerGroup();
    _hHeaderA = _hScrollGroup.create();
    _hBodyA = _hScrollGroup.create();
    _hHeaderB = _hScrollGroup.create();
    _hBodyB = _hScrollGroup.create();
    _vNumA = _vScrollGroup.create();
    _vBodyA = _vScrollGroup.create();
    _vNumB = _vScrollGroup.create();
    _vBodyB = _vScrollGroup.create();
  }

  @override
  void didUpdateWidget(covariant DytavaSheetDiffView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.result, widget.result) ||
        oldWidget.visibleCells.length != widget.visibleCells.length) {
      _rebuildTableAndSelection();
    }
  }

  void _rebuildTableAndSelection() {
    _table = _ExcelDiffPrecomputedTable.build(widget.result);
    for (final col in _table.columns) {
      _colWidths.putIfAbsent(col.index, () => _defaultColWidth);
    }
    // Mặc định chọn ô khác biệt đầu tiên để làm nổi bật khung emerald-500 giống ExcelCompare.org
    for (final row in _table.allDataRows) {
      if (row.kind == ExcelDiffRowKind.modified) {
        for (final col in _table.columns) {
          final cell = col.fieldA != null ? row.cellsByFieldA[col.fieldA] : null;
          if (cell != null && cell.decision.status != DecisionStatus.exact) {
            _selectedAlignedRowIndex = row.alignedIndex;
            _selectedColIndex = col.index;
            return;
          }
        }
      } else if (row.kind == ExcelDiffRowKind.deleted ||
          row.kind == ExcelDiffRowKind.added) {
        _selectedAlignedRowIndex ??= row.alignedIndex;
        _selectedColIndex ??= 0;
      }
    }
  }

  @override
  void dispose() {
    _hScrollGroup.dispose();
    _vScrollGroup.dispose();
    super.dispose();
  }

  double _colWidth(int colIndex) => _colWidths[colIndex] ?? _defaultColWidth;

  double get _totalDataWidth => _table.columns.fold<double>(
    0.0,
    (sum, col) => sum + _colWidth(col.index),
  );

  List<_ExcelDiffAlignedRow> _filteredRows() {
    final visibleCellIds = widget.visibleCells.length < widget.result.cells.length
        ? widget.visibleCells.map((c) => c.id).toSet()
        : null;

    final rows = <_ExcelDiffAlignedRow>[];
    // Dòng 1: Dòng tên cột dữ liệu (Field Header Row) chuẩn ExcelCompare.org
    if (_rowFilter == ExcelDiffRowFilter.all && visibleCellIds == null) {
      rows.add(_table.headerRow);
    }

    for (final row in _table.allDataRows) {
      final matchesTab = switch (_rowFilter) {
        ExcelDiffRowFilter.all => true,
        ExcelDiffRowFilter.added => row.kind == ExcelDiffRowKind.added,
        ExcelDiffRowFilter.deleted => row.kind == ExcelDiffRowKind.deleted,
        ExcelDiffRowFilter.unchanged => row.kind == ExcelDiffRowKind.unchanged,
        ExcelDiffRowFilter.modified => row.kind == ExcelDiffRowKind.modified,
      };
      if (!matchesTab) continue;

      if (visibleCellIds != null &&
          _rowFilter == ExcelDiffRowFilter.all &&
          row.cellsByFieldA.isNotEmpty) {
        final hasVisibleCell = row.cellsByFieldA.values.any(
          (c) => visibleCellIds.contains(c.id),
        );
        if (!hasVisibleCell) continue;
      }
      rows.add(row);
    }
    return rows;
  }

  CellDifference? _selectedCellDifference() {
    final rowIdx = _selectedAlignedRowIndex;
    final colIdx = _selectedColIndex;
    if (rowIdx == null || colIdx == null || colIdx >= _table.columns.length) {
      return null;
    }
    final col = _table.columns[colIdx];
    if (col.fieldA == null) return null;
    for (final row in _table.allDataRows) {
      if (row.alignedIndex == rowIdx) {
        return row.cellsByFieldA[col.fieldA];
      }
    }
    return null;
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
    DecisionStatus.different => (_modifiedFg, _modifiedBg),
    DecisionStatus.unresolved => (
      DytavaColors.unresolved,
      _modifiedBg,
    ),
  };

  void _openFullscreenModal(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (modalContext) => Scaffold(
          backgroundColor: DytavaColors.white,
          appBar: AppBar(
            backgroundColor: DytavaColors.white,
            elevation: 0,
            title: Text(
              'Table Diff · ${widget.sourceALabel ?? 'Sheet A'} ↔ ${widget.sourceBLabel ?? 'Sheet B'}',
              style: DytavaTypography.titleMedium,
            ),
            actions: [
              TextButton.icon(
                onPressed: () => Navigator.of(modalContext).pop(),
                icon: const BrandIcon(DytavaIcons.close, size: 16),
                label: const Text('Thu nhỏ'),
              ),
            ],
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: DytavaSheetDiffView(
                result: widget.result,
                visibleCells: widget.visibleCells,
                onSelectCell: (cellId) {
                  Navigator.of(modalContext).pop();
                  widget.onSelectCell(cellId);
                },
                sourceALabel: widget.sourceALabel,
                sourceBLabel: widget.sourceBLabel,
                sourceAFormat: widget.sourceAFormat,
                sourceBFormat: widget.sourceBFormat,
                onExport: widget.onExport,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rows = _filteredRows();
    final fileALabel =
        widget.sourceALabel ?? 'left_sheet_a.csv (${widget.result.plan.a.records.length} hàng)';
    final fileBLabel =
        widget.sourceBLabel ?? 'right_sheet_b.csv (${widget.result.plan.b.records.length} hàng)';
    final formatA = widget.sourceAFormat ?? SourceFormat.csv;
    final formatB = widget.sourceBFormat ?? SourceFormat.csv;
    final selectedCell = _selectedCellDifference();

    return Container(
      decoration: BoxDecoration(
        color: DytavaColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: DytavaColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            offset: Offset(0, 4),
            blurRadius: 14,
          ),
        ],
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Thanh công cụ Diff Ribbon chuẩn ExcelCompare.org (Bộ lọc + Hộp số lượng + Export / Fullscreen)
          _buildExcelCompareToolbar(context),
          const SizedBox(height: 10),

          // 2. Khung 2 bảng tính đối xứng (Side-by-Side Dual Spreadsheet Grids)
          if (rows.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
              decoration: BoxDecoration(
                color: DytavaColors.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _gridBorder),
              ),
              child: Column(
                children: [
                  BrandIllustration.emptyFilter(size: 56),
                  const SizedBox(height: 8),
                  const Text(
                    'Không có hàng nào trong nhóm lọc này',
                    style: DytavaTypography.titleMedium,
                  ),
                ],
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final isVeryNarrow = constraints.maxWidth < 340;
                final useStacked =
                    _forceVerticalStackOnNarrow || isVeryNarrow;
                final viewportHeight = (rows.length * _rowHeight)
                    .clamp(120.0, 330.0);

                final panelA = _buildSpreadsheetPanel(
                  isLeftPanel: true,
                  fileTitle: fileALabel,
                  format: formatA,
                  rows: rows,
                  viewportHeight: viewportHeight,
                  hHeaderController: _hHeaderA,
                  hBodyController: _hBodyA,
                  vNumController: _vNumA,
                  vBodyController: _vBodyA,
                );

                final panelB = _buildSpreadsheetPanel(
                  isLeftPanel: false,
                  fileTitle: fileBLabel,
                  format: formatB,
                  rows: rows,
                  viewportHeight: viewportHeight,
                  hHeaderController: _hHeaderB,
                  hBodyController: _hBodyB,
                  vNumController: _vNumB,
                  vBodyController: _vBodyB,
                );

                if (useStacked) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      panelA,
                      const SizedBox(height: 8),
                      panelB,
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: panelA),
                    const SizedBox(width: 8),
                    Expanded(child: panelB),
                  ],
                );
              },
            ),

          // 3. Thanh kiểm tra nhanh ô đang chọn (Active Cell Inspector) & Quick-Jump Chips
          if (selectedCell != null) ...[
            const SizedBox(height: 10),
            _buildSelectedCellInspector(context, selectedCell),
          ],
          if (widget.visibleCells.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildQuickJumpCellStrip(context),
          ],
        ],
      ),
    );
  }

  /// Thanh công cụ Diff Ribbon chuẩn ExcelCompare.org:
  /// - Trái: 5 nút lọc hàng `All`, `Added`, `Deleted`, `Unchanged`, `Modified` kèm hộp số đếm có màu nền đặc trưng
  /// - Phải: Các nút tiện ích `A|B`, `Export`, `Fullscreen`
  Widget _buildExcelCompareToolbar(BuildContext context) {
    final filterItems = <(
      ExcelDiffRowFilter,
      String,
      int,
      Color,
      Color,
    )>[
      (
        ExcelDiffRowFilter.all,
        'All',
        _table.totalCount,
        const Color(0xFFF8F8F8),
        const Color(0xFF1F2937),
      ),
      (
        ExcelDiffRowFilter.added,
        'Added',
        _table.addedCount,
        _addedBg,
        const Color(0xFF14532D),
      ),
      (
        ExcelDiffRowFilter.deleted,
        'Deleted',
        _table.deletedCount,
        _deletedBg,
        const Color(0xFF7F1D1D),
      ),
      (
        ExcelDiffRowFilter.unchanged,
        'Unchanged',
        _table.unchangedCount,
        const Color(0xFFF8F8F8),
        const Color(0xFF1F2937),
      ),
      (
        ExcelDiffRowFilter.modified,
        'Modified',
        _table.modifiedCount,
        _modifiedBg,
        const Color(0xFF78350F),
      ),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: DytavaColors.white,
        border: Border(
          bottom: BorderSide(color: DytavaColors.border.withValues(alpha: 0.9)),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final (filter, label, count, badgeBg, badgeFg) in filterItems)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: _buildRibbonFilterButton(
                  filter: filter,
                  label: label,
                  count: count,
                  badgeBg: badgeBg,
                  badgeFg: badgeFg,
                ),
              ),
            const SizedBox(width: 6),
            _buildRibbonActionButton(
              label: _forceVerticalStackOnNarrow ? 'Song song A|B' : 'Xếp dọc A/B',
              iconAsset: DytavaIcons.columns,
              onTap: () => setState(
                () => _forceVerticalStackOnNarrow = !_forceVerticalStackOnNarrow,
              ),
            ),
            if (widget.onExport != null) ...[
              const SizedBox(width: 6),
              _buildRibbonActionButton(
                label: 'Export',
                iconAsset: DytavaIcons.export,
                onTap: widget.onExport!,
              ),
            ],
            const SizedBox(width: 6),
            _buildRibbonActionButton(
              label: 'Fullscreen',
              iconAsset: DytavaIcons.openExternal,
              onTap: () => _openFullscreenModal(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRibbonFilterButton({
    required ExcelDiffRowFilter filter,
    required String label,
    required int count,
    required Color badgeBg,
    required Color badgeFg,
  }) {
    final isSelected = _rowFilter == filter;
    return Semantics(
      button: true,
      selected: isSelected,
      label: 'Lọc hàng $label: $count hàng',
      child: InkWell(
        onTap: () => setState(() => _rowFilter = filter),
        child: Container(
          constraints: const BoxConstraints(minHeight: 34),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: isSelected ? _excelGreen : _headerBg,
            border: Border.all(
              color: isSelected ? _excelGreen : _gridBorder,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? DytavaColors.white
                      : const Color(0xFF4B5563),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                constraints: const BoxConstraints(minWidth: 22),
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeBg,
                  border: Border.all(color: _gridBorder, width: 1),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontFamily: DytavaTypography.dataFont,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: badgeFg,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRibbonActionButton({
    required String label,
    required String iconAsset,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 34),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _excelActionBlue,
            border: Border.all(color: _excelActionBlue),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              BrandIcon(iconAsset, size: 14),
              const SizedBox(width: 5),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: DytavaColors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Xây dựng từng bảng tính (Trái = Sheet A, Phải = Sheet B) giống hệt ExcelCompare.org
  Widget _buildSpreadsheetPanel({
    required bool isLeftPanel,
    required String fileTitle,
    required SourceFormat format,
    required List<_ExcelDiffAlignedRow> rows,
    required double viewportHeight,
    required ScrollController hHeaderController,
    required ScrollController hBodyController,
    required ScrollController vNumController,
    required ScrollController vBodyController,
  }) {
    final totalWidth = _totalDataWidth;
    final recordCount = isLeftPanel
        ? widget.result.plan.a.records.length
        : widget.result.plan.b.records.length;

    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          color: DytavaColors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _gridBorder, width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Panel File Header Bar (bg-gray-100 border-b border-[#c0c0c0] p-2.5)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: const BoxDecoration(
                color: _headerBg,
                border: Border(
                  bottom: BorderSide(color: _gridBorder, width: 1),
                ),
              ),
              child: Row(
                children: [
                  BrandIcon.format(format, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${isLeftPanel ? 'Sheet A' : 'Sheet B'} · $fileTitle',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF374151),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${recordCount}R×${_table.columns.length}C',
                    style: const TextStyle(
                      fontFamily: DytavaTypography.dataFont,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: DytavaColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            // Sticky Column Header Row (# | A | B | C ...)
            SizedBox(
              height: _headerHeight,
              child: Row(
                children: [
                  // Ô góc cố định '#'
                  Container(
                    width: _indexColWidth,
                    height: _headerHeight,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: _headerBg,
                      border: Border(
                        right: BorderSide(color: _gridBorder, width: 1),
                        bottom: BorderSide(color: _gridBorder, width: 1),
                      ),
                    ),
                    child: const Text(
                      '#',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF374151),
                      ),
                    ),
                  ),
                  // Dải chữ cái cột A, B, C... cuộn ngang đồng bộ
                  Expanded(
                    child: SingleChildScrollView(
                      controller: hHeaderController,
                      scrollDirection: Axis.horizontal,
                      physics: const ClampingScrollPhysics(),
                      child: Row(
                        children: [
                          for (final col in _table.columns)
                            _buildColumnLetterHeaderCell(col),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Virtualized Grid Body: Cột số thứ tự '#' cố định bên trái + Lưới ô dữ liệu ảo hóa
            SizedBox(
              height: viewportHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Sticky '#' Row Number Column (Virtualized ListView.builder)
                  SizedBox(
                    width: _indexColWidth,
                    child: ListView.builder(
                      controller: vNumController,
                      itemExtent: _rowHeight,
                      itemCount: rows.length,
                      physics: const ClampingScrollPhysics(),
                      padding: EdgeInsets.zero,
                      itemBuilder: (context, idx) => _buildRowNumberCell(
                        row: rows[idx],
                        isLeftPanel: isLeftPanel,
                      ),
                    ),
                  ),
                  // Data Cells Canvas (Single horizontal scroll controller + Virtualized vertical ListView.builder)
                  Expanded(
                    child: RawScrollbar(
                      controller: hBodyController,
                      thumbVisibility: true,
                      thickness: 6,
                      radius: const Radius.circular(999),
                      thumbColor: const Color(0xFF9CA3AF),
                      notificationPredicate: (n) => n.depth == 0,
                      child: SingleChildScrollView(
                        controller: hBodyController,
                        scrollDirection: Axis.horizontal,
                        physics: const ClampingScrollPhysics(),
                        child: SizedBox(
                          width: totalWidth,
                          height: viewportHeight,
                          child: RawScrollbar(
                            controller: vBodyController,
                            thumbVisibility: true,
                            thickness: 6,
                            radius: const Radius.circular(999),
                            thumbColor: const Color(0xFF9CA3AF),
                            child: ListView.builder(
                              controller: vBodyController,
                              itemExtent: _rowHeight,
                              itemCount: rows.length,
                              physics: const ClampingScrollPhysics(),
                              padding: EdgeInsets.zero,
                              itemBuilder: (context, idx) => _buildDataRowCells(
                                context: context,
                                row: rows[idx],
                                isLeftPanel: isLeftPanel,
                              ),
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
      ),
    );
  }

  /// Ô tiêu đề cột (`A`, `B`, `C`...) kèm thanh kéo thay đổi độ rộng cột đồng bộ
  Widget _buildColumnLetterHeaderCell(_ExcelDiffColumn col) {
    final isColSelected = _selectedColIndex == col.index;
    final width = _colWidth(col.index);

    return GestureDetector(
      onTap: () => setState(() => _selectedColIndex = col.index),
      child: Container(
        width: width,
        height: _headerHeight,
        decoration: BoxDecoration(
          color: isColSelected ? _activeHeaderBg : _headerBg,
          border: Border(
            right: const BorderSide(color: _gridBorder, width: 1),
            bottom: BorderSide(
              color: isColSelected ? _activeEmerald : _gridBorder,
              width: isColSelected ? 2.0 : 1.0,
            ),
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  col.letter,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isColSelected ? FontWeight.w800 : FontWeight.w700,
                    color: isColSelected
                        ? _activeEmeraldDark
                        : const Color(0xFF374151),
                  ),
                ),
              ),
            ),
            // Resize handle ở cạnh phải của cột (kéo để thay đổi độ rộng đồng bộ cả 2 bảng)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: 10,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragUpdate: (details) {
                  setState(() {
                    final next = (_colWidth(col.index) + details.delta.dx)
                        .clamp(72.0, 260.0);
                    _colWidths[col.index] = next;
                  });
                },
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    width: 2,
                    height: 16,
                    color: _gridBorder,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Ô số thứ tự hàng (`#`) cố định bên trái với đúng quy tắc màu nền & sọc chéo của ExcelCompare.org
  Widget _buildRowNumberCell({
    required _ExcelDiffAlignedRow row,
    required bool isLeftPanel,
  }) {
    final isRowSelected =
        row.kind != ExcelDiffRowKind.header &&
        _selectedAlignedRowIndex == row.alignedIndex;
    final isAddedPlaceholder =
        row.kind == ExcelDiffRowKind.added && isLeftPanel;
    final isDeletedPlaceholder =
        row.kind == ExcelDiffRowKind.deleted && !isLeftPanel;

    if (isAddedPlaceholder || isDeletedPlaceholder) {
      return CustomPaint(
        painter: _DiagonalHatchPainter(
          stripeColor: isAddedPlaceholder
              ? const Color(0xFF86EFAC)
              : const Color(0xFFFCA5A5),
        ),
        child: Container(
          height: _rowHeight,
          decoration: BoxDecoration(
            border: Border(
              right: BorderSide(
                color: isRowSelected ? _activeEmerald : _gridBorder,
                width: isRowSelected ? 2.0 : 1.0,
              ),
              bottom: const BorderSide(color: _gridBorder, width: 1),
            ),
          ),
        ),
      );
    }

    Color bgColor = _headerBg;
    Color textColor = const Color(0xFF6B7280);
    if (isRowSelected) {
      bgColor = _activeHeaderBg;
      textColor = _activeEmeraldDark;
    } else if (row.kind == ExcelDiffRowKind.added && !isLeftPanel) {
      bgColor = _addedBg;
      textColor = _addedFg;
    } else if (row.kind == ExcelDiffRowKind.deleted && isLeftPanel) {
      bgColor = _deletedBg;
      textColor = _deletedFg;
    }

    final rowNum = isLeftPanel ? row.rowNumberA : row.rowNumberB;

    return Container(
      height: _rowHeight,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          right: BorderSide(
            color: isRowSelected ? _activeEmerald : _gridBorder,
            width: isRowSelected ? 2.0 : 1.0,
          ),
          bottom: const BorderSide(color: _gridBorder, width: 1),
        ),
      ),
      child: Text(
        rowNum != null ? '$rowNum' : '',
        style: TextStyle(
          fontFamily: DytavaTypography.dataFont,
          fontSize: 11,
          fontWeight: isRowSelected ? FontWeight.w800 : FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  /// Xây dựng các ô dữ liệu của một hàng trong bảng tính
  Widget _buildDataRowCells({
    required BuildContext context,
    required _ExcelDiffAlignedRow row,
    required bool isLeftPanel,
  }) {
    final isAddedPlaceholder =
        row.kind == ExcelDiffRowKind.added && isLeftPanel;
    final isDeletedPlaceholder =
        row.kind == ExcelDiffRowKind.deleted && !isLeftPanel;

    if (isAddedPlaceholder || isDeletedPlaceholder) {
      return CustomPaint(
        painter: _DiagonalHatchPainter(
          stripeColor: isAddedPlaceholder
              ? const Color(0xFF86EFAC)
              : const Color(0xFFFCA5A5),
        ),
        child: SizedBox(
          height: _rowHeight,
          child: Row(
            children: [
              for (final col in _table.columns)
                _buildPlaceholderDataCell(row: row, col: col),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: _rowHeight,
      child: Row(
        children: [
          for (final col in _table.columns)
            _buildPopulatedDataCell(
              context: context,
              row: row,
              col: col,
              isLeftPanel: isLeftPanel,
            ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderDataCell({
    required _ExcelDiffAlignedRow row,
    required _ExcelDiffColumn col,
  }) {
    final isSelected =
        _selectedAlignedRowIndex == row.alignedIndex &&
        _selectedColIndex == col.index;
    return GestureDetector(
      onTap: () => setState(() {
        _selectedAlignedRowIndex = row.alignedIndex;
        _selectedColIndex = col.index;
      }),
      child: Container(
        width: _colWidth(col.index),
        height: _rowHeight,
        decoration: BoxDecoration(
          border: isSelected
              ? Border.all(color: _activeEmerald, width: 2.0)
              : const Border(
                  right: BorderSide(color: _gridBorder, width: 1),
                  bottom: BorderSide(color: _gridBorder, width: 1),
                ),
        ),
      ),
    );
  }

  Widget _buildPopulatedDataCell({
    required BuildContext context,
    required _ExcelDiffAlignedRow row,
    required _ExcelDiffColumn col,
    required bool isLeftPanel,
  }) {
    final width = _colWidth(col.index);

    // Hàng 1 trong lưới: hiển thị tên cột (Field Header Row) giống ExcelCompare.org
    if (row.kind == ExcelDiffRowKind.header) {
      final headerLabel = isLeftPanel
          ? (col.fieldA != null ? '${col.fieldA} (${col.labelA})' : '(trống)')
          : (col.fieldB != null ? '${col.fieldB} (${col.labelB})' : '(trống)');
      final isMissingField =
          (isLeftPanel && col.fieldA == null) ||
          (!isLeftPanel && col.fieldB == null);

      return Container(
        width: width,
        height: _rowHeight,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        alignment: Alignment.centerLeft,
        decoration: const BoxDecoration(
          color: DytavaColors.white,
          border: Border(
            right: BorderSide(color: _gridBorder, width: 1),
            bottom: BorderSide(color: _gridBorder, width: 1),
          ),
        ),
        child: Text(
          headerLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            fontStyle: isMissingField ? FontStyle.italic : FontStyle.normal,
            color: isMissingField
                ? const Color(0xFF9CA3AF)
                : const Color(0xFF111827),
          ),
        ),
      );
    }

    final isSelected =
        _selectedAlignedRowIndex == row.alignedIndex &&
        _selectedColIndex == col.index;
    final cellDiff = col.fieldA != null ? row.cellsByFieldA[col.fieldA] : null;
    final record = isLeftPanel ? row.recordA : row.recordB;
    final fieldId = isLeftPanel ? col.fieldA : col.fieldB;
    final sourceCell = fieldId != null ? record?.cells[fieldId] : null;

    final isMissingColOnThisSide = fieldId == null;
    final rawText = isMissingColOnThisSide
        ? '(trống)'
        : (sourceCell?.rawLexeme ??
              (cellDiff != null
                  ? (isLeftPanel
                        ? (cellDiff.a.rawLexeme ?? '[${cellDiff.a.kind.name}]')
                        : (cellDiff.b.rawLexeme ?? '[${cellDiff.b.kind.name}]'))
                  : ''));

    // Xác định màu nền và màu chữ chuẩn ExcelCompare.org:
    // - Hàng Added (bên phải): nền #DEEBD4
    // - Hàng Deleted (bên trái): nền #FFDDE1
    // - Ô Modified (DIFFERENT / UNRESOLVED / EQUIVALENT có khác biểu diễn): nền #FCEDC5, chữ đỏ đậm #D83431
    // - Ô Unchanged: nền trắng #FFFFFF, chữ #111827
    Color cellBg = DytavaColors.white;
    Color textColor = const Color(0xFF111827);
    FontWeight fontWeight = FontWeight.w400;
    FontStyle fontStyle = isMissingColOnThisSide
        ? FontStyle.italic
        : FontStyle.normal;

    if (row.kind == ExcelDiffRowKind.added && !isLeftPanel) {
      cellBg = _addedBg;
      if (isMissingColOnThisSide) textColor = const Color(0xFF9CA3AF);
    } else if (row.kind == ExcelDiffRowKind.deleted && isLeftPanel) {
      cellBg = _deletedBg;
      if (isMissingColOnThisSide) textColor = const Color(0xFF9CA3AF);
    } else if (cellDiff != null) {
      final status = cellDiff.decision.status;
      final hasRawDiff =
          (cellDiff.a.rawLexeme ?? '') != (cellDiff.b.rawLexeme ?? '');
      if (status == DecisionStatus.different ||
          status == DecisionStatus.unresolved ||
          (status == DecisionStatus.equivalent && hasRawDiff)) {
        cellBg = _modifiedBg;
        textColor = _modifiedFg;
        fontWeight = FontWeight.w600;
      }
    } else if (isMissingColOnThisSide) {
      final oppositeRecord = isLeftPanel ? row.recordB : row.recordA;
      final oppositeField = isLeftPanel ? col.fieldB : col.fieldA;
      final oppositeVal = oppositeField != null
          ? oppositeRecord?.cells[oppositeField]?.rawLexeme
          : null;
      if (oppositeVal != null && oppositeVal.isNotEmpty) {
        cellBg = _modifiedBg;
        textColor = _modifiedFg;
        fontWeight = FontWeight.w600;
      } else {
        textColor = const Color(0xFF9CA3AF);
      }
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedAlignedRowIndex = row.alignedIndex;
          _selectedColIndex = col.index;
        });
      },
      onDoubleTap: cellDiff != null
          ? () => widget.onSelectCell(cellDiff.id)
          : null,
      child: Tooltip(
        message: rawText,
        waitDuration: const Duration(milliseconds: 450),
        child: Container(
          width: width,
          height: _rowHeight,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: cellBg,
            border: isSelected
                ? Border.all(color: _activeEmerald, width: 2.0)
                : const Border(
                    right: BorderSide(color: _gridBorder, width: 1),
                    bottom: BorderSide(color: _gridBorder, width: 1),
                  ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  rawText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: DytavaTypography.dataFont,
                    fontSize: 12,
                    fontWeight: fontWeight,
                    fontStyle: fontStyle,
                    color: textColor,
                  ),
                ),
              ),
              if (cellDiff?.decision.status == DecisionStatus.equivalent)
                Container(
                  margin: const EdgeInsets.only(left: 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: DytavaColors.equivalentBg,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: DytavaColors.equivalent.withValues(alpha: 0.4),
                    ),
                  ),
                  child: const Text(
                    '≈',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: DytavaColors.equivalent,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Thanh Formula / Cell Diff Inspector hiển thị chi tiết ngữ nghĩa Dytava của cặp ô đang chọn trên bảng
  Widget _buildSelectedCellInspector(
    BuildContext context,
    CellDifference cell,
  ) {
    final (fg, bg) = _statusColors(cell.decision.status);
    final rawA = cell.a.rawLexeme ?? '[${cell.a.kind.name}]';
    final rawB = cell.b.rawLexeme ?? '[${cell.b.kind.name}]';
    final colLetter = _selectedColIndex != null &&
            _selectedColIndex! < _table.columns.length
        ? _table.columns[_selectedColIndex!].letter
        : 'A';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bg.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: fg.withValues(alpha: 0.45)),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 6,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _activeEmerald,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '$colLetter${(_selectedAlignedRowIndex ?? 1) + 1}',
                  style: const TextStyle(
                    fontFamily: DytavaTypography.dataFont,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: DytavaColors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'A: $rawA  →  B: $rawB',
                  style: DytavaTypography.dataSmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: DytavaColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              InkWell(
                onTap: () => showDytavaCellDetailBottomSheet(
                  context: context,
                  cell: cell,
                  onOpenFullDetail: () => widget.onSelectCell(cell.id),
                ),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: DytavaColors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: DytavaColors.border),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      BrandIcon(DytavaIcons.preview, size: 14),
                      SizedBox(width: 4),
                      Text(
                        'Sheet',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: DytavaColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              InkWell(
                onTap: () => widget.onSelectCell(cell.id),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: DytavaColors.primary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      BrandIcon(DytavaIcons.openExternal, size: 14),
                      SizedBox(width: 4),
                      Text(
                        'Chi tiết ô',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: DytavaColors.white,
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
    );
  }

  /// Dải chip truy cập nhanh từng cặp ô theo trạng thái ngữ nghĩa Dytava
  Widget _buildQuickJumpCellStrip(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final cell in widget.visibleCells)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Builder(
                builder: (context) {
                  final statusText = _statusName(cell.decision.status);
                  final (fg, bg) = _statusColors(cell.decision.status);
                  return InkWell(
                    onTap: () => widget.onSelectCell(cell.id),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: fg.withValues(alpha: 0.45),
                        ),
                      ),
                      child: Text(
                        '${cell.mapping.fieldA}: $statusText',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: fg,
                        ),
                      ),
                    ),
                  );
                },
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
