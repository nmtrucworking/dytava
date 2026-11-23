import 'dart:async';
import 'dart:convert';

import 'package:excelcompare_core/excelcompare_core.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    final displayedWarnings = flow.selectedSheetPairId == null
        ? flow.result!.warnings
        : flow.result!.warnings.where((w) {
            final colon = w.indexOf(':');
            if (colon == -1) return true;
            final name = w.substring(0, colon).trim();
            final selectedPair = sheets
                .where((s) => s.sheetPair?.id == flow.selectedSheetPairId)
                .firstOrNull
                ?.sheetPair;
            if (selectedPair == null) return true;
            return name == selectedPair.nameA || name == selectedPair.nameB;
          }).toList();
    final isTableView = widget.resultViewTab == 1;
    final activeTableSheet = sheets.isEmpty
        ? result
        : (flow.selectedSheetPairId != null
              ? sheets.firstWhere(
                  (s) => s.sheetPair?.id == flow.selectedSheetPairId,
                  orElse: () => sheets.first,
                )
              : sheets.first);

    return WorkflowScreenLayout(
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (flow.duplicateSourceFiles)
            Container(
              key: const ValueKey('results-duplicate-file-banner'),
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFED7AA)),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.copy_all_rounded,
                    color: Color(0xFFD97706),
                    size: 22,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Hai tệp A và B hoàn toàn giống nhau.',
                      style: TextStyle(
                        fontFamily: DytavaTypography.primaryFont,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF9A3412),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (!isTableView) ...[
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF0F5B38),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 140,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3.5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E7048),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'RESULTS READY',
                      style: TextStyle(
                        fontFamily: DytavaTypography.primaryFont,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '$total differences',
                    style: const TextStyle(
                      fontFamily: DytavaTypography.primaryFont,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
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
                            minimumSize: const Size(48, 28),
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
            const SizedBox(height: 14),
            Row(
              children: [
                for (final item in [
                  (
                    modified,
                    'Modified',
                    const Color(0xFFB45309),
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
                            horizontal: 10,
                            vertical: 10,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: DytavaCountUpText(
                                  value: item.$1,
                                  style: TextStyle(
                                    fontFamily: DytavaTypography.primaryFont,
                                    color: item.$3,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  item.$2,
                                  style: const TextStyle(
                                    fontFamily: DytavaTypography.primaryFont,
                                    fontSize: 12,
                                    color: Color(0xFF64748B),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
          ],
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
                          value: isTableView
                              ? (activeTableSheet.sheetPair?.id ?? 'ALL')
                              : (flow.selectedSheetPairId ?? 'ALL'),
                          style: DytavaTypography.titleMedium,
                          items: [
                            if (!isTableView)
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
                            flow.selectResultSheet(
                              value == 'ALL' ? null : value,
                            );
                          },
                        ),
                      ),
              ),
              Flexible(
                child: TextButton(
                  onPressed: () {
                    final nextTab = widget.resultViewTab == 1 ? 0 : 1;
                    if (nextTab == 1 &&
                        sheets.isNotEmpty &&
                        flow.selectedSheetPairId == null) {
                      flow.selectResultSheet(sheets.first.sheetPair!.id);
                    }
                    widget.onResultViewTabChanged(nextTab);
                    unawaited(
                      SystemChrome.setPreferredOrientations(
                        nextTab == 1
                            ? const [
                                DeviceOrientation.landscapeLeft,
                                DeviceOrientation.landscapeRight,
                                DeviceOrientation.portraitUp,
                              ]
                            : const [
                                DeviceOrientation.portraitUp,
                                DeviceOrientation.portraitDown,
                                DeviceOrientation.landscapeLeft,
                                DeviceOrientation.landscapeRight,
                              ],
                      ),
                    );
                  },
                  child: Text(
                    isTableView ? 'List view ›' : 'Table view ›',
                    style: const TextStyle(
                      fontSize: 12,
                      color: DytavaColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (!isTableView) ...[
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
                        backgroundColor: const Color(0xFFE8F5E9),
                        side: BorderSide.none,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        labelStyle: TextStyle(
                          fontFamily: DytavaTypography.primaryFont,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _filter == item.$1
                              ? Colors.white
                              : const Color(0xFF334155),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (isTableView)
            MobileAlignedGrid(
              key: ValueKey(activeTableSheet.id),
              result: activeTableSheet,
              onOpenCell: widget.onOpenDetail,
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
        for (final warning in displayedWarnings)
          _warningCard(warning),
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

  List<Uint8List> _findImagesForSheet(String sheetName) {
    final images = <Uint8List>[];
    final seen = <String>{};

    void scanSnapshot(InputSnapshot? snap) {
      if (snap == null) return;
      final sheets =
          snap.workbookSheets.isEmpty ? [snap] : snap.workbookSheets;
      for (final s in sheets) {
        if (s.sheetName == sheetName) {
          for (final r in s.records) {
            for (final c in r.cells.values) {
              if (c.kind == CellKind.image &&
                  c.imageBytes != null &&
                  c.imageBytes!.isNotEmpty) {
                final key = c.imageDigest ?? c.rawLexeme ?? '';
                if (seen.add(key)) {
                  images.add(Uint8List.fromList(c.imageBytes!));
                }
              }
            }
          }
        }
      }
    }

    scanSnapshot(flow.slot(SourceSide.a).snapshot);
    scanSnapshot(flow.slot(SourceSide.b).snapshot);

    if (images.isEmpty && flow.result != null) {
      for (final diff in flow.result!.cells) {
        for (final sideCell in [diff.a, diff.b]) {
          if (sideCell.imagePlacement == 'drawingAnchor' &&
              sideCell.imageBytes != null &&
              sideCell.imageBytes!.isNotEmpty) {
            final locA = diff.locationA ?? '';
            final locB = diff.locationB ?? '';
            if (locA.startsWith('$sheetName!') ||
                locB.startsWith('$sheetName!')) {
              final key = sideCell.imageDigest ?? sideCell.rawLexeme ?? '';
              if (seen.add(key)) {
                images.add(Uint8List.fromList(sideCell.imageBytes!));
              }
            }
          }
        }
      }
    }
    return images;
  }

  Widget _warningCard(String warning) {
    final isImageNotice = warning.contains('ảnh') ||
        warning.contains('đối tượng nổi') ||
        warning.contains('Place over Cells');
    final colonIndex = warning.indexOf(':');
    final String title;
    final String description;
    if (colonIndex != -1) {
      title = warning.substring(0, colonIndex).trim();
      description = warning.substring(colonIndex + 1).trim();
    } else {
      title = isImageNotice ? 'Ảnh / Đối tượng nổi' : 'Thông báo';
      description = warning;
    }

    final images =
        isImageNotice ? _findImagesForSheet(title) : const <Uint8List>[];

    return Padding(
      key: ValueKey('warning-${warning.hashCode}'),
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: DytavaColors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isImageNotice ? Icons.layers_outlined : Icons.info_outline,
                    size: 16,
                    color: isImageNotice
                        ? const Color(0xFFB45309)
                        : DytavaColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: DytavaTypography.titleSmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isImageNotice)
                    _badge(
                      'Place over Cells',
                      const Color(0xFFB45309),
                      const Color(0xFFFEF3C7),
                    )
                  else
                    _badge(
                      'Notice',
                      DytavaColors.primaryDark,
                      DytavaColors.primaryLight,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: DytavaTypography.bodySmall.copyWith(
                  color: DytavaColors.textSecondary,
                ),
              ),
              if (images.isNotEmpty) ...[
                const SizedBox(height: 10),
                for (final img in images)
                  Container(
                    height: 100,
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: DytavaColors.border),
                    ),
                    child: Image.memory(
                      img,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.none,
                    ),
                  ),
              ],
            ],
          ),
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
                        style: const TextStyle(
                          fontFamily: DytavaTypography.primaryFont,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                        ),
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
                        sourceCell: cell.a,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _value(
                        'Updated',
                        cell.b.rawLexeme ?? '—',
                        bg,
                        color,
                        sourceCell: cell.b,
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
      : '${source.sheetName ?? 'Sheet1'} · $letters${int.parse(row) + 1}';
}

(String, Color, Color) _statusStyle(DecisionStatus status) => switch (status) {
  DecisionStatus.different => (
    'Modified',
    const Color(0xFFB45309),
    const Color(0xFFFEF3C7),
  ),
  DecisionStatus.unresolved => (
    'Unresolved',
    const Color(0xFFB45309),
    const Color(0xFFFEF3C7),
  ),
  DecisionStatus.equivalent => (
    'Equivalent',
    DytavaColors.primary,
    const Color(0xFFE8F5E9),
  ),
  DecisionStatus.exact => (
    'Same',
    const Color(0xFF64748B),
    const Color(0xFFF1F5F2),
  ),
};

Widget _badge(String label, Color color, Color bg) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
  decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
  child: Text(
    label,
    style: TextStyle(
      fontFamily: DytavaTypography.primaryFont,
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: color,
    ),
  ),
);

Widget _imagePlacementBadge(SourceCell cell) {
  final isManual = cell.imagePlacement == 'drawingAnchor';
  final label = isManual
      ? 'Ảnh đặt thủ công (Place over Cells)'
      : 'Ảnh trong ô (Place in Cell)';
  final badgeColor =
      isManual ? const Color(0xFFB45309) : const Color(0xFF0369A1);
  final badgeBg =
      isManual ? const Color(0xFFFEF3C7) : const Color(0xFFE0F2FE);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: badgeBg,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isManual ? Icons.layers_outlined : Icons.grid_view_rounded,
          size: 11,
          color: badgeColor,
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: badgeColor,
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _renderedCellImage(
  SourceCell cell, {
  double height = 76,
}) {
  final bytes = cell.imageBytes;
  if (bytes == null || bytes.isEmpty) return const SizedBox.shrink();
  final shortSha = (cell.imageDigest != null && cell.imageDigest!.length >= 8)
      ? cell.imageDigest!.substring(0, 8)
      : (cell.imageDigest ?? '');
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _imagePlacementBadge(cell),
      const SizedBox(height: 6),
      Container(
        height: height,
        width: double.infinity,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: DytavaColors.border),
        ),
        child: Image.memory(
          Uint8List.fromList(bytes),
          fit: BoxFit.contain,
          filterQuality: FilterQuality.none,
          errorBuilder: (_, _, _) => Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.broken_image_outlined,
                  size: 16,
                  color: DytavaColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    'Ảnh (${cell.mediaType ?? "bin"} · ${bytes.length} B)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DytavaTypography.bodySmall.copyWith(fontSize: 10),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      if (shortSha.isNotEmpty) ...[
        const SizedBox(height: 4),
        Text(
          '${(cell.mediaType ?? 'IMG').toUpperCase()} · ${bytes.length} B · SHA $shortSha',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: DytavaTypography.dataSmall.copyWith(
            fontSize: 10,
            color: DytavaColors.textSecondary,
          ),
        ),
      ],
    ],
  );
}

Widget _value(
  String label,
  String value,
  Color bg,
  Color color, {
  SourceCell? sourceCell,
}) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
  decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          fontFamily: DytavaTypography.primaryFont,
          fontSize: 10.5,
          color: Color(0xFF64748B),
          fontWeight: FontWeight.w500,
        ),
      ),
      const SizedBox(height: 3),
      if (sourceCell != null &&
          sourceCell.kind == CellKind.image &&
          sourceCell.imageBytes != null &&
          sourceCell.imageBytes!.isNotEmpty)
        _renderedCellImage(sourceCell, height: 68)
      else
        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: DytavaTypography.primaryFont,
            fontWeight: FontWeight.w700,
            fontSize: 14.5,
            color: color,
          ),
        ),
    ],
  ),
);

