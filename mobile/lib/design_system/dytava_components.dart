import 'package:excelcompare_core/excelcompare_core.dart';
import 'package:flutter/material.dart';

import '../domain/workflow.dart';
import 'dytava_asset.dart';
import 'dytava_colors.dart';
import 'dytava_icons.dart';
import 'dytava_illustrations.dart';
import 'dytava_typography.dart';

/// Huy hiệu trạng thái so sánh chuẩn thương hiệu Dytava v2.0
class DytavaStatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final Color backgroundColor;
  final String? iconAsset;
  final IconData? iconData;

  const DytavaStatusBadge({
    super.key,
    required this.label,
    required this.color,
    required this.backgroundColor,
    this.iconAsset,
    this.iconData,
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

  factory DytavaStatusBadge.added({String label = 'ROW_ADDED'}) =>
      DytavaStatusBadge(
        label: label,
        color: DytavaColors.exact,
        backgroundColor: DytavaColors.exactBg,
        iconData: Icons.add_circle_outline,
      );

  factory DytavaStatusBadge.removed({String label = 'ROW_REMOVED'}) =>
      DytavaStatusBadge(
        label: label,
        color: DytavaColors.different,
        backgroundColor: DytavaColors.differentBg,
        iconData: Icons.remove_circle_outline,
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
            DytavaAsset(iconAsset!, size: 16),
            const SizedBox(width: 4),
          ] else if (iconData != null) ...[
            Icon(iconData, size: 14, color: color),
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

/// Thẻ kết quả so sánh (Result Card) chuẩn Brand Showcase Dytava
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
                    child: const DytavaAsset(DytavaIcons.fileXlsx, size: 24),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Kết quả so sánh 2 Sheets',
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
                        DytavaAsset(DytavaIcons.success, size: 16),
                        SizedBox(width: 4),
                        Text(
                          'Hoàn thành',
                          style: TextStyle(
                            fontSize: 11,
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
              Row(
                children: [
                  _MetricBox(
                    count: totalPairs,
                    label: 'Cặp ô',
                    color: DytavaColors.primary,
                    bgColor: DytavaColors.softBlue,
                  ),
                  const SizedBox(width: 6),
                  _MetricBox(
                    count: equivalentCount,
                    label: 'Tương đương',
                    color: DytavaColors.equivalent,
                    bgColor: DytavaColors.equivalentBg,
                  ),
                  const SizedBox(width: 6),
                  _MetricBox(
                    count: differentCount,
                    label: 'Khác biệt',
                    color: DytavaColors.red,
                    bgColor: DytavaColors.softRed,
                  ),
                  const SizedBox(width: 6),
                  _MetricBox(
                    count: unresolvedCount,
                    label: 'Chưa kết luận',
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
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: DytavaTypography.metricNumber.copyWith(
                color: color,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
          ],
        ),
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
    return Card(
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: DytavaColors.softPurple,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: const DytavaAsset(DytavaIcons.saveRule, size: 22),
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
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: DytavaColors.softPurple,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Đang dùng',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: DytavaColors.purple,
                    ),
                  ),
                )
              else
                const Icon(
                  Icons.chevron_right,
                  color: DytavaColors.textMuted,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Thẻ tệp nguồn (File Card) chuẩn Brand Showcase Dytava
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
    final (badgeText, badgeBg, badgeFg) = switch (format) {
      SourceFormat.xlsx => ('X', DytavaColors.softGreen, DytavaColors.exact),
      SourceFormat.csv => ('CSV', DytavaColors.softBlue, DytavaColors.primary),
      SourceFormat.tsv => ('TSV', DytavaColors.softCyan, DytavaColors.cyan),
      SourceFormat.png || SourceFormat.jpeg => (
        'OCR',
        DytavaColors.softPurple,
        DytavaColors.purple,
      ),
    };
    return Container(
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  badgeText,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: badgeFg,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName,
                      style: DytavaTypography.titleMedium.copyWith(fontSize: 14),
                    ),
                    Text(metaText, style: DytavaTypography.bodySmall),
                  ],
                ),
              ),
              if (verified)
                Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    color: DytavaColors.exact,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    size: 14,
                    color: DytavaColors.white,
                  ),
                ),
            ],
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
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
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
                child: const DytavaAsset(DytavaIcons.history, size: 22),
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: DytavaColors.softGreen,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badgeText,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: DytavaColors.exact,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: DytavaColors.textMuted),
            ],
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
class DytavaFeatureGrid extends StatelessWidget {
  final List<DytavaFeatureItem> items;

