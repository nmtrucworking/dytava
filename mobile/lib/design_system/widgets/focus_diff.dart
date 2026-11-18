import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../dytava_colors.dart';
import '../dytava_typography.dart';

/// Thành phần nhận diện cốt lõi: **Focus Diff**
///
/// Trải nghiệm xem sai lệch trên màn hình nhỏ: Hiển thị tập trung từng cặp giá trị
/// Cũ (Nguồn A) và Mới (Nguồn B) với typography Tabular figures và SourceRef chính xác.
/// Hỗ trợ thao tác vuốt/chuyển bản ghi kèm phản hồi xúc giác nhẹ (Haptics).
class FocusDiffCard extends StatelessWidget {
  final String fieldName;
  final String rowIdentifier;
  final String statusText;
  final Color statusColor;
  final String rawA;
  final String rawB;
  final String? sourceRefA;
  final String? sourceRefB;
  final String? ruleReason;
  final int currentIndex;
  final int totalDiffs;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final ValueChanged<String>? onCopy;

  const FocusDiffCard({
    super.key,
    required this.fieldName,
    required this.rowIdentifier,
    required this.statusText,
    required this.statusColor,
    required this.rawA,
    required this.rawB,
    this.sourceRefA,
    this.sourceRefB,
    this.ruleReason,
    this.currentIndex = 1,
    this.totalDiffs = 1,
    this.onPrevious,
    this.onNext,
    this.onCopy,
  });

  void _triggerHaptic() {
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: DytavaColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: DytavaColors.border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: DytavaColors.graphite.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: Field name, Row key, and Index counter
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fieldName,
                      style: DytavaTypography.titleMedium.copyWith(
                        color: DytavaColors.graphite,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      rowIdentifier,
                      style: DytavaTypography.precisionTag.copyWith(
                        fontSize: 10,
                        color: DytavaColors.precisionNeutral,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.3),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  statusText,
                  style: DytavaTypography.labelSmall.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Side-by-side or Stacked Values: Old (A) vs New (B)
          _buildValueBlock(
            label: 'NGUỒN A (THAM CHIẾU / CŨ)',
            value: rawA,
            sourceRef: sourceRefA,
            isHighlight: false,
          ),
          const SizedBox(height: 10),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: DytavaColors.warmCanvas,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.arrow_downward_rounded,
                    size: 13,
                    color: DytavaColors.precisionNeutral,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'So sánh giá trị',
                    style: DytavaTypography.bodySmall.copyWith(
                      fontSize: 10,
                      color: DytavaColors.precisionNeutral,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          _buildValueBlock(
            label: 'NGUỒN B (ĐỐI CHIẾU / MỚI)',
            value: rawB,
            sourceRef: sourceRefB,
            isHighlight: true,
          ),

          if (ruleReason != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: DytavaColors.warmCanvas,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: DytavaColors.border, width: 0.8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 15,
                    color: DytavaColors.precisionNeutral,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      ruleReason!,
                      style: DytavaTypography.bodySmall.copyWith(
                        fontSize: 11,
                        color: DytavaColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Navigation footer: Prev, Counter, Next
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              IconButton.outlined(
                onPressed: onPrevious != null
                    ? () {
                        _triggerHaptic();
                        onPrevious!();
                      }
                    : null,
                icon: const Icon(Icons.chevron_left_rounded, size: 20),
                tooltip: 'Sai khác trước',
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  side: const BorderSide(color: DytavaColors.border),
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(36, 36),
                ),
              ),
              Text(
                'Sai khác $currentIndex / $totalDiffs',
                style: DytavaTypography.dataSmall.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: DytavaColors.graphite,
                ),
              ),
              IconButton.outlined(
                onPressed: onNext != null
                    ? () {
                        _triggerHaptic();
                        onNext!();
                      }
                    : null,
                icon: const Icon(Icons.chevron_right_rounded, size: 20),
                tooltip: 'Sai khác tiếp theo',
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  side: const BorderSide(color: DytavaColors.border),
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(36, 36),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildValueBlock({
    required String label,
    required String value,
    String? sourceRef,
    required bool isHighlight,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isHighlight
            ? DytavaColors.differenceCoral.withValues(alpha: 0.06)
            : DytavaColors.warmCanvas,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isHighlight
              ? DytavaColors.differenceCoral.withValues(alpha: 0.3)
              : DytavaColors.border,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: DytavaTypography.precisionTag.copyWith(
                    fontSize: 9.5,
                    color: isHighlight
                        ? DytavaColors.differenceCoral
                        : DytavaColors.precisionNeutral,
                  ),
                ),
              ),
              if (sourceRef != null)
                Text(
                  sourceRef,
                  style: DytavaTypography.dataSmall.copyWith(
                    fontSize: 10,
                    color: DytavaColors.precisionNeutral,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          SelectableText(
            value.isEmpty ? '(trống)' : value,
            style: DytavaTypography.dataMedium.copyWith(
              color: isHighlight
                  ? DytavaColors.differenceCoral
                  : DytavaColors.graphite,
              fontWeight: isHighlight ? FontWeight.w700 : FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
