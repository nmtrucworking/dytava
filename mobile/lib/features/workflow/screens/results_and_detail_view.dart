import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:excelcompare_core/excelcompare_core.dart';
import 'package:flutter/material.dart';

import '../../../application/workflow_controller.dart';
import '../../../design_system/design_system.dart';
import '../../../domain/workflow.dart';
import '../../shared/text_difference_evidence.dart';
import '../widgets/mobile_aligned_grid.dart';
import '../widgets/workflow_common_widgets.dart';

/// Màn hình Kết quả đối chiếu (`SCR-08`):
/// - Summary ngắn kèm `BrandIllustration.success(asset: DytavaIllustrations.successCompare)`.
/// - Danh sách sai khác cần xử lý (`Các khác biệt cần kiểm tra`) ưu tiên hiển thị đầu tiên.
/// - Chế độ xem chi tiết (`Sheet Diff (2 Bảng)` và `Theo danh sách ô`) tích hợp `BrandIllustration.emptyFilter()` khi bộ lọc trống.
class ResultsScreenView extends StatelessWidget {
  final WorkflowController flow;
  final int resultViewTab;
  final ValueChanged<int> onResultViewTabChanged;
  final void Function(String cellId) onOpenDetail;
  final VoidCallback onOpenExport;

  const ResultsScreenView({
    super.key,
    required this.flow,
    required this.resultViewTab,
    required this.onResultViewTabChanged,
    required this.onOpenDetail,
    required this.onOpenExport,
  });

  Widget _metricBox(
    String fullLabel,
    String subLabel,
    Color color,
    Color bgColor,
    String iconAsset,
  ) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              BrandIcon(iconAsset, size: 15),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  fullLabel,
                  style: DytavaTypography.labelLarge.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            subLabel,
            style: DytavaTypography.bodySmall.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _decisionBadge(DecisionStatus status) => switch (status) {
    DecisionStatus.exact => DytavaStatusBadge.exact(),
    DecisionStatus.equivalent => DytavaStatusBadge.equivalent(),
    DecisionStatus.different => DytavaStatusBadge.different(),
    DecisionStatus.unresolved => DytavaStatusBadge.unresolved(),
  };

