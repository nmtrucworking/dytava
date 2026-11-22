import 'dart:convert';
import 'dart:typed_data';

import 'package:excelcompare_core/excelcompare_core.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../application/workflow_controller.dart';
import '../../../design_system/design_system.dart';
import '../../../domain/workflow.dart';
import '../../shared/text_difference_evidence.dart';
import '../widgets/mobile_aligned_grid.dart';
import '../widgets/workflow_common_widgets.dart';

enum _ChangeFilter {
  all,
  modified,
  added,
  removed,
  unresolved,
  equivalent,
  same,
}

class ResultsScreenView extends StatefulWidget {
  final WorkflowController flow;
  final int resultViewTab;
  final ValueChanged<int> onResultViewTabChanged;
  final void Function(String cellId) onOpenDetail;
  final VoidCallback onOpenExport;
  final Future<void> Function({String? sheetA, String? sheetB})?
  onSwitchSheetsAndCompare;

  const ResultsScreenView({
    super.key,
    required this.flow,
    required this.resultViewTab,
    required this.onResultViewTabChanged,
    required this.onOpenDetail,
    required this.onOpenExport,
    this.onSwitchSheetsAndCompare,
  });
  @override
  State<ResultsScreenView> createState() => _ResultsScreenViewState();
}

class _ResultsScreenViewState extends State<ResultsScreenView> {
  _ChangeFilter _filter = _ChangeFilter.all;
  int _limit = 30;
  WorkflowController get flow => widget.flow;

  @override
  void initState() {
    super.initState();
    _filter = switch (flow.resultFilter) {
      DecisionStatus.different => _ChangeFilter.modified,
      DecisionStatus.unresolved => _ChangeFilter.unresolved,
      DecisionStatus.equivalent => _ChangeFilter.equivalent,
      DecisionStatus.exact => _ChangeFilter.same,
      null => _ChangeFilter.all,
    };
  }

  void _select(_ChangeFilter value) {
    setState(() {
      _filter = value;
      _limit = 30;
    });
    flow.filterResults(switch (value) {
      _ChangeFilter.modified => DecisionStatus.different,
      _ChangeFilter.unresolved => DecisionStatus.unresolved,
      _ChangeFilter.equivalent => DecisionStatus.equivalent,
      _ChangeFilter.same => DecisionStatus.exact,
      _ => null,
    });
  }

