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

  Widget _compactMetricTile({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
    Color? iconColor,
    int? numericValue,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: DytavaColors.graphite800,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: DytavaColors.subtleBorder.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: iconColor ?? color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (numericValue != null)
                  DytavaCountUpText(
                    value: numericValue,
                    duration: const Duration(milliseconds: 650),
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  )
                else
                  Text(
                    value,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10,
                    color: DytavaColors.warmSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendRow({
    required Color color,
    required String label,
    required String countText,
    required String subKey,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '$label $countText',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                color: DytavaColors.offWhite,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            subKey,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrecisionHeroCard(
    BuildContext context,
    ComparisonResult result,
    String labelA,
    String labelB,
  ) {
    final total = result.cells.length;
    final exact = result.count(DecisionStatus.exact);
    final equiv = result.count(DecisionStatus.equivalent);
    final diff = result.count(DecisionStatus.different);
    final unres = result.count(DecisionStatus.unresolved);

    final matchTotal = exact + equiv;
    final matchRate = total > 0 ? matchTotal / total : 0.0;
    final diffRate = total > 0 ? diff / total : 0.0;
    final unresRate = total > 0 ? unres / total : 0.0;

    final matchPercentText = '${(matchRate * 100).toStringAsFixed(1)}%';
    final diffPercentText = '${(diffRate * 100).toStringAsFixed(1)}%';
    final unresPercentText = '${(unresRate * 100).toStringAsFixed(1)}%';

    final totalCols = result.cells.map((c) => c.mapping.fieldA).toSet().length;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: DytavaColors.graphite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: DytavaColors.subtleBorder.withValues(alpha: 0.25),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Tiêu đề gọn gàng & Status Badge
          Row(
            children: [
              const Icon(
                Icons.analytics_outlined,
                size: 18,
                color: DytavaColors.limePrimary,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'COMPLETED · Kết quả so sánh',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: DytavaColors.white,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: DytavaColors.limePrimary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: DytavaColors.limePrimary.withValues(alpha: 0.3),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      size: 12,
                      color: DytavaColors.limePrimary,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Hoàn thành',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: DytavaColors.limePrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 2. Hai thẻ file Nguồn A & Nguồn B
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: DytavaColors.graphite800,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(
                        Icons.description_outlined,
                        size: 14,
                        color: DytavaColors.limePrimary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          labelA,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
                            color: DytavaColors.white,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(
                    Icons.compare_arrows_rounded,
                    size: 16,
                    color: DytavaColors.warmSurface,
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      const Icon(
                        Icons.description_outlined,
                        size: 14,
                        color: DytavaColors.sourceBlue,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          labelB,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
                            color: DytavaColors.white,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 3. Hero Donut Chart Lime Primary & 3 dòng chú giải
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _PrecisionDonutChart(
                matchRate: matchRate,
                diffRate: diffRate,
                unresolvedRate: unresRate,
                matchPercentText: matchPercentText,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _legendRow(
                      color: DytavaColors.limePrimary,
                      label: 'Trùng khớp',
                      countText: '$matchPercentText ($matchTotal)',
                      subKey: 'EXACT: $exact',
                    ),
                    _legendRow(
                      color: DytavaColors.differenceCoral,
                      label: 'Sai khác',
                      countText: '$diffPercentText ($diff)',
                      subKey: 'DIFFERENT: $diff',
                    ),
                    _legendRow(
                      color: DytavaColors.unresolved,
                      label: 'Cần xem xét',
                      countText: '$unresPercentText ($unres)',
                      subKey: 'UNRESOLVED: $unres',
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 4. Lưới 4 Metric Card: Thích ứng linh hoạt 1 hàng 4 cột trên màn hình rộng hoặc 2x2 trên màn hình hẹp
          DytavaResponsiveGroup(
            breakpoint: 420,
            spacing: 6,
            runSpacing: 6,
            children: [
              _compactMetricTile(
                icon: Icons.table_rows_outlined,
                value: '${result.matchedRecords}',
                numericValue: result.matchedRecords,
                label: 'Tổng dòng',
                color: DytavaColors.white,
                iconColor: DytavaColors.warmSurface,
              ),
              _compactMetricTile(
                icon: Icons.view_column_outlined,
                value: '$totalCols',
                numericValue: totalCols,
                label: 'Tổng cột',
                color: DytavaColors.white,
                iconColor: DytavaColors.warmSurface,
              ),
              _compactMetricTile(
                icon: Icons.error_outline_rounded,
                value: '$diff',
                numericValue: diff,
                label: 'Sai khác',
                color: DytavaColors.differenceCoral,
              ),
              _compactMetricTile(
                icon: Icons.search_rounded,
                value: '$unres',
                numericValue: unres,
                label: 'Cần xem xét',
                color: DytavaColors.limePrimary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tabButton(int index, String label) {
    final selected = resultViewTab == index;
    return Expanded(
      child: DytavaTapScale(
        onTap: () => onResultViewTabChanged(index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? DytavaColors.limePrimary : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: selected ? FontWeight.bold : FontWeight.w500,
              color: selected
                  ? DytavaColors.graphite
                  : DytavaColors.textSecondary,
            ),
          ),
        ),
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

    final total = result.cells.length;
    final diffCount = result.count(DecisionStatus.different);
    final diffRateStr = total > 0
        ? '${(diffCount / total * 100).toStringAsFixed(1)}%'
        : '0%';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Hero Precision Card theo Mockup Board 03
        DytavaFadeSlide(
          delay: Duration.zero,
          child: _buildPrecisionHeroCard(context, result, labelA, labelB),
        ),

        // Thanh chuyển Tab chuẩn Mockup Board 03: [ Tổng quan ] | [ Chi tiết ] | [ Theo sheet ]
        DytavaFadeSlide(
          delay: const Duration(milliseconds: 60),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: DytavaColors.warmSurface,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                _tabButton(0, 'Tổng quan'),
                _tabButton(1, 'Chi tiết'),
                _tabButton(2, 'Theo sheet'),
              ],
            ),
          ),
        ),

        // Thẻ tác vụ chuyên biệt (nếu có chế độ so sánh đặc thù)
        if (flow.taskMode == ComparisonTaskMode.compareColumns)
          WorkflowSectionCard(
            color: DytavaColors.softBlue,
            border: Border.all(
              color: DytavaColors.primary.withValues(alpha: 0.3),
            ),
            children: [
              Row(
                children: [
                  const BrandIcon(DytavaIcons.columns, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Kết quả so sánh 2 cột (Compare Columns)',
                      style: DytavaTypography.titleMedium.copyWith(
                        color: DytavaColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Phát hiện trùng lặp & giá trị chỉ xuất hiện ở một phía giữa 2 cột.',
                style: DytavaTypography.bodySmall,
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
                  const BrandIcon(DytavaIcons.key, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Kết quả đối soát theo ID (Reconcile by ID)',
                      style: DytavaTypography.titleMedium.copyWith(
                        color: DytavaColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'So khớp theo mã định danh không phụ thuộc thứ tự hàng (No VLOOKUP).',
                style: DytavaTypography.bodySmall,
              ),
            ],
          ),

        // === TAB 0: TỔNG QUAN (Single Box Insight Card gom các sai khác màu đỏ) ===
        if (resultViewTab == 0) ...[
          // Single Box Insight Card duy nhất gom toàn bộ sai khác đỏ & ô cần kiểm tra
          DytavaFadeSlide(
            delay: const Duration(milliseconds: 100),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: DytavaColors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: diffCount > 0
                      ? DytavaColors.differenceCoral.withValues(alpha: 0.35)
                      : DytavaColors.border,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        diffCount > 0
                            ? Icons.info_outline_rounded
                            : Icons.check_circle_outline_rounded,
                        size: 20,
                        color: diffCount > 0
                            ? DytavaColors.differenceCoral
                            : DytavaColors.exact,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              diffCount > 0
                                  ? 'Phát hiện $diffCount sai khác · Chiếm $diffRateStr'
                                  : 'Dữ liệu trùng khớp hoàn toàn',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: diffCount > 0
                                    ? DytavaColors.different
                                    : DytavaColors.exact,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              diffCount > 0
                                  ? 'Các ô có giá trị không khớp giữa 2 nguồn, cần xem xét và xác minh lại dữ liệu.'
                                  : 'Không phát hiện ô lệch giá trị nào giữa 2 nguồn đối chiếu.',
                              style: DytavaTypography.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (priorityCells.isNotEmpty) ...[
                    const Divider(height: 16),
                    Text(
                      'Các khác biệt cần kiểm tra (${priorityCells.length})',
                      style: DytavaTypography.labelLarge.copyWith(
                        fontWeight: FontWeight.bold,
                        color: DytavaColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    for (var i = 0; i < priorityCells.take(5).length; i++)
                      DytavaFadeSlide(
                        delay: Duration(milliseconds: 140 + i * 35),
                        child: DytavaPriorityDiffCard(
                          cell: priorityCells[i],
                          onQuickBottomSheet: () =>
                              showDytavaCellDetailBottomSheet(
                            context: context,
                            cell: priorityCells[i],
                            onOpenFullDetail: () =>
                                onOpenDetail(priorityCells[i].id),
                          ),
                          onInspectDetail: () =>
                              onOpenDetail(priorityCells[i].id),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Nút CTA xem chi tiết (Pill Lime Primary)
          DytavaFadeSlide(
            delay: const Duration(milliseconds: 250),
            child: DytavaTapScale(
              onTap: () => onResultViewTabChanged(1),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: DytavaColors.limePrimary,
                  foregroundColor: DytavaColors.graphite,
                  shape: const StadiumBorder(),
                  minimumSize: const Size(double.infinity, 44),
                ),
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: const Text(
                  'Xem chi tiết sai khác →',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: () => onResultViewTabChanged(1),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Nút CTA Xuất báo cáo (Secondary)
          DytavaFadeSlide(
            delay: const Duration(milliseconds: 290),
            child: WorkflowPrimaryButton(
              label: 'Xuất / xem trước báo cáo',
              iconAsset: DytavaIcons.export,
              onPressed: onOpenExport,
            ),
          ),
          const SizedBox(height: 10),

          // Bảng đối chiếu đầy đủ & Danh sách ô theo bộ lọc khi cuộn xuống
          DytavaFadeSlide(
            delay: const Duration(milliseconds: 330),
            child: WorkflowSectionCard(
              children: [
                Row(
                  children: [
                    const BrandIcon(DytavaIcons.compareTable, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Xem bảng đối chiếu đầy đủ',
                        style: DytavaTypography.titleMedium.copyWith(
                          color: DytavaColors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Mở bảng cuộn ngang với cột định danh cố định hoặc duyệt theo danh sách ô.',
                  style: DytavaTypography.bodySmall,
                ),
                const SizedBox(height: 8),
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
                const SizedBox(height: 10),
                if (result.alignedRows.isNotEmpty)
                  MobileAlignedGrid(result: result, onOpenCell: onOpenDetail)
                else
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
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          DytavaFadeSlide(
            delay: const Duration(milliseconds: 370),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(44, 44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const BrandIcon(DytavaIcons.play, size: 16),
                label: const Text('Bắt đầu phiên so sánh mới'),
                onPressed: () => flow.navigate(WorkflowScreen.sources),
              ),
            ),
          ),
        ]

        // === TAB 1: CHI TIẾT (Filter Chips & Danh sách toàn bộ các ô diff) ===
        else if (resultViewTab == 1) ...[
          DytavaFadeSlide(
            delay: const Duration(milliseconds: 90),
            child: WorkflowSectionCard(
              children: [
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
                        BrandIllustration.emptyFilter(size: 64),
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
                            vertical: 2,
                          ),
                          leading: BrandIcon.decision(
                            cell.decision.status,
                            size: 20,
                          ),
                          title: Text(
                            '${cell.mapping.fieldA}: ${WorkflowUiHelpers.formatEnumName(cell.decision.status)}',
                            style: DytavaTypography.bodyMedium.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
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
                  'Trang ${flow.page + 1} · ${flow.selectedCells.length} ô trong bộ lọc.',
                  style: DytavaTypography.bodySmall,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(44, 44),
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
                          minimumSize: const Size(44, 44),
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
            ),
          ),
        ]

        // === TAB 2: THEO SHEET (Heatmap Fingerprint & Bảng đối chiếu đầy đủ) ===
        else ...[
          // Bản đồ sai khác Fingerprint
          DytavaFadeSlide(
            delay: const Duration(milliseconds: 90),
            child: DifferenceFingerprint.fromCounts(
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
          ),
          const SizedBox(height: 12),

          // Thống kê cấu trúc riêng (nếu có hàng thêm / bớt)
          if (result.structural.isNotEmpty ||
              result.unresolvedRecords.isNotEmpty)
            DytavaFadeSlide(
              delay: const Duration(milliseconds: 140),
              child: WorkflowSectionCard(
                children: [
                  Row(
                    children: [
                      const BrandIcon(DytavaIcons.rows, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Cấu trúc (thống kê riêng)',
                          style: DytavaTypography.titleMedium.copyWith(
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
                              style: DytavaTypography.bodySmall,
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
                              style: DytavaTypography.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 12),

          // Bảng đối chiếu 2 Sheets
          if (result.alignedRows.isNotEmpty)
            MobileAlignedGrid(result: result, onOpenCell: onOpenDetail)
          else
            DytavaSheetDiffView(
              result: result,
              visibleCells: flow.visibleCells,
              onSelectCell: onOpenDetail,
              sourceALabel: labelA,
              sourceBLabel: labelB,
              sourceAFormat:
                  flow.slot(SourceSide.a).artifact?.format ?? SourceFormat.csv,
              sourceBFormat:
                  flow.slot(SourceSide.b).artifact?.format ?? SourceFormat.csv,
              onExport: onOpenExport,
            ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(44, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const BrandIcon(DytavaIcons.play, size: 16),
              label: const Text('Bắt đầu phiên so sánh mới'),
              onPressed: () => flow.navigate(WorkflowScreen.sources),
            ),
          ),
        ],
      ],
    );
  }
}

/// Custom Donut Chart biểu diễn tỷ lệ trùng khớp Lime Primary v3.2
class _PrecisionDonutChart extends StatelessWidget {
  final double matchRate;
  final double diffRate;
  final double unresolvedRate;
  final String matchPercentText;

  const _PrecisionDonutChart({
    required this.matchRate,
    required this.diffRate,
    required this.unresolvedRate,
    required this.matchPercentText,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 750),
      curve: Curves.easeOutCubic,
      builder: (context, progress, _) {
        final animatedPercent = (matchRate * 100 * progress).toStringAsFixed(1);
        return SizedBox(
          width: 96,
          height: 96,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(96, 96),
                painter: _PrecisionDonutPainter(
                  matchRate: matchRate * progress,
                  diffRate: diffRate * progress,
                  unresolvedRate: unresolvedRate * progress,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    progress >= 0.99 ? matchPercentText : '$animatedPercent%',
                    style: const TextStyle(
                      color: DytavaColors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Inter',
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Trùng khớp',
                    style: TextStyle(
                      color: DytavaColors.warmSurface,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Inter',
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PrecisionDonutPainter extends CustomPainter {
  final double matchRate;
  final double diffRate;
  final double unresolvedRate;

  const _PrecisionDonutPainter({
    required this.matchRate,
    required this.diffRate,
    required this.unresolvedRate,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 12) / 2;
    const strokeWidth = 8.5;

    final trackPaint = Paint()
      ..color = DytavaColors.graphite800
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, trackPaint);

    final total = matchRate + diffRate + unresolvedRate;
    if (total <= 0) return;

    final rect = Rect.fromCircle(center: center, radius: radius);
    var startAngle = -3.141592653589793 / 2;

    final normMatch = matchRate / total;
    final normDiff = diffRate / total;
    final normUnresolved = unresolvedRate / total;

    if (normMatch > 0) {
      final sweepAngle = normMatch * 2 * 3.141592653589793;
      final matchPaint = Paint()
        ..color = DytavaColors.limePrimary
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = strokeWidth;
      canvas.drawArc(rect, startAngle, sweepAngle, false, matchPaint);
      startAngle += sweepAngle;
    }

    if (normDiff > 0) {
      final sweepAngle = normDiff * 2 * 3.141592653589793;
      final diffPaint = Paint()
        ..color = DytavaColors.differenceCoral
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = strokeWidth;
      canvas.drawArc(rect, startAngle, sweepAngle, false, diffPaint);
      startAngle += sweepAngle;
    }

    if (normUnresolved > 0) {
      final sweepAngle = normUnresolved * 2 * 3.141592653589793;
      final unresolvedPaint = Paint()
        ..color = DytavaColors.unresolved
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = strokeWidth;
      canvas.drawArc(rect, startAngle, sweepAngle, false, unresolvedPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _PrecisionDonutPainter oldDelegate) =>
      oldDelegate.matchRate != matchRate ||
      oldDelegate.diffRate != diffRate ||
      oldDelegate.unresolvedRate != unresolvedRate;
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
        DytavaFadeSlide(
          delay: Duration.zero,
          child: Container(
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
        ),

        // Precision Workspace: Focus Diff Card (Single record focused comparison)
        DytavaFadeSlide(
          delay: const Duration(milliseconds: 60),
          child: FocusDiffCard(
            fieldName: '${cell.mapping.fieldA} → ${cell.mapping.fieldB}',
            rowIdentifier: 'Hàng ${cell.rowA} → ${cell.rowB}',
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
        ),
        const SizedBox(height: 14),

        // Thẻ tiêu đề kết luận kèm `BrandIllustration.verdict(...)`
        DytavaFadeSlide(
          delay: const Duration(milliseconds: 120),
          child: WorkflowSectionCard(
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
                          '${cell.mapping.fieldA} → ${cell.mapping.fieldB}',
                          style: DytavaTypography.titleLarge.copyWith(
                            color: DytavaColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${WorkflowUiHelpers.formatEnumName(cell.decision.status)} · Hàng ${cell.rowA} → ${cell.rowB}',
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
        ),

        // Hai giá trị A/B xếp dọc trên điện thoại (< 680dp), 2 cột trên tablet (>= 680dp)
        DytavaFadeSlide(
          delay: const Duration(milliseconds: 180),
          child: LayoutBuilder(
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
        ),

        if (cell.a.rawLexeme != null &&
            cell.b.rawLexeme != null &&
            cell.a.rawLexeme != cell.b.rawLexeme)
          DytavaFadeSlide(
            delay: const Duration(milliseconds: 220),
            child: WorkflowSectionCard(
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
          ),

        DytavaFadeSlide(
          delay: const Duration(milliseconds: 260),
          child: WorkflowSectionCard(
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
        ),
        const SizedBox(height: 8),
        DytavaFadeSlide(
          delay: const Duration(milliseconds: 300),
          child: WorkflowSecondaryButton(
            label: 'Trở về kết quả',
            iconAsset: DytavaIcons.back,
            onPressed: onBackToResults,
          ),
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
                  DytavaToast.success(
                    context,
                    'Đã lưu báo cáo thành công vào thiết bị.',
                    title: 'Lưu báo cáo',
                  );
                }
              } catch (_) {
                if (context.mounted) {
                  DytavaToast.error(
                    context,
                    'Không lưu được báo cáo. Hãy chọn lại vị trí.',
                    title: 'Lỗi lưu tệp',
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