  Widget _filterChips(ComparisonResult res) {
    final items = <(DecisionStatus?, String, Color, Color)>[
      (
        null,
        'Tất cả (${res.cells.length})',
        DytavaColors.primary,
        DytavaColors.softBlue,
      ),
      (
        DecisionStatus.different,
        'Khác biệt (${res.count(DecisionStatus.different)})',
        DytavaColors.different,
        DytavaColors.differentBg,
      ),
      (
        DecisionStatus.unresolved,
        'Chưa kết luận (${res.count(DecisionStatus.unresolved)})',
        DytavaColors.unresolved,
        DytavaColors.unresolvedBg,
      ),
      (
        DecisionStatus.equivalent,
        'Tương đương (${res.count(DecisionStatus.equivalent)})',
        DytavaColors.equivalent,
        DytavaColors.equivalentBg,
      ),
      (
        DecisionStatus.exact,
        'Trùng khớp (${res.count(DecisionStatus.exact)})',
        DytavaColors.exact,
        DytavaColors.exactBg,
      ),
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final (status, label, color, bg) in items)
            FilterChip(
              selected: flow.resultFilter == status,
              label: Text(label),
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: flow.resultFilter == status
                    ? FontWeight.bold
                    : FontWeight.w500,
                color: flow.resultFilter == status
                    ? color
                    : DytavaColors.textPrimary,
              ),
              backgroundColor: DytavaColors.white,
              selectedColor: bg,
              checkmarkColor: color,
              side: BorderSide(
                color: flow.resultFilter == status
                    ? color
                    : DytavaColors.border,
              ),
              onSelected: (_) => flow.filterResults(status),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final result = flow.result!;
    final priorityCells = result.cells
        .where(
          (c) =>
              c.decision.status == DecisionStatus.different ||
              c.decision.status == DecisionStatus.unresolved,
        )
        .toList();
    final labelA = flow.slot(SourceSide.a).artifact?.label ?? 'Nguồn A';
    final labelB = flow.slot(SourceSide.b).artifact?.label ?? 'Nguồn B';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Summary ngắn + BrandIllustration.success(successCompare)
        DifferenceFingerprint.fromCounts(
          exactCount: result.count(DecisionStatus.exact),
          equivalentCount: result.count(DecisionStatus.equivalent),
          differentCount: result.count(DecisionStatus.different),
          unresolvedCount: result.count(DecisionStatus.unresolved),
          onSegmentTap: (index) {
            if (index == 0) flow.filterResults(DecisionStatus.exact);
            if (index == 1) flow.filterResults(DecisionStatus.different);
            if (index == 2) flow.filterResults(DecisionStatus.unresolved);
          },
        ),
        const SizedBox(height: 12),
        WorkflowSectionCard(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BrandIllustration.success(
                  asset: DytavaIllustrations.successCompare,
                  size: 48,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'COMPLETED · Kết quả so sánh',
                        style: DytavaTypography.titleLarge.copyWith(
                          color: DytavaColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$labelA ↔ $labelB · Chiều: ${result.plan.config.direction == ComparisonDirection.aToB ? 'A → B' : 'B → A'}',
                        style: DytavaTypography.bodySmall,
                      ),
                    ],
                  ),
                ),
                const WorkflowStatusPill(
                  label: 'Hoàn thành',
                  color: DytavaColors.exact,
                  bg: DytavaColors.softGreen,
                  iconAsset: DytavaIcons.success,
                ),
              ],
            ),
            const Divider(height: 20),
            Text(
              'Ô ghép: ${result.cells.length} · Hàng ghép: ${result.matchedRecords}',
              style: DytavaTypography.bodyMedium,
            ),
            const SizedBox(height: 12),
            // Hàng 1 (Ưu tiên cao): Khác biệt & Chưa kết luận
            Row(
              children: [
                _metricBox(
                  'DIFFERENT: ${result.count(DecisionStatus.different)}',
                  'Ô khác biệt',
                  DytavaColors.different,
                  DytavaColors.differentBg,
                  DytavaIcons.different,
                ),
                const SizedBox(width: 8),
                _metricBox(
                  'UNRESOLVED: ${result.count(DecisionStatus.unresolved)}',
                  'Chưa kết luận',
                  DytavaColors.unresolved,
                  DytavaColors.unresolvedBg,
                  DytavaIcons.unresolved,
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Hàng 2 (Bổ trợ): Trùng khớp & Tương đương
            Row(
              children: [
                _metricBox(
                  'EXACT: ${result.count(DecisionStatus.exact)}',
                  'Trùng khớp',
                  DytavaColors.exact,
                  DytavaColors.exactBg,
                  DytavaIcons.exact,
                ),
                const SizedBox(width: 8),
                _metricBox(
                  'EQUIVALENT: ${result.count(DecisionStatus.equivalent)}',
                  'Tương đương',
                  DytavaColors.equivalent,
                  DytavaColors.equivalentBg,
                  DytavaIcons.equivalent,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: DytavaColors.background,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Exact: ${result.exactRate == null ? 'N/A' : '${(result.exactRate! * 100).toStringAsFixed(1)}%'} · Đồng thuận: ${result.agreementRate == null ? 'N/A' : '${(result.agreementRate! * 100).toStringAsFixed(1)}%'} · Mẫu số: ${result.cells.length} ô',
                style: DytavaTypography.bodyMedium,
              ),
            ),
          ],
        ),

        // Thẻ kết quả chuyên biệt theo mục tiêu tác vụ (Compare Files / Columns / Reconcile)
        if (flow.taskMode == ComparisonTaskMode.compareColumns)
          WorkflowSectionCard(
            color: DytavaColors.softBlue,
            border: Border.all(
              color: DytavaColors.primary.withValues(alpha: 0.3),
            ),
            children: [
              Row(
                children: [
                  const BrandIcon(DytavaIcons.columns, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Kết quả so sánh 2 cột (Compare Columns)',
                      style: DytavaTypography.titleLarge.copyWith(
                        color: DytavaColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Phát hiện trùng lặp & giá trị chỉ xuất hiện ở một phía giữa 2 cột.',
                style: DytavaTypography.bodySmall,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _metricBox(
                    'Trùng khớp: ${result.count(DecisionStatus.exact) + result.count(DecisionStatus.equivalent)}',
                    'Xuất hiện ở cả 2 cột',
                    DytavaColors.exact,
                    DytavaColors.softGreen,
                    DytavaIcons.success,
                  ),
                  const SizedBox(width: 8),
                  _metricBox(
                    'Khác biệt: ${result.count(DecisionStatus.different)}',
                    'Giá trị không trùng',
                    DytavaColors.different,
                    DytavaColors.differentBg,
                    DytavaIcons.different,
                  ),
                ],
              ),
            ],
          )
        else if (flow.taskMode == ComparisonTaskMode.reconcile)
          WorkflowSectionCard(
            color: DytavaColors.softBlue,
            border: Border.all(
              color: DytavaColors.primary.withValues(alpha: 0.3),
            ),
            children: [
              Row(
                children: [
                  const BrandIcon(DytavaIcons.key, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Kết quả đối soát theo ID (Reconcile by ID)',
                      style: DytavaTypography.titleLarge.copyWith(
                        color: DytavaColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'So khớp theo mã định danh không phụ thuộc thứ tự hàng (No VLOOKUP).',
                style: DytavaTypography.bodySmall,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _metricBox(
                    'Ghép theo ID: ${result.matchedRecords}',
                    'Bản ghi tìm thấy cả 2 phía',
                    DytavaColors.primary,
                    DytavaColors.softBlue,
                    DytavaIcons.link,
                  ),
                  const SizedBox(width: 8),
                  _metricBox(
                    'Lệch giá trị: ${result.count(DecisionStatus.different)}',
                    'Cần kiểm tra đối soát',
                    DytavaColors.different,
                    DytavaColors.differentBg,
                    DytavaIcons.different,
                  ),
                ],
              ),
            ],
          ),

        // 2. Danh sách sai khác theo mức độ cần xử lý (Priority Diff Cards)
        if (priorityCells.isNotEmpty)
          WorkflowSectionCard(
            children: [
              Row(
                children: [
                  const BrandIcon(DytavaIcons.differences, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Các khác biệt cần kiểm tra (${priorityCells.length})',
                      style: DytavaTypography.titleLarge.copyWith(
                        color: DytavaColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Kiểm tra nhanh các ô Khác biệt hoặc Chưa kết luận trước khi mở toàn bộ bảng đối chiếu.',
                style: DytavaTypography.bodyMedium,
              ),
              const SizedBox(height: 8),
              for (final pCell in priorityCells.take(5))
                DytavaPriorityDiffCard(
                  cell: pCell,
                  onQuickBottomSheet: () => showDytavaCellDetailBottomSheet(
                    context: context,
                    cell: pCell,
                    onOpenFullDetail: () => onOpenDetail(pCell.id),
                  ),
                  onInspectDetail: () => onOpenDetail(pCell.id),
                ),
            ],
          ),

        // 3. Thống kê cấu trúc riêng (Hàng thêm / bớt / chưa ghép)
        if (result.structural.isNotEmpty || result.unresolvedRecords.isNotEmpty)
          WorkflowSectionCard(
            children: [
              Row(
                children: [
                  const BrandIcon(DytavaIcons.rows, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Cấu trúc (thống kê riêng)',
                      style: DytavaTypography.titleLarge.copyWith(
                        color: DytavaColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              for (final s in result.structural)
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: DytavaColors.softBlue,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      BrandIcon(
                        s.kind.contains('ADDED')
                            ? DytavaIcons.added
                            : DytavaIcons.removed,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${s.kind} · ${s.side.name.toUpperCase()} · ${s.recordId}',
                          style: DytavaTypography.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              for (final g in result.unresolvedRecords)
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: DytavaColors.softAmber,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const BrandIcon(DytavaIcons.duplicate, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${g.reason} · A: ${g.recordsA.length}, B: ${g.recordsB.length} hàng chưa ghép',
                          style: DytavaTypography.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

        // 4. Bảng đối chiếu đầy đủ & Danh sách ô theo bộ lọc
        WorkflowSectionCard(
          children: [
            Row(
              children: [
                const BrandIcon(DytavaIcons.compareTable, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Xem bảng đối chiếu đầy đủ',
                    style: DytavaTypography.titleLarge.copyWith(
                      color: DytavaColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Mở bảng cuộn ngang với cột định danh cố định hoặc duyệt theo danh sách ô.',
              style: DytavaTypography.bodyMedium,
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: DytavaFilterTabs(
                tabs: const ['Sheet Diff (2 Bảng)', 'Theo danh sách ô'],
                selectedIndex: resultViewTab,
                onChanged: onResultViewTabChanged,
              ),
            ),
            if (resultViewTab == 0 && result.alignedRows.isNotEmpty)
              MobileAlignedGrid(result: result, onOpenCell: onOpenDetail)
            else ...[
              _filterChips(result),
              DropdownButtonFormField<DecisionStatus?>(
                key: ValueKey('filter-${flow.resultFilter}'),
                initialValue: flow.resultFilter,
                decoration: const InputDecoration(
                  labelText: 'Lọc trạng thái ô',
                  prefixIcon: Padding(
                    padding: EdgeInsets.all(12),
                    child: BrandIcon(DytavaIcons.filter, size: 18),
                  ),
                ),
                items: [
                  const DropdownMenuItem<DecisionStatus?>(
                    value: null,
                    child: Text('Tất cả'),
                  ),
                  for (final s in DecisionStatus.values)
                    DropdownMenuItem(
                      value: s,
                      child: Text(WorkflowUiHelpers.formatEnumName(s)),
                    ),
                ],
                onChanged: flow.filterResults,
              ),
              const SizedBox(height: 12),
              if (flow.visibleCells.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: DytavaColors.background,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      BrandIllustration.emptyFilter(size: 72),
                      const SizedBox(height: 8),
                      const Text(
                        'Không có ô nào khớp bộ lọc hiện tại',
                        style: DytavaTypography.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Hãy chọn Tất cả hoặc một trạng thái khác để xem tiếp các cặp ô.',
                        textAlign: TextAlign.center,
                        style: DytavaTypography.bodySmall,
                      ),
                    ],
                  ),
                )
              else if (resultViewTab == 0)
                DytavaSheetDiffView(
                  result: result,
                  visibleCells: flow.visibleCells,
                  onSelectCell: onOpenDetail,
                  sourceALabel: labelA,
                  sourceBLabel: labelB,
                  sourceAFormat:
                      flow.slot(SourceSide.a).artifact?.format ??
                      SourceFormat.csv,
                  sourceBFormat:
                      flow.slot(SourceSide.b).artifact?.format ??
                      SourceFormat.csv,
                  onExport: onOpenExport,
                )
              else
                for (final cell in flow.visibleCells)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Material(
                      color: DytavaColors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: const BorderSide(color: DytavaColors.border),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        leading: BrandIcon.decision(
                          cell.decision.status,
                          size: 22,
                        ),
                        title: Text(
                          '${cell.mapping.fieldA}: ${WorkflowUiHelpers.formatEnumName(cell.decision.status)}',
                          style: DytavaTypography.titleMedium,
                        ),
                        subtitle: Text(
                          'A: ${cell.a.rawLexeme ?? '[${cell.a.kind.name}]'} · B: ${cell.b.rawLexeme ?? '[${cell.b.kind.name}]'}',
                          style: DytavaTypography.dataMedium,
                        ),
                        trailing: _decisionBadge(cell.decision.status),
                        onTap: () => onOpenDetail(cell.id),
                      ),
                    ),
                  ),
              const SizedBox(height: 10),
              Text(
                'Trang ${flow.page + 1} · ${flow.selectedCells.length} ô trong bộ lọc. Summary phía trên là toàn bộ kết quả.',
                style: DytavaTypography.bodyMedium,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(48, 48),
                      ),
                      icon: const BrandIcon(DytavaIcons.back, size: 16),
                      onPressed: flow.page > 0 ? () => flow.turnPage(-1) : null,
                      label: const Text('Trang trước'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(48, 48),
                      ),
                      icon: const BrandIcon(DytavaIcons.forward, size: 16),
                      onPressed:
                          (flow.page + 1) * WorkflowController.pageSize <
                              flow.selectedCells.length
                          ? () => flow.turnPage(1)
                          : null,
                      label: const Text('Trang sau'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        WorkflowPrimaryButton(
          label: 'Xuất / xem trước báo cáo',
          iconAsset: DytavaIcons.export,
          onPressed: onOpenExport,
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(48, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const BrandIcon(DytavaIcons.play, size: 18),
            label: const Text('Bắt đầu phiên so sánh mới'),
            onPressed: () => flow.navigate(WorkflowScreen.sources),
          ),
        ),
      ],
    );
  }
}

/// Màn hình Chi tiết sai khác (`SCR-09`):
/// - Tích hợp `BrandIllustration.verdict(cell.decision.status)` (`statusExact`, `statusEquivalent`, `statusDifferent`, `statusUnresolved`).
/// - Hai giá trị A/B xếp dọc trên điện thoại (`< 680dp`) và 2 cột trên màn hình lớn (`>= 680dp`), kèm vị trí nguồn và giải thích kết luận.
class DifferenceDetailScreenView extends StatelessWidget {
  final WorkflowController flow;
  final ValueChanged<String> onSelectCellId;
  final VoidCallback onBackToResults;

  const DifferenceDetailScreenView({
    super.key,
    required this.flow,
    required this.onSelectCellId,
    required this.onBackToResults,
  });

  Widget _decisionBadge(DecisionStatus status) => switch (status) {
    DecisionStatus.exact => DytavaStatusBadge.exact(),
    DecisionStatus.equivalent => DytavaStatusBadge.equivalent(),
    DecisionStatus.different => DytavaStatusBadge.different(),
    DecisionStatus.unresolved => DytavaStatusBadge.unresolved(),
  };

  Widget _buildSideValueCard(CellDifference cell, SourceSide side) {
    final isSideA = side == SourceSide.a;
    final sideUpper = side.name.toUpperCase();
    final sourceCell = isSideA ? cell.a : cell.b;
    final canonicalVal = isSideA ? cell.decision.left : cell.decision.right;
    final location = isSideA ? cell.locationA : cell.locationB;

    return WorkflowSectionCard(
      children: [
        Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: isSideA ? DytavaColors.primary : DytavaColors.secondary,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text(
                sideUpper,
                style: const TextStyle(
                  color: DytavaColors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nguồn $sideUpper',
                    style: DytavaTypography.titleLarge.copyWith(
                      color: DytavaColors.textPrimary,
                    ),
                  ),
                  Text(
                    isSideA
                        ? 'Bảng tham chiếu (Sheet A)'
                        : 'Bảng đối chiếu (Sheet B)',
                    style: DytavaTypography.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
        const Divider(height: 16),
        Text(
          'Physical kind: ${sourceCell.kind.name}',
          style: DytavaTypography.bodyMedium,
        ),
        Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: DytavaColors.background,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: DytavaColors.border),
          ),
          child: SelectableText(
            'Raw: ${sourceCell.rawLexeme ?? '[không có lexeme]'}',
            style: DytavaTypography.dataMedium.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Text(
          'Canonical: ${canonicalVal?.label ?? '[không đủ căn cứ]'}',
          style: DytavaTypography.bodyMedium,
        ),
        const SizedBox(height: 2),
        Text(
          'Vị trí nguồn: ${location ?? '[không có reference]'}',
          style: DytavaTypography.bodySmall.copyWith(
            color: DytavaColors.textSecondary,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cell = flow.result!.cells.firstWhere((c) => c.id == flow.detailId);
    final list = flow.selectedCells;
    final index = list.indexWhere((c) => c.id == cell.id);
    final hasPrev = index > 0;
    final hasNext = index >= 0 && index < list.length - 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Thanh chuyển đổi Trước / Sau giữa các ô trong danh sách
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: DytavaColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: DytavaColors.border),
          ),
          child: Row(
            children: [
              OutlinedButton.icon(
                icon: const BrandIcon(DytavaIcons.back, size: 16),
                label: const Text('Trước'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                ),
                onPressed: hasPrev
                    ? () => onSelectCellId(list[index - 1].id)
                    : null,
              ),
              Expanded(
                child: Center(
                  child: Text(
                    'Khác biệt ${index >= 0 ? index + 1 : 1}/${list.length}',
                    style: DytavaTypography.titleMedium.copyWith(fontSize: 13),
                  ),
                ),
              ),
              OutlinedButton.icon(
                icon: const BrandIcon(DytavaIcons.forward, size: 16),
                label: const Text('Sau'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                ),
                onPressed: hasNext
                    ? () => onSelectCellId(list[index + 1].id)
                    : null,
              ),
            ],
          ),
        ),

        // Precision Workspace: Focus Diff Card (Single record focused comparison)
        FocusDiffCard(
          fieldName: '${cell.mapping.fieldA} ↔ ${cell.mapping.fieldB}',
          rowIdentifier: 'Hàng ${cell.rowA} ↔ ${cell.rowB}',
          statusText: WorkflowUiHelpers.formatEnumName(cell.decision.status),
          statusColor: cell.decision.status == DecisionStatus.different
              ? DytavaColors.differenceCoral
              : (cell.decision.status == DecisionStatus.unresolved
                    ? DytavaColors.amber
                    : DytavaColors.primary),
          rawA: cell.a.rawLexeme ?? '(trống)',
          rawB: cell.b.rawLexeme ?? '(trống)',
          sourceRefA: cell.locationA,
          sourceRefB: cell.locationB,
          ruleReason: cell.decision.reason != null
              ? 'Mã lý do: ${cell.decision.reason!.name} (${cell.decision.ruleId})'
              : 'Quy tắc: ${cell.decision.ruleId}',
          currentIndex: index >= 0 ? index + 1 : 1,
          totalDiffs: list.length,
          onPrevious: hasPrev ? () => onSelectCellId(list[index - 1].id) : null,
          onNext: hasNext ? () => onSelectCellId(list[index + 1].id) : null,
        ),
        const SizedBox(height: 14),

        // Thẻ tiêu đề kết luận kèm `BrandIllustration.verdict(...)`
        WorkflowSectionCard(
          children: [
            Row(
              children: [
                BrandIllustration.verdict(cell.decision.status, size: 52),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${cell.mapping.fieldA} ↔ ${cell.mapping.fieldB}',
                        style: DytavaTypography.titleLarge.copyWith(
                          color: DytavaColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${WorkflowUiHelpers.formatEnumName(cell.decision.status)} · Hàng ${cell.rowA} ↔ ${cell.rowB}',
                        style: DytavaTypography.bodyMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _decisionBadge(cell.decision.status),
              ],
            ),
          ],
        ),

        // Hai giá trị A/B xếp dọc trên điện thoại (< 680dp), 2 cột trên tablet (>= 680dp)
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 680) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildSideValueCard(cell, SourceSide.a)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildSideValueCard(cell, SourceSide.b)),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSideValueCard(cell, SourceSide.a),
                _buildSideValueCard(cell, SourceSide.b),
              ],
            );
          },
        ),

        if (cell.a.rawLexeme != null &&
            cell.b.rawLexeme != null &&
            cell.a.rawLexeme != cell.b.rawLexeme)
          WorkflowSectionCard(
            children: [
              Row(
                children: [
                  const BrandIcon(DytavaIcons.differences, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Đối chiếu trực quan chuỗi',
                      style: DytavaTypography.titleLarge.copyWith(
                        color: DytavaColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextDifferenceEvidence(
                a: cell.a.rawLexeme!,
                b: cell.b.rawLexeme!,
              ),
            ],
          ),

        WorkflowSectionCard(
          children: [
            Row(
              children: [
                const BrandIcon(DytavaIcons.policy, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Căn cứ quyết định (Rationale)',
                    style: DytavaTypography.titleLarge.copyWith(
                      color: DytavaColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Nguyên nhân: ${cell.decision.explanation ?? DytavaPriorityDiffCard.summarizeCause(cell)}',
              style: DytavaTypography.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
                color: DytavaColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Rule: ${cell.decision.ruleId}',
              style: DytavaTypography.bodyMedium,
            ),
            if (cell.decision.reason != null) ...[
              const SizedBox(height: 2),
              Text(
                'Reason: ${cell.decision.reason!.name}',
                style: DytavaTypography.bodyMedium,
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        WorkflowPrimaryButton(
          label: 'Trở về kết quả',
          iconAsset: DytavaIcons.back,
          onPressed: onBackToResults,
        ),
      ],
    );
  }
}

/// Màn hình Xuất & Xem trước báo cáo (`SCR-10`):
/// - Sử dụng `BrandIllustration.securityLocal` và `BrandIllustration.onboarding(DytavaIllustrations.onboardingReport)`.
/// - Khi đang tạo preview hiển thị `BrandIllustration.processing(asset: DytavaIllustrations.processingReport)`.
/// - Không dùng `successExport` hay tuyên bố đã lưu tệp thật khi mới dừng ở JSON preview trong RAM.
class ExportScreenView extends StatelessWidget {
  final WorkflowController flow;
  final ExportKind exportKind;
  final ExportSelection selection;
  final bool scopeConfirmed;
  final ValueChanged<ExportKind> onKindChanged;
  final ValueChanged<ExportSelection> onSelectionChanged;
  final ValueChanged<bool> onScopeConfirmedChanged;
  final VoidCallback onRunExportPreview;
  final VoidCallback onBackToResults;

  const ExportScreenView({
    super.key,
    required this.flow,
    required this.exportKind,
    required this.selection,
    required this.scopeConfirmed,
    required this.onKindChanged,
    required this.onSelectionChanged,
    required this.onScopeConfirmedChanged,
    required this.onRunExportPreview,
    required this.onBackToResults,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WorkflowSectionCard(
          color: DytavaColors.softBlue,
          border: Border.all(
            color: DytavaColors.primary.withValues(alpha: 0.3),
          ),
          children: [
            Row(
              children: [
                BrandIllustration.securityLocal(size: 42),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bảo mật xuất báo cáo',
                        style: DytavaTypography.titleMedium.copyWith(
                          color: DytavaColors.primary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Báo cáo chứa dữ liệu nguồn. Xem trước CSV / JSON và lưu cục bộ vào vị trí bạn chọn.',
                        style: DytavaTypography.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        WorkflowSectionCard(
          children: [
            Row(
              children: [
                BrandIllustration.onboarding(
                  DytavaIllustrations.onboardingReport,
                  maxHeight: 50,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Cấu hình xuất báo cáo',
                    style: DytavaTypography.titleLarge.copyWith(
                      color: DytavaColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<ExportKind>(
              initialValue: exportKind,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Đầu ra',
                prefixIcon: Padding(
                  padding: EdgeInsets.all(12),
                  child: BrandIcon(DytavaIcons.report, size: 18),
                ),
              ),
              items: [
                for (final kind in ExportKind.values)
                  DropdownMenuItem(
                    value: kind,
                    child: Text(
                      '${WorkflowUiHelpers.formatEnumName(kind)}${flow.exporter.supports(kind) ? ' (xem trước)' : ' (chưa hỗ trợ)'}',
                    ),
                  ),
              ],
              onChanged: flow.busy
                  ? null
                  : (kind) {
                      if (kind != null) onKindChanged(kind);
                    },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<ExportSelection>(
              initialValue: selection,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Phạm vi',
                prefixIcon: Padding(
                  padding: EdgeInsets.all(12),
                  child: BrandIcon(DytavaIcons.filter, size: 18),
                ),
              ),
              items: const [
                DropdownMenuItem(
                  value: ExportSelection.fullComparison,
                  child: Text('Toàn bộ'),
                ),
                DropdownMenuItem(
                  value: ExportSelection.differencesOnly,
                  child: Text('Chỉ sai khác + unresolved'),
                ),
              ],
              onChanged: flow.busy
                  ? null
                  : (sel) {
                      if (sel != null) onSelectionChanged(sel);
                    },
            ),
            const SizedBox(height: 12),
            WorkflowCheckTile(
              label: 'Xác nhận định dạng và phạm vi preview',
              checked: scopeConfirmed,
              onChanged: flow.busy ? null : onScopeConfirmedChanged,
            ),
            if (!flow.exporter.supports(exportKind))
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Định dạng này chưa được hỗ trợ. Chọn một định dạng xem trước đang bật.',
                  style: DytavaTypography.bodyMedium,
                ),
              ),
            const SizedBox(height: 12),
            WorkflowPrimaryButton(
              label: 'Tạo bản xem trước',
              iconAsset: DytavaIcons.fileJson,
              onPressed:
                  scopeConfirmed &&
                      flow.exporter.supports(exportKind) &&
                      !flow.busy
                  ? onRunExportPreview
                  : null,
            ),
            if (flow.exportState != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    'Preview attempt: ${WorkflowUiHelpers.formatEnumName(flow.exportState!)}',
                    style: DytavaTypography.bodyMedium,
                  ),
                ),
              ),
            if (flow.exportState?.active == true) ...[
              const SizedBox(height: 10),
              Center(
                child: BrandIllustration.processing(
                  asset: DytavaIllustrations.processingReport,
                  size: 64,
                ),
              ),
              const SizedBox(height: 8),
              const LinearProgressIndicator(),
              const SizedBox(height: 8),
              WorkflowPrimaryButton(
                label: 'Hủy preview',
                iconAsset: DytavaIcons.cancel,
                onPressed: flow.exportState == ExportState.cancelling
                    ? null
                    : flow.cancelExport,
              ),
            ],
          ],
        ),
        if (flow.receipt?.fileName != null)
          WorkflowPrimaryButton(
            label: 'Lưu tệp vào thiết bị',
            iconAsset: DytavaIcons.export,
            onPressed: () async {
              final receipt = flow.receipt!;
              try {
                final uri = await FilePicker.saveFile(
                  fileName: receipt.fileName!,
                  bytes: Uint8List.fromList(utf8.encode(receipt.previewText)),
                  mimeType: receipt.fileName!.endsWith('.csv')
                      ? 'text/csv'
                      : 'application/json',
                );
                if (context.mounted && uri != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Đã lưu báo cáo.')),
                  );
                }
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Không lưu được báo cáo. Hãy chọn lại vị trí.',
                      ),
                    ),
                  );
                }
              }
            },
          ),
        if (flow.receipt != null)
          WorkflowSectionCard(
            children: [
              Row(
                children: [
                  const BrandIcon(DytavaIcons.fileJson, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Bản xem trước đã sẵn sàng.',
                      style: DytavaTypography.titleMedium.copyWith(
                        color: DytavaColors.exact,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: DytavaColors.darkNavy,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SelectableText(
                  flow.receipt!.previewText.length > 20000
                      ? '${flow.receipt!.previewText.substring(0, 20000)}\n… Xem trước 20.000 ký tự; tệp lưu chứa toàn bộ dữ liệu.'
                      : flow.receipt!.previewText,
                  style: const TextStyle(
                    fontFamily: DytavaTypography.dataFont,
                    fontSize: 12,
                    color: Color(0xFFE2E8F0),
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        const SizedBox(height: 8),
        WorkflowPrimaryButton(
          label: 'Trở về kết quả',
          iconAsset: DytavaIcons.back,
          onPressed: flow.busy ? null : onBackToResults,
        ),
      ],
    );
  }
}