String _changeTitle(CellDifference cell) {
  final rule = cell.decision.ruleId.toLowerCase();
  String typeName = 'Value';
  if (cell.a.kind == CellKind.image ||
      cell.b.kind == CellKind.image ||
      rule.contains('image')) {
    typeName = 'Image value';
  } else if (rule.contains('bool') ||
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
  if (cell.a.kind == CellKind.image ||
      cell.b.kind == CellKind.image ||
      rule.contains('image')) {
    return 'Embedded Image (SHA-256 & Binary)';
  }
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

  String _pad2(int n) => n < 10 ? '0$n' : '$n';

  ({String label, bool isNegative})? _calculateNumericDelta(
    String? a,
    String? b,
  ) {
    if (a == null || b == null) return null;
    final numA = num.tryParse(a.replaceAll(',', '').trim());
    final numB = num.tryParse(b.replaceAll(',', '').trim());
    if (numA == null || numB == null) return null;
    final delta = numB - numA;
    final isNeg = delta < 0;
    final deltaStr = delta == 0
        ? '0'
        : (isNeg ? '−' : '+') +
            (delta.abs() % 1 == 0
                ? delta.abs().toInt().toString()
                : delta.abs().toStringAsFixed(2));

    if (numA != 0) {
      final pct = ((delta / numA.abs()) * 100);
      final pctVal = pct.abs() % 1 == 0
          ? pct.abs().toInt().toString()
          : pct.abs().toStringAsFixed(1);
      final pctStr = '${pct >= 0 ? '+' : '−'}$pctVal%';
      return (label: '$deltaStr ($pctStr)', isNegative: isNeg);
    }
    return (label: deltaStr, isNegative: isNeg);
  }

  void _openQuickNav(
    BuildContext context,
    List<CellDifference> list,
    int currentIndex,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _QuickNavBottomSheet(
        list: list,
        currentIndex: currentIndex,
        flow: flow,
        onSelectCellId: (id) {
          Navigator.pop(ctx);
          onSelectCellId(id);
        },
      ),
    );
  }

  void _openComparisonDetailsSheet(BuildContext context, CellDifference cell) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.58,
        minChildSize: 0.35,
        maxChildSize: 0.88,
        expand: false,
        builder: (ctx, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  const Icon(
                    Icons.tune_rounded,
                    color: DytavaColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Comparison details',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _techRow('Rule reference', cell.decision.ruleId),
              _techRow('Comparison type', _ruleTypeLabel(cell)),
              _techRow('Matching mode', switch (flow.config.mode) {
                MatchingMode.positional => 'By position',
                MatchingMode.key => 'By key column',
                MatchingMode.orderedSequence => 'Sequence alignment',
              }),
              if (cell.a.kind == CellKind.image)
                _techRow(
                  'Original image placement',
                  cell.a.imagePlacement == 'drawingAnchor'
                      ? 'Place over Cells (Drawing Anchor)'
                      : 'Place in Cell (RichData)',
                ),
              if (cell.b.kind == CellKind.image)
                _techRow(
                  'Updated image placement',
                  cell.b.imagePlacement == 'drawingAnchor'
                      ? 'Place over Cells (Drawing Anchor)'
                      : 'Place in Cell (RichData)',
                ),
              _techRow(
                'Original source',
                '${flow.slot(SourceSide.a).artifact?.label ?? "File A"} · ${_cellLocation(flow, cell, SourceSide.a)}',
              ),
              _techRow(
                'Updated source',
                '${flow.slot(SourceSide.b).artifact?.label ?? "File B"} · ${_cellLocation(flow, cell, SourceSide.b)}',
              ),
              _techRow(
                'Original normalized',
                cell.decision.left?.label ?? '—',
              ),
              _techRow(
                'Updated normalized',
                cell.decision.right?.label ?? '—',
              ),
              if (cell.a.rawLexeme != null &&
                  cell.b.rawLexeme != null &&
                  cell.a.rawLexeme != cell.b.rawLexeme &&
                  cell.a.kind != CellKind.image &&
                  cell.b.kind != CellKind.image)
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Character difference:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextDifferenceEvidence(
                        a: cell.a.rawLexeme!,
                        b: cell.b.rawLexeme!,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sideValueBox({
    required String label,
    required SourceCell cell,
    required CanonicalValue? canonical,
    required Color accentColor,
    required Color bgColor,
    required Color borderColor,
  }) {
    final norm = _normalizedLabel(canonical, cell.rawLexeme);
    final showNorm =
        norm != '—' && norm.trim() != (cell.rawLexeme ?? '').trim();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: accentColor,
            ),
          ),
          const SizedBox(height: 8),
          if (cell.kind == CellKind.image &&
              cell.imageBytes != null &&
              cell.imageBytes!.isNotEmpty) ...[
            _renderedCellImage(cell, height: 110),
            const SizedBox(height: 6),
          ],
          SelectableText(
            cell.rawLexeme ?? '—',
            style: TextStyle(
              fontSize: cell.kind == CellKind.image ? 12 : 24,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1E293B),
              height: 1.15,
            ),
          ),
          if (showNorm) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: borderColor),
              ),
              child: Text(
                'Norm: $norm',
                style: const TextStyle(
                  fontSize: 11,
                  fontFamily: 'IBM Plex Mono',
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF475569),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cell = flow.result!.cells.firstWhere((c) => c.id == flow.detailId);
    final list = flow.selectedCells;
    final index = list.indexWhere((c) => c.id == cell.id);
    final reviewedPercent = list.isEmpty
        ? 100
        : (((index < 0 ? 0 : index + 1) / list.length) * 100).round();

    final fileA = flow.slot(SourceSide.a).artifact?.label ?? 'File A';
    final fileB = flow.slot(SourceSide.b).artifact?.label ?? 'File B';
    final locA = _cellLocation(flow, cell, SourceSide.a);
    final locB = _cellLocation(flow, cell, SourceSide.b);
    final numDelta = _calculateNumericDelta(
      cell.a.rawLexeme,
      cell.b.rawLexeme,
    );

    return WorkflowScreenLayout(
      contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      content: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity == null) return;
          if (details.primaryVelocity! < -200) {
            // Swipe left -> Next difference
            if (index >= 0 && index < list.length - 1) {
              HapticFeedback.lightImpact();
              onSelectCellId(list[index + 1].id);
            }
          } else if (details.primaryVelocity! > 200) {
            // Swipe right -> Previous difference
            if (index > 0) {
              HapticFeedback.lightImpact();
              onSelectCellId(list[index - 1].id);
            }
          }
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Row: DIFFERENCE 04 / 40 · 10% reviewed
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Flexible(
                  child: InkWell(
                    onTap: () => _openQuickNav(context, list, index),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 2,
                        horizontal: 2,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              'DIFFERENCE ${_pad2(index < 0 ? 1 : index + 1)} / ${_pad2(list.isEmpty ? 1 : list.length)}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                                color: Color(0xFF64748B),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.unfold_more_rounded,
                            size: 14,
                            color: Color(0xFF64748B),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$reviewedPercent% reviewed',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: DytavaColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

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
            const SizedBox(height: 8),

            // File & Location source strip (e.g. Combined!D4 → sheet4!D4)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.description_outlined,
                        size: 13,
                        color: Color(0xFF64748B),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          fileA == fileB ? fileA : '$fileA  ↔  $fileB',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF475569),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.pin_drop_outlined,
                        size: 13,
                        color: DytavaColors.primary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          locA == locB ? locA : '$locA  →  $locB',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontFamily: 'IBM Plex Mono',
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E293B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Value comparison boxes: ORIGINAL · A vs UPDATED · B
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
                      child: _sideValueBox(
                        label: 'ORIGINAL · A',
                        cell: cell.a,
                        canonical: cell.decision.left,
                        accentColor: const Color(0xFF64748B),
                        bgColor: const Color(0xFFF8FAFC),
                        borderColor: const Color(0xFFE2E8F0),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // UPDATED · B
                    Expanded(
                      child: _sideValueBox(
                        label: 'UPDATED · B',
                        cell: cell.b,
                        canonical: cell.decision.right,
                        accentColor: DytavaColors.primary,
                        bgColor: const Color(0xFFF0FDF4),
                        borderColor: const Color(0xFFBBF7D0),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Numeric difference delta if both are numeric
            if (numDelta != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: numDelta.isNegative
                      ? const Color(0xFFFEF2F2)
                      : const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: numDelta.isNegative
                        ? const Color(0xFFFECACA)
                        : const Color(0xFFBBF7D0),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      numDelta.isNegative
                          ? Icons.trending_down_rounded
                          : Icons.trending_up_rounded,
                      size: 16,
                      color: numDelta.isNegative
                          ? const Color(0xFFDC2626)
                          : const Color(0xFF16A34A),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Numeric difference: ${numDelta.label}',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: numDelta.isNegative
                              ? const Color(0xFFDC2626)
                              : const Color(0xFF16A34A),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Comparison details button
            Center(
              child: OutlinedButton.icon(
                onPressed: () => _openComparisonDetailsSheet(context, cell),
                icon: const Icon(Icons.tune_rounded, size: 16),
                label: const Text('Comparison details'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF334155),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  minimumSize: const Size(0, 42),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Back to differences subtle link
            Center(
              child: TextButton.icon(
                onPressed: onBackToResults,
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  size: 15,
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
            const SizedBox(height: 12),
          ],
        ),
      ),
      bottomBar: StickyBottomBar(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: index > 0
                  ? () => onSelectCellId(list[index - 1].id)
                  : null,
              style: TextButton.styleFrom(
                minimumSize: const Size(44, 44),
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 6,
                ),
                foregroundColor: DytavaColors.primary,
                disabledForegroundColor:
                    DytavaColors.textSecondary.withValues(alpha: 0.35),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_back_rounded, size: 16),
                  SizedBox(width: 4),
                  Text('Previous'),
                ],
              ),
            ),
            Flexible(
              child: InkWell(
                onTap: () => _openQuickNav(context, list, index),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${index < 0 ? 1 : index + 1} / ${list.isEmpty ? 1 : list.length}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(
                        Icons.unfold_more_rounded,
                        size: 14,
                        color: Color(0xFF64748B),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            TextButton(
              onPressed: index >= 0 && index < list.length - 1
                  ? () => onSelectCellId(list[index + 1].id)
                  : null,
              style: TextButton.styleFrom(
                minimumSize: const Size(44, 44),
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 6,
                ),
                foregroundColor: DytavaColors.primary,
                disabledForegroundColor:
                    DytavaColors.textSecondary.withValues(alpha: 0.35),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Next'),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward_rounded, size: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickNavBottomSheet extends StatefulWidget {
  final List<CellDifference> list;
  final int currentIndex;
  final WorkflowController flow;
  final ValueChanged<String> onSelectCellId;

  const _QuickNavBottomSheet({
    required this.list,
    required this.currentIndex,
    required this.flow,
    required this.onSelectCellId,
  });

  @override
  State<_QuickNavBottomSheet> createState() => _QuickNavBottomSheetState();
}

class _QuickNavBottomSheetState extends State<_QuickNavBottomSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = _query.isEmpty
        ? widget.list
        : widget.list.where((c) {
            final q = _query.toLowerCase();
            final locA =
                _cellLocation(widget.flow, c, SourceSide.a).toLowerCase();
            final locB =
                _cellLocation(widget.flow, c, SourceSide.b).toLowerCase();
            final valA = (c.a.rawLexeme ?? '').toLowerCase();
            final valB = (c.b.rawLexeme ?? '').toLowerCase();
            final title = _changeTitle(c).toLowerCase();
            return locA.contains(q) ||
                locB.contains(q) ||
                valA.contains(q) ||
                valB.contains(q) ||
                title.contains(q);
          }).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (ctx, scrollController) => Column(
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Text(
                  'Jump to difference',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const Spacer(),
                Text(
                  '${widget.list.length} total',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search cell, sheet, or value...',
                hintStyle: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF94A3B8),
                ),
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.separated(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              itemCount: filtered.length,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
              itemBuilder: (ctx, i) {
                final item = filtered[i];
                final originalIndex = widget.list.indexOf(item);
                final isSelected = originalIndex == widget.currentIndex;
                final locA = _cellLocation(widget.flow, item, SourceSide.a);

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  selected: isSelected,
                  selectedTileColor: DytavaColors.primaryLight,
                  leading: Text(
                    '#${originalIndex + 1}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? DytavaColors.primary
                          : const Color(0xFF64748B),
                    ),
                  ),
                  title: Text(
                    locA,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? DytavaColors.primaryDark
                          : const Color(0xFF1E293B),
                    ),
                  ),
                  subtitle: Text(
                    '${item.a.rawLexeme ?? "—"} → ${item.b.rawLexeme ?? "—"}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: isSelected
                      ? const Icon(
                          Icons.check_circle_rounded,
                          color: DytavaColors.primary,
                          size: 18,
                        )
                      : const Icon(
                          Icons.chevron_right_rounded,
                          color: Color(0xFF94A3B8),
                          size: 18,
                        ),
                  onTap: () => widget.onSelectCellId(item.id),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

Widget _techRow(String label, String value) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 5),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 125,
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: Color(0xFF64748B),
          ),
        ),
      ),
      Expanded(
        child: Text(
          value,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E293B),
          ),
        ),
      ),
    ],
  ),
);

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
