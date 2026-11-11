import 'package:flutter/material.dart';

import 'dytava_colors.dart';
import 'dytava_typography.dart';
import 'dytava_asset.dart';
import 'dytava_icons.dart';
import 'dytava_illustrations.dart';

/// Các thành phần giao diện mẫu (UI Components) chuẩn theo nhận diện Dytava
class DytavaStatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final Color backgroundColor;
  final String? iconAsset;

  const DytavaStatusBadge({
    super.key,
    required this.label,
    required this.color,
    required this.backgroundColor,
    this.iconAsset,
  });

  factory DytavaStatusBadge.exact() => const DytavaStatusBadge(
    label: 'EXACT',
    color: DytavaColors.exact,
    backgroundColor: DytavaColors.exactBg,
    iconAsset: DytavaIcons.exact,
  );

  factory DytavaStatusBadge.equivalent() => const DytavaStatusBadge(
    label: 'EQUIVALENT',
    color: DytavaColors.equivalent,
    backgroundColor: DytavaColors.equivalentBg,
    iconAsset: DytavaIcons.equivalent,
  );

  factory DytavaStatusBadge.different() => const DytavaStatusBadge(
    label: 'DIFFERENT',
    color: DytavaColors.different,
    backgroundColor: DytavaColors.differentBg,
    iconAsset: DytavaIcons.different,
  );

  factory DytavaStatusBadge.unresolved() => const DytavaStatusBadge(
    label: 'UNRESOLVED',
    color: DytavaColors.unresolved,
    backgroundColor: DytavaColors.unresolvedBg,
    iconAsset: DytavaIcons.unresolved,
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (iconAsset != null) ...[
            DytavaAsset(iconAsset!, size: 18),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: DytavaTypography.labelSmall.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

/// Thẻ kết quả so sánh (Result Card)
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
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: DytavaColors.softGreen,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: const DytavaAsset(DytavaIcons.fileXlsx, size: 28),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Kết quả so sánh',
                          style: DytavaTypography.titleMedium,
                        ),
                        Text(
                          '$fileA ↔ $fileB',
                          style: DytavaTypography.bodyMedium,
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
                      color: DytavaColors.softGreen,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DytavaAsset(DytavaIcons.success, size: 18),
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
              const SizedBox(height: 16),
              Row(
                children: [
                  _MetricBox(
                    count: totalPairs,
                    label: 'Cặp ô',
                    color: DytavaColors.primary,
                    bgColor: DytavaColors.softBlue,
                  ),
                  const SizedBox(width: 8),
                  _MetricBox(
                    count: equivalentCount,
                    label: 'Tương đương',
                    color: DytavaColors.equivalent,
                    bgColor: DytavaColors.equivalentBg,
                  ),
                  const SizedBox(width: 8),
                  _MetricBox(
                    count: differentCount,
                    label: 'Khác biệt',
                    color: DytavaColors.red,
                    bgColor: DytavaColors.softRed,
                  ),
                  const SizedBox(width: 8),
                  _MetricBox(
                    count: unresolvedCount,
                    label: 'Chưa xác định',
                    color: DytavaColors.unresolved,
                    bgColor: DytavaColors.unresolvedBg,
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

class _MetricBox extends StatelessWidget {
  final int count;
  final String label;
  final Color color;
  final Color bgColor;

  const _MetricBox({
    required this.count,
    required this.label,
    required this.color,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: DytavaTypography.metricNumber.copyWith(color: color),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Trạng thái rỗng chuẩn thương hiệu (Empty State)
class DytavaEmptyState extends StatelessWidget {
  final VoidCallback? onImport;
  final VoidCallback? onOcr;

  const DytavaEmptyState({super.key, this.onImport, this.onOcr});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const DytavaAsset(DytavaIllustrations.emptyComparisons, size: 144),
            const SizedBox(height: 20),
            const Text(
              'Sẵn sàng đối chiếu',
              style: DytavaTypography.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Nhập hai giá trị ở trên rồi bấm So sánh để xem kết quả.',
              textAlign: TextAlign.center,
              style: DytavaTypography.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