  const DytavaFeatureGrid({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final item in items)
          InkWell(
            onTap: item.onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 74,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
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
                    child: DytavaAsset(item.iconAsset, size: 22),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: DytavaColors.textPrimary,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Thanh Tab / Bộ lọc danh mục (Filter / View Mode Tabs) chuẩn Brand Showcase
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
              child: GestureDetector(
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  decoration: BoxDecoration(
                    color: selectedIndex == i
                        ? DytavaColors.primary
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  alignment: Alignment.center,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      tabs[i],
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

/// Thanh điều hướng dưới cùng (Bottom Navigation Bar 5 Tabs) chuẩn Brand Showcase
class DytavaBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const DytavaBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  static const _items = [
    ('Trang chủ', Icons.home_outlined, Icons.home),
    ('So sánh', Icons.table_chart_outlined, Icons.table_chart),
    ('Lịch sử', Icons.history_outlined, Icons.history),
    ('Học tập', Icons.school_outlined, Icons.school),
    ('Cài đặt', Icons.settings_outlined, Icons.settings),
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
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              for (var i = 0; i < _items.length; i++)
                Expanded(
                  child: InkWell(
                    onTap: () => onTap(i),
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: currentIndex == i
                            ? DytavaColors.softBlue
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            currentIndex == i ? _items[i].$3 : _items[i].$2,
                            size: 20,
                            color: currentIndex == i
                                ? DytavaColors.primary
                                : DytavaColors.textSecondary,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _items[i].$1,
                            style: TextStyle(
                              fontSize: 10,
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
            ],
          ),
        ),
      ),
    );
  }
}

/// Bảng xem trước trang tính (Spreadsheet Grid Preview) cho 1 nguồn dữ liệu
class DytavaSheetPreviewTable extends StatelessWidget {
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
  Widget build(BuildContext context) {
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: DytavaColors.softBlue,
              borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.grid_on,
                  size: 16,
                  color: DytavaColors.primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    sheetTitle,
                    style: DytavaTypography.labelLarge.copyWith(
                      color: DytavaColors.primary,
                    ),
                  ),
                ),
                Text(
                  '${records.length} hàng × ${fields.length} cột',
                  style: DytavaTypography.bodySmall.copyWith(
                    color: DytavaColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          // Dòng tiêu đề cột
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: const BoxDecoration(
              color: DytavaColors.background,
              border: Border(bottom: BorderSide(color: DytavaColors.border)),
            ),
            child: Row(
              children: [
                const SizedBox(
                  width: 36,
                  child: Text(
                    '#',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: DytavaColors.textSecondary,
                    ),
                  ),
                ),
                for (final f in fields)
                  Expanded(
                    child: Text(
                      '${f.label} (${f.id})',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: DytavaColors.textPrimary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Các hàng dữ liệu
          for (final row in records.take(5))
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: DytavaColors.border)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width: 36,
                        child: Text(
                          '${row.ordinal + 1}',
                          style: DytavaTypography.dataMedium.copyWith(
                            color: DytavaColors.textSecondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      for (final f in fields)
                        Expanded(
                          child: Text(
                            row.cells[f.id]?.rawLexeme ??
                                '[${row.cells[f.id]?.kind.name ?? 'null'}]',
                            style: DytavaTypography.dataMedium.copyWith(
                              color: DytavaColors.textPrimary,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Hàng ${row.ordinal + 1}: ${row.cells.values.map((c) => c.rawLexeme ?? '[${c.kind.name}]').join(' | ')}',
                    style: DytavaTypography.bodySmall.copyWith(fontSize: 10),
                  ),
                ],
              ),
            ),
        ],
      ),
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

/// Component trung tâm: Bảng đối chiếu 2 Sheets (Sheet Diff 2 Sheets)
/// Thay thế cho danh sách so sánh từng ô rời rạc bằng góc nhìn bảng tính 2 chiều.
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
    // Nhóm các ô hiển thị theo cặp hàng (rowA, rowB) để dựng thành hàng của Sheet Diff
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Thanh chuyển đổi chế độ Sheet Diff: Hợp nhất 2 Sheets vs Song song 2 Sheets
        Container(
          padding: const EdgeInsets.all(10),
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
                  const Icon(
                    Icons.compare,
                    size: 18,
                    color: DytavaColors.primary,
                  ),
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
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _modeButton(
                      label: 'Bảng hợp nhất (A ↔ B)',
                      icon: Icons.table_rows_outlined,
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
                      icon: Icons.view_column_outlined,
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
          runSpacing: 4,
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
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 8),
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
            Icon(
              icon,
              size: 14,
              color: selected ? DytavaColors.white : DytavaColors.textSecondary,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: selected
                        ? DytavaColors.white
                        : DytavaColors.textPrimary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendChip(String text, Color fg, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: fg.withValues(alpha: 0.35)),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }

  /// Chế độ 1: Bảng Sheet Diff hợp nhất 2 Sheets (hiển thị hàng × cột với giá trị A ↔ B trong từng ô)
  Widget _buildUnifiedSheetDiff(
    List<FieldMapping> mappings,
    List<String> rowKeys,
    Map<String, Map<String, CellDifference>> rowMap,
    Map<String, (String, String)> rowLabels,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: DytavaColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DytavaColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header cột của bảng Sheet Diff
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            decoration: const BoxDecoration(
              color: DytavaColors.darkNavy,
              borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
            ),
            child: Row(
              children: [
                const SizedBox(
                  width: 42,
                  child: Text(
                    'Hàng',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: DytavaColors.white,
                    ),
                  ),
                ),
                for (final m in mappings)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        'Cột ${m.fieldA} ↔ ${m.fieldB}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: DytavaColors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Từng hàng của 2 Sheets đã ghép
          for (var rIdx = 0; rIdx < rowKeys.length; rIdx++) ...[
            Builder(
              builder: (context) {
                final key = rowKeys[rIdx];
                final cellsByField = rowMap[key]!;
                final (rA, rB) = rowLabels[key]!;
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: DytavaColors.border),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Cột chỉ mục hàng A/B
                      SizedBox(
                        width: 42,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: DytavaColors.background,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '#${rIdx + 1}',
                                style: DytavaTypography.dataMedium.copyWith(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$rA\n$rB',
                              style: const TextStyle(
                                fontSize: 9,
                                color: DytavaColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Từng ô cột trong hàng Sheet Diff
                      for (final m in mappings)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: cellsByField.containsKey(m.fieldA)
                                ? _buildUnifiedDiffCell(cellsByField[m.fieldA]!)
                                : Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: DytavaColors.background,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      '— (ẩn bởi bộ lọc)',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: DytavaColors.textMuted,
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ],
          // Hiển thị các hàng thêm/bớt (ROW_ADDED / ROW_REMOVED) ngay dưới chân bảng Sheet Diff
          for (final s in widget.result.structural)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: s.kind.contains('ADDED')
                    ? DytavaColors.softGreen
                    : DytavaColors.softRed,
                border: const Border(
                  bottom: BorderSide(color: DytavaColors.border),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    s.kind.contains('ADDED')
                        ? Icons.add_box_outlined
                        : Icons.indeterminate_check_box_outlined,
                    size: 16,
                    color: s.kind.contains('ADDED')
                        ? DytavaColors.exact
                        : DytavaColors.different,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
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
                  _legendChip(
                    s.side == SourceSide.b ? 'Chỉ có ở Sheet B' : 'Chỉ có ở Sheet A',
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
  }

  Widget _buildUnifiedDiffCell(CellDifference cell) {
    final (fg, bg) = _statusColors(cell.decision.status);
    final rawA = cell.a.rawLexeme ?? '[${cell.a.kind.name}]';
    final rawB = cell.b.rawLexeme ?? '[${cell.b.kind.name}]';
    final statusText = _statusName(cell.decision.status);

    return Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: fg.withValues(alpha: 0.45), width: 1),
      ),
      child: InkWell(
        onTap: () => widget.onSelectCell(cell.id),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Dòng trạng thái ô (giữ đúng text '${fieldA}: ${STATUS}' cho kiểm thử & truy vết)
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  '${cell.mapping.fieldA}: $statusText',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: fg,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              // Giá trị Sheet A đối chiếu Sheet B ngay trong ô bảng tính
              Text(
                'A: $rawA · B: $rawB',
                style: DytavaTypography.dataMedium.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: DytavaColors.textPrimary,
                ),
              ),
              if (cell.decision.status == DecisionStatus.equivalent)
                Text(
                  'Chuẩn hóa: ${cell.decision.left?.label ?? rawA}',
                  style: TextStyle(fontSize: 10, color: fg),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Chế độ 2: Đặt 2 bảng Sheet A và Sheet B song song cạnh nhau (Side-by-Side 2 Sheets)
  Widget _buildSideBySideSheets(
    List<FieldMapping> mappings,
    List<String> rowKeys,
    Map<String, Map<String, CellDifference>> rowMap,
    Map<String, (String, String)> rowLabels,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Bảng Sheet A (Tham chiếu)
        Expanded(
          child: _buildSingleSideSheet(
            title: 'SHEET A ( gốc )',
            headerColor: DytavaColors.primary,
            isSideA: true,
            mappings: mappings,
            rowKeys: rowKeys,
            rowMap: rowMap,
          ),
        ),
        const SizedBox(width: 8),
        // Bảng Sheet B (Đối chiếu)
        Expanded(
          child: _buildSingleSideSheet(
            title: 'SHEET B ( đối chiếu )',
            headerColor: DytavaColors.purple,
            isSideA: false,
            mappings: mappings,
            rowKeys: rowKeys,
            rowMap: rowMap,
          ),
        ),
      ],
    );
  }

  Widget _buildSingleSideSheet({
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
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            decoration: BoxDecoration(
              color: headerColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(9),
              ),
            ),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: DytavaColors.white,
              ),
            ),
          ),
          for (var rIdx = 0; rIdx < rowKeys.length; rIdx++)
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: DytavaColors.border)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hàng #${rIdx + 1}',
                    style: const TextStyle(
                      fontSize: 10,
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
                          onTap: () => widget.onSelectCell(cell.id),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 4,
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
                              style: DytavaTypography.dataMedium.copyWith(
                                fontSize: 11,
                                color: DytavaColors.textPrimary,
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
