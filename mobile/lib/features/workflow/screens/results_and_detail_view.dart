import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

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
import '../../../l10n/app_localizations.dart';

enum _ChangeFilter {
  all,
  modified,
  added,
  removed,
  unresolved,
  equivalent,
  same,
}

enum DiffCategory { modified, added, removed, unresolved, equivalent, same }

sealed class DifferenceDisplayItem {}

class CellDifferenceItem extends DifferenceDisplayItem {
  final CellDifference cell;
  final DiffCategory category;
  CellDifferenceItem(this.cell, this.category);
}

class StructuralDifferenceItem extends DifferenceDisplayItem {
  final StructuralChange change;
  final DiffCategory category;
  StructuralDifferenceItem(this.change, this.category);
}

class UnresolvedRecordItem extends DifferenceDisplayItem {
  final RecordUnresolved record;
  UnresolvedRecordItem(this.record);
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
  int _currentPage = 1;
  static const int _pageSize = 5;
  final GlobalKey _cardsSectionKey = GlobalKey();

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

  bool _autoFocusingScroll = false;

  void _scrollToCards() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = _cardsSectionKey.currentContext;
      if (ctx != null) {
        _autoFocusingScroll = true;
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          alignment: 0.0,
        ).whenComplete(() {
          _autoFocusingScroll = false;
        });
      }
    });
  }

  bool _onScrollEnd(ScrollEndNotification notification) {
    if (_autoFocusingScroll || widget.resultViewTab == 1) return false;
    if (MediaQuery.maybeOf(context)?.disableAnimations == true) return false;
    final metrics = notification.metrics;
    if (metrics.axis != Axis.vertical) return false;
    // When user scrolls down from the top header into the transition area,
    // auto-focus onto the difference cards section so the page fits the screen.
    if (metrics.pixels >= 48 && metrics.pixels <= 190 && metrics.maxScrollExtent > 190) {
      _scrollToCards();
    }
    return false;
  }

  void _goToPage(int page) {
    setState(() {
      _currentPage = page;
    });
    _scrollToCards();
  }

  void _select(_ChangeFilter value) {
    setState(() {
      _filter = value;
      _currentPage = 1;
    });
    flow.filterResults(switch (value) {
      _ChangeFilter.modified => DecisionStatus.different,
      _ChangeFilter.unresolved => DecisionStatus.unresolved,
      _ChangeFilter.equivalent => DecisionStatus.equivalent,
      _ChangeFilter.same => DecisionStatus.exact,
      _ => null,
    });
    _scrollToCards();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final result = flow.displayedResult!;

    // Classify all cells into Added, Removed, Modified, etc., while preserving
    // natural worksheet order in [allCellItems] so Sheet 1 (e.g. Planned) stays first.
    final allCellItems = <CellDifferenceItem>[];
    final modifiedCells = <CellDifference>[];
    final addedCells = <CellDifference>[];
    final removedCells = <CellDifference>[];
    final unresolvedCells = <CellDifference>[];
    final equivalentCells = <CellDifference>[];
    final exactCells = <CellDifference>[];

    for (final cell in result.cells) {
      if (cell.decision.status == DecisionStatus.unresolved) {
        unresolvedCells.add(cell);
      } else if (cell.decision.status == DecisionStatus.equivalent) {
        equivalentCells.add(cell);
      } else if (cell.decision.status == DecisionStatus.exact) {
        exactCells.add(cell);
      } else {
        final aEmpty = _isCellEmpty(cell.a);
        final bEmpty = _isCellEmpty(cell.b);
        if (aEmpty && !bEmpty) {
          addedCells.add(cell);
          allCellItems.add(CellDifferenceItem(cell, DiffCategory.added));
        } else if (!aEmpty && bEmpty) {
          removedCells.add(cell);
          allCellItems.add(CellDifferenceItem(cell, DiffCategory.removed));
        } else {
          modifiedCells.add(cell);
          allCellItems.add(CellDifferenceItem(cell, DiffCategory.modified));
        }
      }
    }

    final addedStructural = result.structural
        .where((s) => s.kind.contains('ADDED'))
        .toList();
    final removedStructural = result.structural
        .where((s) => s.kind.contains('REMOVED'))
        .toList();

    final modifiedCount = modifiedCells.length;
    final addedCount = addedCells.length + addedStructural.length;
    final removedCount = removedCells.length + removedStructural.length;
    final unresolvedCount = unresolvedCells.length +
        result.count(DecisionStatus.unresolved) +
        result.unresolvedRecords.length;
    final total = modifiedCount + addedCount + removedCount;

    // Filter items based on selected category
    final List<DifferenceDisplayItem> items = switch (_filter) {
      _ChangeFilter.all => [
        ...allCellItems,
        for (final s in addedStructural) StructuralDifferenceItem(s, DiffCategory.added),
        for (final s in removedStructural) StructuralDifferenceItem(s, DiffCategory.removed),
        for (final c in unresolvedCells) CellDifferenceItem(c, DiffCategory.unresolved),
      ],
      _ChangeFilter.modified => [
        for (final c in modifiedCells) CellDifferenceItem(c, DiffCategory.modified),
      ],
      _ChangeFilter.added => [
        for (final c in addedCells) CellDifferenceItem(c, DiffCategory.added),
        for (final s in addedStructural) StructuralDifferenceItem(s, DiffCategory.added),
      ],
      _ChangeFilter.removed => [
        for (final c in removedCells) CellDifferenceItem(c, DiffCategory.removed),
        for (final s in removedStructural) StructuralDifferenceItem(s, DiffCategory.removed),
      ],
      _ChangeFilter.unresolved => [
        for (final c in unresolvedCells) CellDifferenceItem(c, DiffCategory.unresolved),
        for (final r in result.unresolvedRecords) UnresolvedRecordItem(r),
      ],
      _ChangeFilter.equivalent => [
        for (final c in equivalentCells) CellDifferenceItem(c, DiffCategory.equivalent),
      ],
      _ChangeFilter.same => [
        for (final c in exactCells) CellDifferenceItem(c, DiffCategory.same),
      ],
    };

    final totalItems = items.length;
    final totalPages = (totalItems / _pageSize).ceil().clamp(1, 999999);
    final safePage = _currentPage.clamp(1, totalPages);
    final pagedItems = items.skip((safePage - 1) * _pageSize).take(_pageSize).toList();

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

    return NotificationListener<ScrollEndNotification>(
      onNotification: _onScrollEnd,
      child: WorkflowScreenLayout(
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
              child: Row(
                children: [
                  const Icon(
                    Icons.copy_all_rounded,
                    color: Color(0xFFD97706),
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.identicalFilesTitle,
                      style: const TextStyle(
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
            DytavaFadeSlide.staggered(
              index: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0E5332), Color(0xFF1A6E45)],
                    begin: Alignment.bottomLeft,
                    end: Alignment.topRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F5B38).withValues(alpha: 0.20),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF14633C),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              l10n.resultsReadyUpper,
                              style: const TextStyle(
                                fontFamily: DytavaTypography.primaryFont,
                                fontSize: 8.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              l10n.totalDifferencesCount(total),
                              style: const TextStyle(
                                fontFamily: DytavaTypography.primaryFont,
                                fontSize: 22,
                                height: 1.1,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          if (unresolvedCount > 0) ...[
                            const SizedBox(height: 5),
                            InkWell(
                              onTap: () => _select(_ChangeFilter.unresolved),
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  l10n.reviewUnresolvedCount(unresolvedCount),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontFamily: DytavaTypography.primaryFont,
                                    fontSize: 10.5,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              const Icon(
                                Icons.description_outlined,
                                size: 13,
                                color: Colors.white70,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  l10n.isVietnamese
                                      ? '${sheets.isEmpty ? 1 : sheets.length} sheet đã so sánh'
                                      : '${sheets.isEmpty ? 1 : sheets.length} sheets compared',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontFamily: DytavaTypography.primaryFont,
                                    fontSize: 11.5,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l10n.isVietnamese
                                ? '${result.cells.length} ô'
                                : '${result.cells.length} cells',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: DytavaTypography.primaryFont,
                              fontSize: 11.5,
                              color: Colors.white.withValues(alpha: 0.88),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            DytavaFadeSlide.staggered(
              index: 1,
              child: Row(
                children: [
                for (final item in [
                  (
                    modifiedCount,
                    l10n.modifiedFilter,
                    const Color(0xFF92400E),
                    _ChangeFilter.modified,
                  ),
                  (
                    addedCount,
                    l10n.addedFilter,
                    const Color(0xFF0E7A3E),
                    _ChangeFilter.added,
                  ),
                  (
                    removedCount,
                    l10n.deletedFilter,
                    const Color(0xFFB93829),
                    _ChangeFilter.removed,
                  ),
                ]) ...[
                  if (item.$4 != _ChangeFilter.modified) const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFFFFF), Color(0xFFF7FBF8)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2EAE4)),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x04000000),
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Material(
                        type: MaterialType.transparency,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => _select(item.$4),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: DytavaCountUpText(
                                      value: item.$1,
                                      style: TextStyle(
                                        fontFamily: DytavaTypography.primaryFont,
                                        color: item.$3,
                                        fontSize: 20,
                                        height: 1.05,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      item.$2,
                                      style: const TextStyle(
                                        fontFamily: DytavaTypography.primaryFont,
                                        fontSize: 11,
                                        color: Color(0xFF64748B),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            ),
            const SizedBox(height: 10),
          ],
          Container(
            key: _cardsSectionKey,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: sheets.isEmpty
                      ? Text(
                          l10n.allSheetsCount(1),
                          style: DytavaTypography.titleMedium,
                        )
                      : ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 195),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              isDense: true,
                              value: isTableView
                                  ? (activeTableSheet.sheetPair?.id ?? 'ALL')
                                  : (flow.selectedSheetPairId ?? 'ALL'),
                              style: DytavaTypography.titleMedium,
                              icon: const Icon(
                                Icons.arrow_drop_down_rounded,
                                color: Color(0xFF1E293B),
                                size: 22,
                              ),
                              items: [
                                if (!isTableView)
                                  DropdownMenuItem(
                                    value: 'ALL',
                                    child: Text(
                                      l10n.allSheetsCount(sheets.length),
                                      overflow: TextOverflow.ellipsis,
                                    ),
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
                                setState(() => _currentPage = 1);
                                flow.selectResultSheet(
                                  value == 'ALL' ? null : value,
                                );
                                _scrollToCards();
                              },
                            ),
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
                      isTableView ? l10n.listViewToggle : l10n.tableViewToggle,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: DytavaColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (!isTableView) ...[
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final item in [
                    (_ChangeFilter.all, '${l10n.all} $total'),
                    (_ChangeFilter.modified, '${l10n.modifiedFilter} $modifiedCount'),
                    (_ChangeFilter.added, '${l10n.addedFilter} $addedCount'),
                    (_ChangeFilter.removed, '${l10n.deletedFilter} $removedCount'),
                    (_ChangeFilter.unresolved, '${l10n.needsReviewVerdict} $unresolvedCount'),
                    (
                      _ChangeFilter.equivalent,
                      '${l10n.isVietnamese ? "Tương đương" : "Equivalent"} ${equivalentCells.length}',
                    ),
                    (
                      _ChangeFilter.same,
                      '${l10n.matchingVerdict} ${exactCells.length}',
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
                        backgroundColor: const Color(0xFFE6F0EA),
                        side: BorderSide.none,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        labelStyle: TextStyle(
                          fontFamily: DytavaTypography.primaryFont,
                          fontSize: 12.5,
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
            for (final item in pagedItems)
              switch (item) {
                CellDifferenceItem(:final cell, :final category) =>
                  _cellCard(cell, category),
                StructuralDifferenceItem(:final change, :final category) =>
                  _structuralCard(change, category),
                UnresolvedRecordItem(:final record) =>
                  WorkflowSectionCard(
                    color: DytavaColors.modifiedBg,
                    children: [
                      Text(
                        l10n.noReliableMatch,
                        style: DytavaTypography.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(record.reason, style: DytavaTypography.bodySmall),
                      Text(
                        'A: ${record.recordsA.join(', ')}\nB: ${record.recordsB.join(', ')}',
                        style: DytavaTypography.bodySmall,
                      ),
                      Text(
                        l10n.keptUnresolvedNotice,
                        style: DytavaTypography.bodySmall,
                      ),
                    ],
                  ),
              },
            if (items.isEmpty)
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
                          ? l10n.noDifferencesFound
                          : l10n.noChangesInFilter,
                      style: DytavaTypography.titleMedium,
                    ),
                    if (unresolvedCount > 0)
                      TextButton(
                        onPressed: () => _select(_ChangeFilter.unresolved),
                        child: Text(l10n.reviewUnresolvedCount(unresolvedCount)),
                      ),
                  ],
                ),
              ),
            for (final warning in displayedWarnings)
              _warningCard(warning),
            _buildPaginationBar(totalItems, totalPages),
          ],
          if (isTableView)
            for (final warning in displayedWarnings)
              _warningCard(warning),
          const SizedBox(height: 12),
        ],
      ),
      bottomBar: StickyBottomBar(
        child: WorkflowPrimaryButton(
          label: l10n.exportReport,
          iconAsset: DytavaIcons.export,
          onPressed: widget.onOpenExport,
        ),
      ),
    ),
    );
  }

  List<Uint8List> _findImagesForSheet(String sheetName) {
    final images = <Uint8List>[];
    final seen = <String>{};

    void scanSnapshot(InputSnapshot? snap, {required bool drawingOnly}) {
      if (snap == null) return;
      final sheets =
          snap.workbookSheets.isEmpty ? [snap] : snap.workbookSheets;
      for (final s in sheets) {
        if (s.sheetName == sheetName) {
          for (final r in s.records) {
            for (final c in r.cells.values) {
              if (c.kind == CellKind.image &&
                  (!drawingOnly || c.imagePlacement == 'drawingAnchor') &&
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

    // Prefer Place over Cells (drawingAnchor) images for this sheet
    scanSnapshot(flow.slot(SourceSide.a).snapshot, drawingOnly: true);
    scanSnapshot(flow.slot(SourceSide.b).snapshot, drawingOnly: true);

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
    final l10n = context.l10n;
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
      title = isImageNotice
          ? (l10n.isVietnamese ? 'Ảnh / Đối tượng nổi' : 'Image / Floating object')
          : (l10n.isVietnamese ? 'Thông báo' : 'Notice');
      description = warning;
    }

    final images =
        isImageNotice ? _findImagesForSheet(title) : const <Uint8List>[];

    return Padding(
      key: ValueKey('warning-${warning.hashCode}'),
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFCF5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFDE68A)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  isImageNotice ? Icons.layers_outlined : Icons.info_outline,
                  size: 14,
                  color: isImageNotice
                      ? const Color(0xFFB45309)
                      : DytavaColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontFamily: DytavaTypography.primaryFont,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isImageNotice)
                  _badge(
                    l10n.placeOverCellsBadge,
                    const Color(0xFFB45309),
                    const Color(0xFFFEF3C7),
                  )
                else
                  _badge(
                    l10n.isVietnamese ? 'Thông báo' : 'Notice',
                    DytavaColors.primaryDark,
                    DytavaColors.primaryLight,
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              description,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: DytavaTypography.primaryFont,
                fontSize: 11.5,
                color: Color(0xFF64748B),
              ),
            ),
            if (images.isNotEmpty) ...[
              const SizedBox(height: 6),
              SizedBox(
                height: 48,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: images.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, idx) => Container(
                    width: 88,
                    height: 48,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Image.memory(
                      images[idx],
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.none,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPaginationBar(int totalItems, int totalPages) {
    if (totalItems <= _pageSize) return const SizedBox.shrink();
    final l10n = context.l10n;
    final safePage = _currentPage.clamp(1, totalPages);

    // Compute visible page window (up to 5 page buttons)
    const maxButtons = 5;
    int startPage = (safePage - 2).clamp(1, totalPages);
    int endPage = (startPage + maxButtons - 1).clamp(1, totalPages);
    if (endPage - startPage + 1 < maxButtons) {
      startPage = (endPage - maxButtons + 1).clamp(1, totalPages);
    }

    final startItem = (safePage - 1) * _pageSize + 1;
    final endItem = (safePage * _pageSize).clamp(1, totalItems);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  key: const ValueKey('results-prev-page'),
                  icon: const Icon(Icons.chevron_left_rounded, size: 22),
                  onPressed: safePage > 1 ? () => _goToPage(safePage - 1) : null,
                  tooltip: l10n.previousPage,
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 2),
                for (int p = startPage; p <= endPage; p++) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: InkWell(
                      key: ValueKey('results-page-$p'),
                      borderRadius: BorderRadius.circular(10),
                      onTap: p == safePage ? null : () => _goToPage(p),
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: p == safePage
                              ? DytavaColors.primary
                              : const Color(0xFFE8F2EC),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$p',
                          style: TextStyle(
                            fontFamily: DytavaTypography.primaryFont,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: p == safePage
                                ? Colors.white
                                : const Color(0xFF334155),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 2),
                IconButton(
                  key: const ValueKey('results-next-page'),
                  icon: const Icon(Icons.chevron_right_rounded, size: 22),
                  onPressed: safePage < totalPages ? () => _goToPage(safePage + 1) : null,
                  tooltip: l10n.nextPage,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.isVietnamese
                ? 'Hiển thị $startItem–$endItem / $totalItems thay đổi · Trang $safePage/$totalPages'
                : 'Showing $startItem–$endItem of $totalItems · Page $safePage of $totalPages',
            style: const TextStyle(
              fontFamily: DytavaTypography.primaryFont,
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cellCard(CellDifference cell, DiffCategory category) {
    final l10n = context.l10n;
    final (label, color, bg) = switch (category) {
      DiffCategory.added => (
        l10n.isVietnamese ? 'Thêm mới' : 'Added',
        const Color(0xFF15803D),
        const Color(0xFFE6F2EA),
      ),
      DiffCategory.removed => (
        l10n.isVietnamese ? 'Đã xóa' : 'Removed',
        const Color(0xFFB93829),
        const Color(0xFFFBE9E7),
      ),
      DiffCategory.modified => (
        l10n.isVietnamese ? 'Đã sửa' : 'Modified',
        const Color(0xFF8D5411),
        const Color(0xFFFBF0D9),
      ),
      DiffCategory.unresolved => (
        l10n.isVietnamese ? 'Cần xem xét' : 'Unresolved',
        const Color(0xFF8D5411),
        const Color(0xFFFBF0D9),
      ),
      DiffCategory.equivalent => (
        l10n.isVietnamese ? 'Tương đương' : 'Equivalent',
        DytavaColors.primary,
        const Color(0xFFE8F5E9),
      ),
      DiffCategory.same => (
        l10n.isVietnamese ? 'Trùng khớp' : 'Same',
        const Color(0xFF64748B),
        const Color(0xFFF1F5F2),
      ),
    };

    return Padding(
      key: ValueKey('change-${cell.id}'),
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2EAE4)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x05000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => widget.onOpenDetail(cell.id),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _cellLocation(flow, cell, SourceSide.a),
                          style: const TextStyle(
                            fontFamily: DytavaTypography.primaryFont,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      _badge(label, color, bg),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildCellCardBody(cell, category),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCellCardBody(CellDifference cell, DiffCategory category) {
    final l10n = context.l10n;
    final isAImage = cell.a.kind == CellKind.image &&
        cell.a.imageBytes != null &&
        cell.a.imageBytes!.isNotEmpty;
    final isBImage = cell.b.kind == CellKind.image &&
        cell.b.imageBytes != null &&
        cell.b.imageBytes!.isNotEmpty;

    // Requirement 2a: ADDED -> ONLY show Updated box (original is omitted)
    if (category == DiffCategory.added) {
      return _singleValueBox(
        label: l10n.isVietnamese ? 'Cập nhật' : 'Updated',
        labelColor: const Color(0xFF5B7065),
        bg: const Color(0xFFE8F2EC),
        child: isBImage
            ? _renderedCellImage(cell.b, height: 68)
            : Text(
                cell.b.rawLexeme ?? '',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: DytavaTypography.primaryFont,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: Color(0xFF15803D),
                ),
              ),
      );
    }

    // REMOVED -> show Original and Updated with red dash
    if (category == DiffCategory.removed) {
      return Row(
        children: [
          Expanded(
            child: _value(
              l10n.isVietnamese ? 'Gốc' : 'Original',
              cell.a.rawLexeme ?? '—',
              const Color(0xFFF3F5F4),
              const Color(0xFF1E293B),
              sourceCell: cell.a,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _singleValueBox(
              label: l10n.isVietnamese ? 'Cập nhật' : 'Updated',
              labelColor: const Color(0xFF64748B),
              bg: const Color(0xFFFCECEB),
              child: const Text(
                '—',
                style: TextStyle(
                  fontFamily: DytavaTypography.primaryFont,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: Color(0xFFB93829),
                ),
              ),
            ),
          ),
        ],
      );
    }

    // MODIFIED / other
    if (isAImage || isBImage) {
      return Row(
        children: [
          Expanded(
            child: _value(
              l10n.isVietnamese ? 'Gốc' : 'Original',
              cell.a.rawLexeme ?? '—',
              const Color(0xFFF3F5F4),
              const Color(0xFF1E293B),
              sourceCell: cell.a,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _value(
              l10n.isVietnamese ? 'Cập nhật' : 'Updated',
              cell.b.rawLexeme ?? '—',
              const Color(0xFFFDF3DC),
              const Color(0xFF8D5411),
              sourceCell: cell.b,
            ),
          ),
        ],
      );
    }

    final rawA = cell.a.rawLexeme ?? '';
    final rawB = cell.b.rawLexeme ?? '';

    // Requirement 2b: Numeric or similar atomic types -> render original and updated side-by-side
    if (_isNumericOrAtomic(rawA, rawB)) {
      return Row(
        children: [
          Expanded(
            child: _value(
              l10n.isVietnamese ? 'Gốc' : 'Original',
              rawA.isEmpty ? '—' : rawA,
              const Color(0xFFF3F5F4),
              const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _value(
              l10n.isVietnamese ? 'Cập nhật' : 'Updated',
              rawB.isEmpty ? '—' : rawB,
              const Color(0xFFFDF3DC),
              const Color(0xFF8D5411),
            ),
          ),
        ],
      );
    }

    // Requirement 2b: Text editing -> single Updated box with inline diff:
    // Italicized content, red strikethrough old content, green new content,
    // prioritizing changed points, multiple change points separated by "|".
    return _singleValueBox(
      label: l10n.isVietnamese ? 'Cập nhật' : 'Updated',
      labelColor: const Color(0xFF64748B),
      bg: const Color(0xFFFDF3DC),
      child: _buildInlineTextDiff(rawA, rawB),
    );
  }

  String _structuralLabel(StructuralChange change) {
    final l10n = context.l10n;
    if (!change.kind.startsWith('ROW_')) return change.recordId;
    final info =
        flow.displayedResult?.recordInfo(change.side, change.recordId) ??
        flow.result?.recordInfo(change.side, change.recordId);
    if (info != null) {
      return '${info.$1 ?? l10n.sheet} · ${l10n.isVietnamese ? "Hàng" : "Row"} ${info.$2 + 2}';
    }
    return l10n.unpairedRow;
  }

  Widget _structuralCard(StructuralChange change, DiffCategory category) {
    final l10n = context.l10n;
    final isAdded = category == DiffCategory.added;
    final (label, color, bg) = isAdded
        ? (
            l10n.isVietnamese ? 'Thêm mới' : 'Added',
            const Color(0xFF15803D),
            const Color(0xFFE6F2EA),
          )
        : (
            l10n.isVietnamese ? 'Đã xóa' : 'Removed',
            const Color(0xFFB93829),
            const Color(0xFFFBE9E7),
          );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2EAE4)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x05000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _structuralLabel(change),
                      style: const TextStyle(
                        fontFamily: DytavaTypography.primaryFont,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _badge(label, color, bg),
                ],
              ),
              const SizedBox(height: 12),
              if (isAdded)
                _singleValueBox(
                  label: l10n.isVietnamese ? 'Cập nhật' : 'Updated',
                  labelColor: const Color(0xFF5B7065),
                  bg: const Color(0xFFE8F2EC),
                  child: Text(
                    '${change.kind.replaceAll('_', ' ').toLowerCase()} · File ${change.side.name.toUpperCase()}',
                    style: const TextStyle(
                      fontFamily: DytavaTypography.primaryFont,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Color(0xFF15803D),
                    ),
                  ),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: _value(
                        l10n.isVietnamese ? 'Gốc' : 'Original',
                        '${change.kind.replaceAll('_', ' ').toLowerCase()} · File ${change.side.name.toUpperCase()}',
                        const Color(0xFFF3F5F4),
                        const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _singleValueBox(
                        label: l10n.isVietnamese ? 'Cập nhật' : 'Updated',
                        labelColor: const Color(0xFF64748B),
                        bg: const Color(0xFFFCECEB),
                        child: const Text(
                          '—',
                          style: TextStyle(
                            fontFamily: DytavaTypography.primaryFont,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: Color(0xFFB93829),
                          ),
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

Widget _singleValueBox({
  required String label,
  required Color labelColor,
  required Color bg,
  required Widget child,
}) => Container(
  width: double.infinity,
  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
  decoration: BoxDecoration(
    color: bg,
    borderRadius: BorderRadius.circular(12),
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(
          fontFamily: DytavaTypography.primaryFont,
          fontSize: 11.5,
          color: labelColor,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 4),
      child,
    ],
  ),
);

bool _isCellEmpty(SourceCell cell) {
  if (cell.kind == CellKind.missing) return true;
  if (cell.kind == CellKind.image) {
    return cell.imageBytes == null || cell.imageBytes!.isEmpty;
  }
  return cell.rawLexeme == null || cell.rawLexeme!.trim().isEmpty;
}

bool _isNumericOrAtomic(String a, String b) {
  final sA = a.trim();
  final sB = b.trim();
  if (sA.isEmpty || sB.isEmpty) return false;

  // Numeric, currency, percentage, accounting format
  final numPattern = RegExp(
    r'^([\$€£¥₫]|USD|VND|EUR)?\s*[-+(]?[0-9]+([.,][0-9]+)*[)]?\s*([%đ₫]|USD|VND|EUR)?$',
    caseSensitive: false,
  );
  if (numPattern.hasMatch(sA) && numPattern.hasMatch(sB)) return true;

  // Booleans
  final boolA = sA.toLowerCase();
  final boolB = sB.toLowerCase();
  if ((boolA == 'true' || boolA == 'false') &&
      (boolB == 'true' || boolB == 'false')) {
    return true;
  }

  // Dates or times (e.g. 2026-11-24, 24/11/2026, 10:45)
  final dateTimePattern = RegExp(
    r'^(\d{1,4}[-/.]\d{1,2}[-/.]\d{1,4}|\d{1,2}:\d{2}(:\d{2})?)$',
  );
  if (dateTimePattern.hasMatch(sA) && dateTimePattern.hasMatch(sB)) {
    return true;
  }

  // Formulas
  if (sA.startsWith('=') && sB.startsWith('=')) return true;

  // Short atomic tokens (<= 4 chars without spaces)
  if (!sA.contains(' ') &&
      !sB.contains(' ') &&
      sA.length <= 4 &&
      sB.length <= 4) {
    return true;
  }

  return false;
}

class _DiffOp {
  final int type; // 0: equal, -1: delete, 1: insert
  final String text;
  const _DiffOp(this.type, this.text);
}

class _DiffHunk {
  final String prefix;
  final List<_DiffOp> ops;
  final String suffix;
  const _DiffHunk({
    required this.prefix,
    required this.ops,
    required this.suffix,
  });
}

List<_DiffOp> _diffChars(String a, String b) {
  if (a.isEmpty && b.isEmpty) return const [];
  if (a.isEmpty) return [_DiffOp(1, b)];
  if (b.isEmpty) return [_DiffOp(-1, a)];

  final runesA = a.runes.toList(growable: false);
  final runesB = b.runes.toList(growable: false);

  var prefix = 0;
  while (prefix < runesA.length &&
      prefix < runesB.length &&
      runesA[prefix] == runesB[prefix]) {
    prefix++;
  }

  var suffix = 0;
  while (suffix < runesA.length - prefix &&
      suffix < runesB.length - prefix &&
      runesA[runesA.length - 1 - suffix] == runesB[runesB.length - 1 - suffix]) {
    suffix++;
  }

  final midA = runesA.sublist(prefix, runesA.length - suffix);
  final midB = runesB.sublist(prefix, runesB.length - suffix);

  final ops = <_DiffOp>[];
  if (prefix > 0) {
    ops.add(_DiffOp(0, String.fromCharCodes(runesA.sublist(0, prefix))));
  }

  if (midA.length * midB.length > 250000) {
    if (midA.isNotEmpty) ops.add(_DiffOp(-1, String.fromCharCodes(midA)));
    if (midB.isNotEmpty) ops.add(_DiffOp(1, String.fromCharCodes(midB)));
  } else {
    final m = midA.length;
    final n = midB.length;
    final dp = List.generate(m + 1, (_) => Int32List(n + 1));
    for (var i = 1; i <= m; i++) {
      for (var j = 1; j <= n; j++) {
        dp[i][j] = midA[i - 1] == midB[j - 1]
            ? dp[i - 1][j - 1] + 1
            : (dp[i - 1][j] > dp[i][j - 1] ? dp[i - 1][j] : dp[i][j - 1]);
      }
    }

    var i = m;
    var j = n;
    final midOps = <_DiffOp>[];
    while (i > 0 || j > 0) {
      if (i > 0 && j > 0 && midA[i - 1] == midB[j - 1]) {
        midOps.add(_DiffOp(0, String.fromCharCode(midA[--i])));
        j--;
      } else if (j > 0 && (i == 0 || dp[i][j - 1] >= dp[i - 1][j])) {
        midOps.add(_DiffOp(1, String.fromCharCode(midB[--j])));
      } else {
        midOps.add(_DiffOp(-1, String.fromCharCode(midA[--i])));
      }
    }

    _DiffOp? current;
    for (final op in midOps.reversed) {
      if (current == null) {
        current = op;
      } else if (current.type == op.type) {
        current = _DiffOp(current.type, current.text + op.text);
      } else {
        ops.add(current);
        current = op;
      }
    }
    if (current != null) ops.add(current);
  }

  if (suffix > 0) {
    ops.add(_DiffOp(0, String.fromCharCodes(runesA.sublist(runesA.length - suffix))));
  }

  final merged = <_DiffOp>[];
  for (final op in ops) {
    if (merged.isNotEmpty && merged.last.type == op.type) {
      final last = merged.removeLast();
      merged.add(_DiffOp(last.type, last.text + op.text));
    } else {
      merged.add(op);
    }
  }
  return merged;
}

String _extractWordPrefix(String text, {int maxChars = 14}) {
  if (text.isEmpty) return '';
  // Include trailing characters of the current word plus up to maxChars of immediate context
  final slice = text.length > maxChars ? text.substring(text.length - maxChars) : text;
  if (text.length <= maxChars) return slice;
  final spaceIdx = slice.indexOf(' ');
  if (spaceIdx != -1 && spaceIdx < slice.length - 1) {
    return slice.substring(spaceIdx + 1);
  }
  return slice;
}

String _extractWordSuffix(String text, {int maxChars = 14}) {
  if (text.isEmpty) return '';
  final slice = text.length > maxChars ? text.substring(0, maxChars) : text;
  if (text.length <= maxChars) return slice;
  final spaceIdx = slice.lastIndexOf(' ');
  if (spaceIdx > 0) {
    return slice.substring(0, spaceIdx);
  }
  return slice;
}

List<InlineSpan> _computeTextDiffSpans(String a, String b) {
  const deletedStyle = TextStyle(
    color: Color(0xFFDC2626),
    decoration: TextDecoration.lineThrough,
    decorationColor: Color(0xFFDC2626),
    decorationThickness: 2.0,
    fontStyle: FontStyle.italic,
    fontWeight: FontWeight.w700,
  );
  const insertedStyle = TextStyle(
    color: Color(0xFF15803D),
    fontStyle: FontStyle.italic,
    fontWeight: FontWeight.w700,
  );
  const italicStyle = TextStyle(
    color: Color(0xFF8D5411),
    fontStyle: FontStyle.italic,
    fontWeight: FontWeight.w700,
  );
  const separatorStyle = TextStyle(
    color: Color(0xFF8D5411),
    fontWeight: FontWeight.w800,
    fontStyle: FontStyle.normal,
  );

  if (a == b) {
    return [TextSpan(text: b, style: italicStyle)];
  }

  final ops = _diffChars(a, b);
  final changeIndices = <int>[];
  for (var i = 0; i < ops.length; i++) {
    if (ops[i].type != 0) changeIndices.add(i);
  }

  if (changeIndices.isEmpty) {
    return [TextSpan(text: b, style: italicStyle)];
  }

  // Group change operations into distinct change points (hunks).
  // Changes separated by whitespace or > 3 unchanged characters become separate hunks
  // so multiple change points are clearly separated by " | ".
  final hunks = <_DiffHunk>[];
  var k = 0;
  while (k < changeIndices.length) {
    final startIdx = changeIndices[k];
    var endIdx = startIdx;
    while (k + 1 < changeIndices.length) {
      final nextIdx = changeIndices[k + 1];
      var gapText = '';
      for (var g = endIdx + 1; g < nextIdx; g++) {
        gapText += ops[g].text;
      }
      final hasWhitespace = gapText.contains(RegExp(r'\s'));
      if (!hasWhitespace && gapText.length <= 3) {
        endIdx = nextIdx;
        k++;
      } else {
        break;
      }
    }

    var prefix = '';
    if (startIdx > 0 && ops[startIdx - 1].type == 0) {
      prefix = _extractWordPrefix(ops[startIdx - 1].text);
    }

    var suffix = '';
    if (endIdx + 1 < ops.length && ops[endIdx + 1].type == 0) {
      suffix = _extractWordSuffix(ops[endIdx + 1].text);
    }

    hunks.add(
      _DiffHunk(
        prefix: prefix,
        ops: ops.sublist(startIdx, endIdx + 1),
        suffix: suffix,
      ),
    );
    k++;
  }

  // Single change point in a short string -> render full string with inline diff
  if (hunks.length == 1 && a.length <= 48 && b.length <= 48) {
    final spans = <InlineSpan>[];
    for (final op in ops) {
      if (op.type == 0) {
        spans.add(TextSpan(text: op.text, style: italicStyle));
      } else if (op.type == -1) {
        spans.add(TextSpan(text: op.text, style: deletedStyle));
      } else if (op.type == 1) {
        spans.add(TextSpan(text: op.text, style: insertedStyle));
      }
    }
    return spans;
  }

  // Prioritize changed segments; separate multiple change points with " | "
  final resultSpans = <InlineSpan>[];
  for (var hIdx = 0; hIdx < hunks.length; hIdx++) {
    if (hIdx > 0) {
      resultSpans.add(const TextSpan(text: ' | ', style: separatorStyle));
    }
    final h = hunks[hIdx];
    if (h.prefix.isNotEmpty) {
      resultSpans.add(TextSpan(text: h.prefix, style: italicStyle));
    }
    for (final op in h.ops) {
      if (op.type == -1) {
        resultSpans.add(TextSpan(text: op.text, style: deletedStyle));
      } else if (op.type == 1) {
        resultSpans.add(TextSpan(text: op.text, style: insertedStyle));
      } else {
        resultSpans.add(TextSpan(text: op.text, style: italicStyle));
      }
    }
    if (h.suffix.isNotEmpty) {
      resultSpans.add(TextSpan(text: h.suffix, style: italicStyle));
    }
  }

  return resultSpans;
}

Widget _buildInlineTextDiff(String a, String b) {
  final spans = _computeTextDiffSpans(a, b);
  return RichText(
    text: TextSpan(
      style: const TextStyle(
        fontFamily: DytavaTypography.primaryFont,
        fontSize: 15,
        color: Color(0xFF8D5411),
        fontStyle: FontStyle.italic,
        fontWeight: FontWeight.w700,
        height: 1.35,
      ),
      children: spans,
    ),
  );
}

final _refPattern = RegExp(r'^(.*)!R(\d+)/');
final _recordRowPattern = RegExp(r'/record-(\d+)/');

String _cellLocation(
  WorkflowController flow,
  CellDifference cell,
  SourceSide side,
) {
  final effectiveSide = (side == SourceSide.a &&
          (cell.locationA == null || cell.locationA!.isEmpty) &&
          cell.locationB != null &&
          cell.locationB!.isNotEmpty)
      ? SourceSide.b
      : side;
  final location =
      effectiveSide == SourceSide.a ? cell.locationA : cell.locationB;
  final plan = flow.displayedResult?.planForCell(cell) ??
      flow.result?.planForCell(cell) ??
      flow.result!.plan;
  final source = effectiveSide == SourceSide.a ? plan.a : plan.b;
  final field = effectiveSide == SourceSide.a
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
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.tune_rounded,
                    color: DytavaColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    context.l10n.comparisonDetails,
                    style: const TextStyle(
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
              _techRow(context.l10n.ruleReference, cell.decision.ruleId),
              _techRow(context.l10n.comparisonType, _ruleTypeLabel(cell)),
              _techRow(context.l10n.matchingMode, switch (flow.config.mode) {
                MatchingMode.positional => context.l10n.byPosition,
                MatchingMode.key => context.l10n.byKeyColumn,
                MatchingMode.orderedSequence => context.l10n.sequenceAlignment,
              }),
              if (cell.a.kind == CellKind.image)
                _techRow(
                  context.l10n.originalImagePlacement,
                  cell.a.imagePlacement == 'drawingAnchor'
                      ? context.l10n.placeOverCellsBadge
                      : context.l10n.placeInCellBadge,
                ),
              if (cell.b.kind == CellKind.image)
                _techRow(
                  context.l10n.updatedImagePlacement,
                  cell.b.imagePlacement == 'drawingAnchor'
                      ? context.l10n.placeOverCellsBadge
                      : context.l10n.placeInCellBadge,
                ),
              _techRow(
                context.l10n.originalSource,
                '${flow.slot(SourceSide.a).artifact?.label ?? (context.l10n.isVietnamese ? "Tệp A" : "File A")} · ${_cellLocation(flow, cell, SourceSide.a)}',
              ),
              _techRow(
                context.l10n.updatedSource,
                '${flow.slot(SourceSide.b).artifact?.label ?? (context.l10n.isVietnamese ? "Tệp B" : "File B")} · ${_cellLocation(flow, cell, SourceSide.b)}',
              ),
              _techRow(
                context.l10n.originalNormalized,
                cell.decision.left?.label ?? '—',
              ),
              _techRow(
                context.l10n.updatedNormalized,
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
                      Text(
                        context.l10n.characterDifference,
                        style: const TextStyle(
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
                        label: '${context.l10n.isVietnamese ? "GỐC" : "ORIGINAL"} · A',
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
                        label: '${context.l10n.isVietnamese ? "CẬP NHẬT" : "UPDATED"} · B',
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
                        context.l10n.numericDifference(numDelta.label),
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
                label: Text(context.l10n.comparisonDetails),
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
                label: Text(
                  context.l10n.backToDifferences,
                  style: const TextStyle(
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
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.arrow_back_rounded, size: 16),
                  const SizedBox(width: 4),
                  Text(context.l10n.previous),
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
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(context.l10n.next),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward_rounded, size: 16),
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text(
                  context.l10n.jumpToDifference,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const Spacer(),
                Text(
                  context.l10n.totalCount(widget.list.length),
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
                hintText: context.l10n.isVietnamese
                    ? 'Tìm ô, sheet, hoặc giá trị...'
                    : 'Search cell, sheet, or value...',
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
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final hasReceipt = flow.receipt != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 4),
        Text(
          l10n.exportReport,
          style: const TextStyle(
            fontFamily: DytavaTypography.primaryFont,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.includeComparedCells(flow.result!.cells.length),
          style: const TextStyle(
            fontFamily: DytavaTypography.primaryFont,
            fontSize: 13,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 14),
        RadioGroup<ExportKind>(
          groupValue: exportKind,
          onChanged: (value) {
            if (value != null) onKindChanged(value);
          },
          child: Column(
            children: [
              for (final kind in [
                ExportKind.csvDiff,
                ExportKind.jsonReport,
                ExportKind.dytavaReportPdf,
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: exportKind == kind
                        ? const Color(0xFFE8F5E9)
                        : const Color(0xFFF8FAF9),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                        color: exportKind == kind
                            ? DytavaColors.primary
                            : const Color(0xFFE2E8F0),
                        width: exportKind == kind ? 1.4 : 1.0,
                      ),
                    ),
                    child: RadioListTile<ExportKind>(
                      value: kind,
                      enabled: !flow.busy,
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      controlAffinity: ListTileControlAffinity.trailing,
                      activeColor: DytavaColors.primary,
                      title: Text(
                        switch (kind) {
                          ExportKind.csvDiff => 'CSV',
                          ExportKind.jsonReport => 'JSON',
                          ExportKind.dytavaReportPdf ||
                          ExportKind.mergedDiffPdf =>
                            'PDF',
                        },
                        style: TextStyle(
                          fontFamily: DytavaTypography.primaryFont,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: exportKind == kind
                              ? DytavaColors.primaryDark
                              : const Color(0xFF1E293B),
                        ),
                      ),
                      subtitle: Text(
                        switch (kind) {
                          ExportKind.csvDiff => l10n.csvSubtitle,
                          ExportKind.jsonReport => l10n.jsonSubtitle,
                          ExportKind.dytavaReportPdf ||
                          ExportKind.mergedDiffPdf =>
                            l10n.pdfSubtitle,
                        },
                        style: const TextStyle(
                          fontFamily: DytavaTypography.primaryFont,
                          fontSize: 11.5,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<ExportSelection>(
          isExpanded: true,
          initialValue: selection,
          decoration: InputDecoration(
            labelText: l10n.reportScope,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          items: [
            DropdownMenuItem(
              value: ExportSelection.fullComparison,
              child: Text(l10n.fullComparison),
            ),
            DropdownMenuItem(
              value: ExportSelection.differencesOnly,
              child: Text(l10n.differencesAndUnresolved),
            ),
          ],
          onChanged: flow.busy
              ? null
              : (v) {
                  if (v != null) onSelectionChanged(v);
                },
        ),
        const SizedBox(height: 10),
        if (!hasReceipt) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: scopeConfirmed
                  ? const Color(0xFFE8F5E9)
                  : const Color(0xFFF8FAF9),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: scopeConfirmed
                      ? DytavaColors.primary
                      : const Color(0xFFE2E8F0),
                ),
              ),
              child: CheckboxListTile(
                dense: true,
                visualDensity: VisualDensity.compact,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                activeColor: DytavaColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                title: Text(
                  l10n.confirmFormatAndReportScope,
                  style: const TextStyle(
                    fontFamily: DytavaTypography.primaryFont,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
                value: scopeConfirmed,
                onChanged: flow.busy
                    ? null
                    : (v) => onScopeConfirmedChanged(v ?? false),
              ),
            ),
          ),
          WorkflowPrimaryButton(
            label: l10n.prepareReport,
            onPressed: scopeConfirmed &&
                    flow.exporter.supports(exportKind) &&
                    !flow.busy
                ? onRunExportPreview
                : null,
          ),
        ],
        if (flow.issue != null) WorkflowIssueList(issues: [flow.issue!]),
        if (flow.exportState?.active == true) ...[
          const SizedBox(height: 10),
          const LinearProgressIndicator(),
          TextButton(
            onPressed: flow.exportState == ExportState.cancelling
                ? null
                : flow.cancelExport,
            child: Text(l10n.cancelExport),
          ),
        ],
        if (hasReceipt)
          DytavaFadeSlide(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        color: DytavaColors.primary,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.reportReady,
                          style: const TextStyle(
                            fontFamily: DytavaTypography.primaryFont,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF065F46),
                          ),
                        ),
                      ),
                      if (flow.receipt!.fileName != null)
                        Flexible(
                          child: Text(
                            flow.receipt!.fileName!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: DytavaTypography.primaryFont,
                              fontSize: 11.5,
                              color: Color(0xFF047857),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                WorkflowPrimaryButton(
                  label: l10n.saveToDevice,
                  iconAsset: DytavaIcons.export,
                  onPressed: () => _save(context),
                ),
                Theme(
                  data: Theme.of(context).copyWith(
                    dividerColor: Colors.transparent,
                  ),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 4),
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    title: Text(
                      l10n.previewReport,
                      style: const TextStyle(
                        fontFamily: DytavaTypography.primaryFont,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF334155),
                      ),
                    ),
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        constraints: const BoxConstraints(maxHeight: 160),
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
                ),
              ],
            ),
          ),
        const SizedBox(height: 4),
        TextButton(
          onPressed: flow.busy ? null : onBackToResults,
          child: Text(
            l10n.cancel,
            style: const TextStyle(
              fontFamily: DytavaTypography.primaryFont,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _save(BuildContext context) async {
    final l10n = context.l10n;
    final receipt = flow.receipt!;
    final fileName = receipt.fileName ??
        switch (exportKind) {
          ExportKind.csvDiff => 'dytava-differences.csv',
          ExportKind.jsonReport => 'dytava-report.json',
          ExportKind.dytavaReportPdf ||
          ExportKind.mergedDiffPdf =>
            'dytava-report.pdf',
        };
    final bytes = receipt.fileBytes != null
        ? Uint8List.fromList(receipt.fileBytes!)
        : Uint8List.fromList(utf8.encode(receipt.previewText));
    final mimeType = fileName.endsWith('.csv')
        ? 'text/csv'
        : fileName.endsWith('.pdf')
        ? 'application/pdf'
        : 'application/json';
    try {
      final uri = await FilePicker.saveFile(
        fileName: fileName,
        bytes: bytes,
        mimeType: mimeType,
      );
      // Không tự động đóng modal sau khi lưu thành công để người dùng có thể xuất thêm định dạng khác hoặc xem lại báo cáo
      if (context.mounted && uri != null) {
        DytavaToast.success(
          context,
          l10n.reportSavedToast,
          title: l10n.reportSavedTitle,
        );
      }
    } catch (_) {
      if (context.mounted) {
        DytavaToast.error(
          context,
          l10n.chooseAnotherLocationRetry,
          title: l10n.unableToSaveReport,
        );
      }
    }
  }
}