  @override
  Widget build(BuildContext context) {
    final result = flow.displayedResult!;
    final modified = result.count(DecisionStatus.different);
    final added = result.structural
        .where((s) => s.kind.contains('ADDED'))
        .toList();
    final removed = result.structural
        .where((s) => s.kind.contains('REMOVED'))
        .toList();
    final unresolved =
        result.count(DecisionStatus.unresolved) +
        result.unresolvedRecords.length;
    final total = modified + added.length + removed.length;
    final cells = result.cells
        .where(
          (c) => switch (_filter) {
            _ChangeFilter.all || _ChangeFilter.modified =>
              c.decision.status == DecisionStatus.different,
            _ChangeFilter.unresolved =>
              c.decision.status == DecisionStatus.unresolved,
            _ChangeFilter.equivalent =>
              c.decision.status == DecisionStatus.equivalent,
            _ChangeFilter.same => c.decision.status == DecisionStatus.exact,
            _ => false,
          },
        )
        .toList();
    final structural = switch (_filter) {
      _ChangeFilter.all => [...added, ...removed],
      _ChangeFilter.added => added,
      _ChangeFilter.removed => removed,
      _ => <StructuralChange>[],
    };
    final sheets = flow.result!.sheetResults;
    return WorkflowScreenLayout(
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: DytavaColors.primaryDark,
                    borderRadius: BorderRadius.circular(24),
                  ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 166,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: DytavaColors.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'RESULTS READY',
                  style: DytavaTypography.labelSmall.copyWith(
                    fontSize: 10,
                    color: DytavaColors.primaryDark,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '$total differences',
                style: DytavaTypography.displayLarge.copyWith(
                  fontSize: 29,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                children: [
                  Text(
                    '${sheets.isEmpty ? 1 : sheets.length} sheets compared · ${result.cells.length} cells',
                    style: DytavaTypography.bodySmall.copyWith(
                      color: Colors.white,
                    ),
                  ),
                  if (unresolved > 0)
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(48, 32),
                      ),
                      onPressed: () => _select(_ChangeFilter.unresolved),
                      child: Text(
                        '$unresolved unresolved ›',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            for (final item in [
              (
                modified,
                'Modified',
                DytavaColors.modified,
                _ChangeFilter.modified,
              ),
              (
                added.length,
                'Added',
                DytavaColors.primary,
                _ChangeFilter.added,
              ),
              (
                removed.length,
                'Removed',
                DytavaColors.removed,
                _ChangeFilter.removed,
              ),
            ]) ...[
              if (item.$2 != 'Modified') const SizedBox(width: 8),
              Expanded(
                child: Material(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: DytavaColors.border),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => _select(item.$4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DytavaCountUpText(
                            value: item.$1,
                            style: DytavaTypography.metricNumber.copyWith(
                              color: item.$3,
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(item.$2, style: DytavaTypography.bodySmall),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: sheets.isEmpty
                  ? const Text(
                      'All sheets (1)',
                      style: DytavaTypography.titleMedium,
                    )
                  : DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: flow.selectedSheetPairId ?? 'ALL',
                        style: DytavaTypography.titleMedium,
                        items: [
                          DropdownMenuItem(
                            value: 'ALL',
                            child: Text('All sheets (${sheets.length})'),
                          ),
                          for (final sheet in sheets)
                            DropdownMenuItem(
                              value: sheet.sheetPair!.id,
                              child: Text(
                                sheet.sheetPair!.label,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (value) {
                          setState(() => _limit = 30);
                          flow.selectResultSheet(value == 'ALL' ? null : value);
                        },
                      ),
                    ),
            ),
            Flexible(
              child: TextButton(
                onPressed: () => widget.onResultViewTabChanged(
                  widget.resultViewTab == 1 ? 0 : 1,
                ),
                child: Text(
                  widget.resultViewTab == 1 ? 'List view ›' : 'Table view ›',
                  style: const TextStyle(
                    fontSize: 12,
                    color: DytavaColors.textSecondary,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final item in [
                (_ChangeFilter.all, 'All $total'),
                (_ChangeFilter.modified, 'Modified $modified'),
                (_ChangeFilter.added, 'Added ${added.length}'),
                (_ChangeFilter.removed, 'Removed ${removed.length}'),
                (_ChangeFilter.unresolved, 'Unresolved $unresolved'),
                (
                  _ChangeFilter.equivalent,
                  'Equivalent ${result.count(DecisionStatus.equivalent)}',
                ),
                (
                  _ChangeFilter.same,
                  'Same ${result.count(DecisionStatus.exact)}',
                ),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    showCheckmark: false,
                    selected: _filter == item.$1,
                    label: Text(item.$2),
                    onSelected: (_) => _select(item.$1),
                    selectedColor: DytavaColors.primary,
                    backgroundColor: DytavaColors.primaryLight,
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    labelStyle: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _filter == item.$1
                          ? Colors.white
                          : DytavaColors.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (widget.resultViewTab == 1)
          for (final sheet
              in result.sheetResults.isEmpty ? [result] : result.sheetResults)
            WorkflowSectionCard(
              padding: const EdgeInsets.all(8),
              children: [
                if (sheet.sheetPair != null)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      sheet.sheetPair!.label,
                      style: DytavaTypography.titleMedium,
                    ),
                  ),
                MobileAlignedGrid(
                  key: ValueKey(sheet.id),
                  result: sheet,
                  onOpenCell: widget.onOpenDetail,
                ),
              ],
            )
        else ...[
          for (final cell in cells.take(_limit)) _cellCard(cell),
          for (final change in structural.take(
            (_limit - cells.length).clamp(0, _limit),
          ))
            _structuralCard(change),
          if (_filter == _ChangeFilter.unresolved)
            for (final record in result.unresolvedRecords.take(_limit))
              WorkflowSectionCard(
                color: DytavaColors.modifiedBg,
                children: [
                  const Text(
                    'No reliable one-to-one match',
                    style: DytavaTypography.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(record.reason, style: DytavaTypography.bodySmall),
                  Text(
                    'A: ${record.recordsA.join(', ')}\nB: ${record.recordsB.join(', ')}',
                    style: DytavaTypography.bodySmall,
                  ),
                  const Text(
                    'Kept unresolved. No changes are inferred.',
                    style: DytavaTypography.bodySmall,
                  ),
                ],
              ),
          if (cells.isEmpty &&
              structural.isEmpty &&
              !(_filter == _ChangeFilter.unresolved &&
                  result.unresolvedRecords.isNotEmpty))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 36),
              child: Column(
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    color: DytavaColors.primary,
                    size: 40,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _filter == _ChangeFilter.all
                        ? 'No differences found'
                        : 'No changes in this filter',
                    style: DytavaTypography.titleMedium,
                  ),
                  if (unresolved > 0)
                    TextButton(
                      onPressed: () => _select(_ChangeFilter.unresolved),
                      child: Text('Review $unresolved unresolved ›'),
                    ),
                ],
              ),
            ),
          if (cells.length + structural.length > _limit)
            TextButton(
              onPressed: () => setState(() => _limit += 30),
              child: const Text('Show more changes'),
            ),
        ],
        for (final warning in flow.result!.warnings)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(warning, style: DytavaTypography.bodySmall),
          ),
          const SizedBox(height: 16),
        ],
      ),
      bottomBar: StickyBottomBar(
        child: WorkflowPrimaryButton(
          label: 'Export report',
          iconAsset: DytavaIcons.export,
          onPressed: widget.onOpenExport,
        ),
      ),
    );
  }

  Widget _cellCard(CellDifference cell) {
    final status = cell.decision.status;
    final (label, color, bg) = _statusStyle(status);
    return Padding(
      key: ValueKey('change-${cell.id}'),
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: DytavaColors.border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => widget.onOpenDetail(cell.id),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _cellLocation(flow, cell, SourceSide.a),
                        style: DytavaTypography.titleSmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    _badge(label, color, bg),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _value(
                        'Original',
                        cell.a.rawLexeme ?? '—',
                        DytavaColors.background,
                        DytavaColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _value(
                        'Updated',
                        cell.b.rawLexeme ?? '—',
                        bg,
                        color,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _structuralLabel(StructuralChange change) {
    if (!change.kind.startsWith('ROW_')) return change.recordId;
    final info =
        flow.displayedResult?.recordInfo(change.side, change.recordId) ??
        flow.result?.recordInfo(change.side, change.recordId);
    if (info != null) {
      return '${info.$1 ?? 'Sheet'} · Row ${info.$2 + 2}';
    }
    return 'Unpaired row';
  }

  Widget _structuralCard(StructuralChange change) {
    final isAdded = change.kind.contains('ADDED');
    return WorkflowSectionCard(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _structuralLabel(change),
                style: DytavaTypography.titleSmall,
              ),
            ),
            _badge(
              isAdded ? 'Added' : 'Removed',
              isAdded ? DytavaColors.primary : DytavaColors.removed,
              isAdded ? DytavaColors.primaryLight : DytavaColors.removedBg,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '${change.kind.replaceAll('_', ' ').toLowerCase()} · File ${change.side.name.toUpperCase()}',
          style: DytavaTypography.bodySmall,
        ),
      ],
    );
  }
}

final _refPattern = RegExp(r'^(.*)!R(\d+)/');
final _recordRowPattern = RegExp(r'/record-(\d+)/');

String _cellLocation(
  WorkflowController flow,
  CellDifference cell,
  SourceSide side,
) {
  final location = side == SourceSide.a ? cell.locationA : cell.locationB;
  final plan = flow.displayedResult?.planForCell(cell) ??
      flow.result?.planForCell(cell) ??
      flow.result!.plan;
  final source = side == SourceSide.a ? plan.a : plan.b;
  final field = side == SourceSide.a
      ? cell.mapping.fieldA
      : cell.mapping.fieldB;
  var column = source.fields.indexWhere((f) => f.id == field) + 1;
  var letters = '';
  while (column > 0) {
    column--;
    letters = String.fromCharCode(65 + column % 26) + letters;
    column ~/= 26;
  }
  final reference = location == null ? null : _refPattern.firstMatch(location);
  if (reference != null) {
    return '${reference.group(1)} · $letters${reference.group(2)}';
  }
  if (location != null && !location.startsWith('fixture/')) {
    return location.replaceFirst('!', ' · ');
  }
  final row = location == null
      ? null
      : _recordRowPattern.firstMatch(location)?.group(1);
  return row == null
      ? field
      : '${source.sheetName ?? 'Sample'} · $letters${int.parse(row) + 1}';
}

(String, Color, Color) _statusStyle(DecisionStatus status) => switch (status) {
  DecisionStatus.different => (
    'Modified',
    DytavaColors.modified,
    DytavaColors.modifiedBg,
  ),
  DecisionStatus.unresolved => (
    'Unresolved',
    DytavaColors.modified,
    DytavaColors.modifiedBg,
  ),
  DecisionStatus.equivalent => (
    'Equivalent',
    DytavaColors.primary,
    DytavaColors.primaryLight,
  ),
  DecisionStatus.exact => (
    'Same',
    DytavaColors.textSecondary,
    DytavaColors.background,
  ),
};

Widget _badge(String label, Color color, Color bg) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
  decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
  child: Text(
    label,
    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
  ),
);

Widget _value(String label, String value, Color bg, Color color) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
  decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(9)),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: DytavaTypography.bodySmall.copyWith(fontSize: 10)),
      const SizedBox(height: 4),
      Text(
        value,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: DytavaTypography.dataMedium.copyWith(
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    ],
  ),
);

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

  @override
  Widget build(BuildContext context) {
    final cell = flow.result!.cells.firstWhere((c) => c.id == flow.detailId);
    final list = flow.selectedCells;
    final index = list.indexWhere((c) => c.id == cell.id);

    return WorkflowScreenLayout(
      contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // DIFFERENCE X OF Y
          Text(
            'DIFFERENCE ${index < 0 ? 1 : index + 1} OF ${list.isEmpty ? 1 : list.length}',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 8),

          // Change Title
          Text(
            _changeTitle(cell),
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E293B),
              height: 1.2,
            ),
          ),
          const SizedBox(height: 6),

          // Subtitle
          Text(
            _changeSubtitle(cell),
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF64748B),
              height: 1.3,
            ),
          ),
          const SizedBox(height: 20),

          // File & Cell Location
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.grid_on_rounded,
                  color: DytavaColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      flow.slot(SourceSide.a).artifact?.label ?? 'Workbook.xlsx',
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _cellSheetAndAddress(flow, cell, SourceSide.a),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 36, thickness: 1, color: Color(0xFFE2E8F0)),

          // Side-by-side comparison
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: child,
            ),
            child: IntrinsicHeight(
              key: ValueKey('cell-diff-${cell.id}'),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ORIGINAL · A
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ORIGINAL · A',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SelectableText(
                          cell.a.rawLexeme ?? '—',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            const Text(
                              'Normalized: ',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _normalizedLabel(
                                  cell.decision.left,
                                  cell.a.rawLexeme,
                                ),
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontFamily: 'IBM Plex Mono',
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF334155),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const VerticalDivider(
                    width: 32,
                    thickness: 1,
                    color: Color(0xFFE2E8F0),
                  ),
                  // UPDATED · B
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'UPDATED · B',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SelectableText(
                          cell.b.rawLexeme ?? '—',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            const Text(
                              'Normalized: ',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _normalizedLabel(
                                  cell.decision.right,
                                  cell.b.rawLexeme,
                                ),
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontFamily: 'IBM Plex Mono',
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF334155),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 36, thickness: 1, color: Color(0xFFE2E8F0)),

          // Info row
          Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                color: DytavaColors.primary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'Compared as ${_ruleTypeLabel(cell)} values.',
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF1E293B),
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Technical Details collapsible card
          _TechnicalDetailsCard(
            cell: cell,
            flow: flow,
            onBackToResults: onBackToResults,
          ),
          const SizedBox(height: 16),

          // Back to differences subtle button
          Center(
            child: TextButton.icon(
              onPressed: onBackToResults,
              icon: const Icon(
                Icons.arrow_back_rounded,
                size: 16,
                color: DytavaColors.textSecondary,
              ),
              label: const Text(
                'Back to differences',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: DytavaColors.textSecondary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
      bottomBar: StickyBottomBar(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton.icon(
              onPressed: index > 0
                  ? () => onSelectCellId(list[index - 1].id)
                  : null,
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('Previous'),
              style: TextButton.styleFrom(
                foregroundColor: DytavaColors.primary,
                disabledForegroundColor:
                    DytavaColors.textSecondary.withOpacity(0.35),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
            Text(
              '${index < 0 ? 1 : index + 1} / ${list.isEmpty ? 1 : list.length}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF334155),
              ),
            ),
            Directionality(
              textDirection: TextDirection.rtl,
              child: TextButton.icon(
                onPressed: index >= 0 && index < list.length - 1
                    ? () => onSelectCellId(list[index + 1].id)
                    : null,
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: const Text('Next'),
                style: TextButton.styleFrom(
                  foregroundColor: DytavaColors.primary,
                  disabledForegroundColor:
                      DytavaColors.textSecondary.withOpacity(0.35),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _changeTitle(CellDifference cell) {
  final rule = cell.decision.ruleId.toLowerCase();
  String typeName = 'Value';
  if (rule.contains('bool') ||
      _isBooleanString(cell.a.rawLexeme) ||
      _isBooleanString(cell.b.rawLexeme)) {
    typeName = 'Boolean value';
  } else if (rule.contains('dec') || rule.contains('num')) {
    typeName = 'Numeric value';
  } else if (rule.contains('date')) {
    typeName = 'Date value';
  } else if (rule.contains('text')) {
    typeName = 'Text value';
  }

  return switch (cell.decision.status) {
    DecisionStatus.different => '$typeName changed',
    DecisionStatus.equivalent => '$typeName equivalent',
    DecisionStatus.unresolved => '$typeName unresolved',
    DecisionStatus.exact => '$typeName identical',
  };
}

bool _isBooleanString(String? s) {
  if (s == null) return false;
  final l = s.trim().toLowerCase();
  return l == 'true' || l == 'false' || l == 'yes' || l == 'no';
}

String _changeSubtitle(CellDifference cell) {
  return switch (cell.decision.status) {
    DecisionStatus.different => 'The original and updated values are different.',
    DecisionStatus.equivalent =>
      'The values differ in format but have identical meaning.',
    DecisionStatus.unresolved => 'Could not reliably determine equivalence.',
    DecisionStatus.exact =>
      'The original and updated values are exactly identical.',
  };
}

String _cellSheetAndAddress(
  WorkflowController flow,
  CellDifference cell,
  SourceSide side,
) {
  final loc = _cellLocation(flow, cell, side);
  final parts = loc.split(' · ');
  if (parts.length >= 2) {
    return 'Sheet: ${parts[0]}  ·  Cell: ${parts[1]}';
  }
  return 'Cell: $loc';
}

String _normalizedLabel(CanonicalValue? canonical, String? raw) {
  if (canonical != null) return canonical.label;
  if (raw != null) {
    final lower = raw.trim().toLowerCase();
    if (lower == 'no') return 'false';
    if (lower == 'yes') return 'true';
    return raw;
  }
  return '—';
}

String _ruleTypeLabel(CellDifference cell) {
  final rule = cell.decision.ruleId.toLowerCase();
  if (rule.contains('bool') ||
      _isBooleanString(cell.a.rawLexeme) ||
      _isBooleanString(cell.b.rawLexeme)) {
    return 'Boolean';
  }
  if (rule.contains('dec') || rule.contains('num')) {
    return 'Decimal';
  }
  if (rule.contains('date')) {
    return 'Date';
  }
  if (rule.contains('text')) {
    return 'Text';
  }
  return 'Semantic';
}

class _TechnicalDetailsCard extends StatefulWidget {
  final CellDifference cell;
  final WorkflowController flow;
  final VoidCallback onBackToResults;

  const _TechnicalDetailsCard({
    required this.cell,
    required this.flow,
    required this.onBackToResults,
  });

  @override
  State<_TechnicalDetailsCard> createState() => _TechnicalDetailsCardState();
}

class _TechnicalDetailsCardState extends State<_TechnicalDetailsCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDCFCE7), width: 1),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  const Icon(
                    Icons.code_rounded,
                    color: DytavaColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Technical details',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: const Color(0xFF64748B),
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Divider(height: 16, color: Color(0xFFDCFCE7)),
                  _techRow('Rule reference', widget.cell.decision.ruleId),
                  _techRow(
                    'Original cell',
                    _cellLocation(widget.flow, widget.cell, SourceSide.a),
                  ),
                  _techRow(
                    'Updated cell',
                    _cellLocation(widget.flow, widget.cell, SourceSide.b),
                  ),
                  _techRow(
                    'Original normalized',
                    widget.cell.decision.left?.label ?? 'Unresolved',
                  ),
                  _techRow(
                    'Updated normalized',
                    widget.cell.decision.right?.label ?? 'Unresolved',
                  ),
                  _techRow('Matching mode', switch (widget.flow.config.mode) {
                    MatchingMode.positional => 'By position',
                    MatchingMode.key => 'By key column',
                    MatchingMode.orderedSequence => 'Sequence alignment',
                  }),
                  if (widget.cell.a.rawLexeme != null &&
                      widget.cell.b.rawLexeme != null &&
                      widget.cell.a.rawLexeme != widget.cell.b.rawLexeme)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: TextDifferenceEvidence(
                        a: widget.cell.a.rawLexeme!,
                        b: widget.cell.b.rawLexeme!,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _techRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF1E293B),
            ),
          ),
        ),
      ],
    ),
  );
}

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
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: 12),
      const Text('Export report', style: DytavaTypography.displayMedium),
      const SizedBox(height: 10),
      Text(
        'Include ${flow.result!.cells.length} compared cells across the workbook.',
        style: DytavaTypography.bodyMedium,
      ),
      const SizedBox(height: 24),
      RadioGroup<ExportKind>(
        groupValue: exportKind,
        onChanged: (value) {
          if (value != null) onKindChanged(value);
        },
        child: Column(
          children: [
            for (final kind in [ExportKind.csvDiff, ExportKind.jsonReport])
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: RadioListTile<ExportKind>(
                  value: kind,
                  enabled: !flow.busy,
                  tileColor: DytavaColors.background,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  controlAffinity: ListTileControlAffinity.trailing,
                  title: Text(
                    kind == ExportKind.csvDiff ? 'CSV' : 'JSON',
                    style: DytavaTypography.titleSmall,
                  ),
                  subtitle: Text(
                    kind == ExportKind.csvDiff
                        ? 'Flat list of compared cells'
                        : 'Complete comparison report and evidence',
                    style: DytavaTypography.bodySmall,
                  ),
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      DropdownButtonFormField<ExportSelection>(
        isExpanded: true,
        initialValue: selection,
        decoration: const InputDecoration(labelText: 'Report scope'),
        items: const [
          DropdownMenuItem(
            value: ExportSelection.fullComparison,
            child: Text('Full comparison'),
          ),
          DropdownMenuItem(
            value: ExportSelection.differencesOnly,
            child: Text('Differences and unresolved'),
          ),
        ],
        onChanged: flow.busy
            ? null
            : (v) {
                if (v != null) onSelectionChanged(v);
              },
      ),
      const SizedBox(height: 16),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text(
          'Confirm format and report scope',
          style: DytavaTypography.bodyMedium,
        ),
        value: scopeConfirmed,
        onChanged: flow.busy
            ? null
            : (v) => onScopeConfirmedChanged(v ?? false),
      ),
      WorkflowPrimaryButton(
        label: 'Prepare report',
        onPressed:
            scopeConfirmed && flow.exporter.supports(exportKind) && !flow.busy
            ? onRunExportPreview
            : null,
      ),
      if (flow.issue != null) WorkflowIssueList(issues: [flow.issue!]),
      if (flow.exportState?.active == true) ...[
        const SizedBox(height: 12),
        const LinearProgressIndicator(),
        TextButton(
          onPressed: flow.exportState == ExportState.cancelling
              ? null
              : flow.cancelExport,
          child: const Text('Cancel export'),
        ),
      ],
      if (flow.receipt != null) ...[
        const SizedBox(height: 16),
        const Text('Report ready', style: DytavaTypography.titleMedium),
        const SizedBox(height: 12),
        if (flow.receipt!.fileName != null)
          WorkflowPrimaryButton(
            label: 'Save to device',
            iconAsset: DytavaIcons.export,
            onPressed: () => _save(context),
          ),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text(
            'Preview report',
            style: DytavaTypography.titleSmall,
          ),
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240),
              child: SingleChildScrollView(
                child: SelectableText(
                  flow.receipt!.previewText.length > 20000
                      ? '${flow.receipt!.previewText.substring(0, 20000)}\n… Preview limited to 20,000 characters. The saved file includes all data.'
                      : flow.receipt!.previewText,
                  style: DytavaTypography.dataSmall,
                ),
              ),
            ),
          ],
        ),
      ],
      TextButton(
        onPressed: flow.busy ? null : onBackToResults,
        child: const Text('Cancel'),
      ),
    ],
  );

  Future<void> _save(BuildContext context) async {
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
          'Report saved to your device.',
          title: 'Report saved',
        );
      }
    } catch (_) {
      if (context.mounted) {
        DytavaToast.error(
          context,
          'Choose another location and try again.',
          title: 'Unable to save report',
        );
      }
    }
  }
}
