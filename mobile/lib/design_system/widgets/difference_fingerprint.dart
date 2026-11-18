import 'package:flutter/material.dart';

import '../dytava_colors.dart';
import '../dytava_typography.dart';

/// Một phân đoạn trên dải Difference Fingerprint
class FingerprintSegment {
  final double weight; // Độ dài tương đối của phân đoạn (0..1 hoặc số dòng)
  final int count; // Số lượng bản ghi trong phân đoạn
  final FingerprintVerdict verdict; // Loại kết luận
  final String label;

  const FingerprintSegment({
    required this.weight,
    required this.count,
    required this.verdict,
    this.label = '',
  });
}

enum FingerprintVerdict {
  matched, // Trùng khớp hoàn toàn hoặc tương đương
  difference, // Có sai khác giá trị
  review, // Chưa kết luận / cần xem xét
}

/// Thành phần nhận diện cốt lõi: **Difference Fingerprint**
///
/// Dải trực quan biểu diễn vị trí và mật độ sai khác trên toàn bảng đối chiếu.
/// Người dùng có thể chạm vào từng vùng để lọc/mở các bản ghi liên quan.
class DifferenceFingerprint extends StatelessWidget {
  final List<FingerprintSegment> segments;
  final int totalRecords;
  final int diffCount;
  final int matchCount;
  final int reviewCount;
  final ValueChanged<int>? onSegmentTap;
  final int? selectedSegmentIndex;

  const DifferenceFingerprint({
    super.key,
    required this.segments,
    required this.totalRecords,
    required this.diffCount,
    required this.matchCount,
    this.reviewCount = 0,
    this.onSegmentTap,
    this.selectedSegmentIndex,
  });

  /// Factory tiện ích tạo Fingerprint mẫu từ số liệu tổng kết
  factory DifferenceFingerprint.fromCounts({
    Key? key,
    required int exactCount,
    required int equivalentCount,
    required int differentCount,
    required int unresolvedCount,
    ValueChanged<int>? onSegmentTap,
    int? selectedSegmentIndex,
  }) {
    final matched = exactCount + equivalentCount;
    final total = matched + differentCount + unresolvedCount;
    final safeTotal = total > 0 ? total : 1;

    final segs = <FingerprintSegment>[];
    if (matched > 0) {
      segs.add(
        FingerprintSegment(
          weight: matched / safeTotal,
          count: matched,
          verdict: FingerprintVerdict.matched,
          label: 'Trùng khớp',
        ),
      );
    }
    if (differentCount > 0) {
      segs.add(
        FingerprintSegment(
          weight: differentCount / safeTotal,
          count: differentCount,
          verdict: FingerprintVerdict.difference,
          label: 'Sai khác',
        ),
      );
    }
    if (unresolvedCount > 0) {
      segs.add(
        FingerprintSegment(
          weight: unresolvedCount / safeTotal,
          count: unresolvedCount,
          verdict: FingerprintVerdict.review,
          label: 'Cần xem xét',
        ),
      );
    }

    return DifferenceFingerprint(
      key: key,
      segments: segs,
      totalRecords: total,
      diffCount: differentCount,
      matchCount: matched,
      reviewCount: unresolvedCount,
      onSegmentTap: onSegmentTap,
      selectedSegmentIndex: selectedSegmentIndex,
    );
  }

  Color _verdictColor(FingerprintVerdict verdict) {
    switch (verdict) {
      case FingerprintVerdict.difference:
        return DytavaColors.differenceCoral;
      case FingerprintVerdict.review:
        return DytavaColors.amber;
      case FingerprintVerdict.matched:
        return const Color(0xFF94A3B8); // Slate trung tính
    }
  }

  @override
  Widget build(BuildContext context) {
    final diffPercentage = totalRecords > 0
        ? (diffCount / totalRecords * 100).toStringAsFixed(1)
        : '0.0';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DytavaColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: DytavaColors.border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: DytavaColors.graphite.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: Title & Density metric
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(
                'BẢN ĐỒ SAI KHÁC (FINGERPRINT)',
                style: DytavaTypography.precisionTag.copyWith(
                  letterSpacing: 1.1,
                  fontSize: 10.5,
                ),
              ),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '$diffPercentage% ',
                      style: DytavaTypography.metricNumber.copyWith(
                        fontSize: 13,
                        color: diffCount > 0
                            ? DytavaColors.differenceCoral
                            : DytavaColors.exact,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    TextSpan(
                      text: 'mật độ sai lệch',
                      style: DytavaTypography.bodySmall.copyWith(
                        fontSize: 11,
                        color: DytavaColors.precisionNeutral,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // The Fingerprint density strip
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 24,
              decoration: BoxDecoration(
                color: DytavaColors.warmCanvas,
                border: Border.all(color: DytavaColors.border, width: 0.8),
                borderRadius: BorderRadius.circular(8),
              ),
              child: segments.isEmpty
                  ? Center(
                      child: Text(
                        'Chưa có dữ liệu đối chiếu',
                        style: DytavaTypography.bodySmall.copyWith(
                          fontSize: 10,
                          color: DytavaColors.precisionNeutral,
                        ),
                      ),
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (int i = 0; i < segments.length; i++)
                          _buildSegmentBar(i, segments[i]),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 12),

          // Legend
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildLegendItem(
                label: 'Trùng khớp',
                count: matchCount,
                color: const Color(0xFF94A3B8),
              ),
              _buildLegendItem(
                label: 'Sai khác',
                count: diffCount,
                color: DytavaColors.differenceCoral,
              ),
              if (reviewCount > 0)
                _buildLegendItem(
                  label: 'Cần xem xét',
                  count: reviewCount,
                  color: DytavaColors.amber,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentBar(int index, FingerprintSegment segment) {
    final color = _verdictColor(segment.verdict);
    final isSelected = selectedSegmentIndex == index;

    return Expanded(
      flex: (segment.weight * 1000).toInt().clamp(1, 1000),
      child: GestureDetector(
        onTap: () => onSegmentTap?.call(index),
        child: Container(
          decoration: BoxDecoration(
            color: color,
            border: isSelected
                ? Border.all(color: DytavaColors.graphite, width: 2)
                : Border(
                    right: BorderSide(
                      color: DytavaColors.white.withValues(alpha: 0.6),
                      width: 1,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem({
    required String label,
    required int count,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: DytavaTypography.bodySmall.copyWith(
            fontSize: 11,
            color: DytavaColors.graphite,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '($count)',
          style: DytavaTypography.dataSmall.copyWith(
            fontSize: 11,
            color: DytavaColors.precisionNeutral,
          ),
        ),
      ],
    );
  }
}
