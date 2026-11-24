import 'dart:async';
import 'dart:math' as math;

import 'package:excelcompare_core/excelcompare_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../design_system/design_system.dart';
import '../../../domain/workflow.dart';
import '../../../l10n/app_localizations.dart';

/// Mobile-native synchronized Table View for a single active sheet pair.
///
/// - Renders ONE active sheet at a time (never stacks multiple sheets vertically).
/// - Clean 1-row toolbar: Landscape toggle (`Xoay ngang`), auto-zoom difference
///   stepper (`Khác biệt X/N` with up/down arrows), and pinch-to-zoom on the
///   table grid (no extra web filter chips or metadata text).
class MobileAlignedGrid extends StatefulWidget {
  const MobileAlignedGrid({
    super.key,
    required this.result,
    required this.onOpenCell,
  });
  final ComparisonResult result;
  final ValueChanged<String> onOpenCell;
  @override
  State<MobileAlignedGrid> createState() => _MobileAlignedGridState();
}

class _MobileAlignedGridState extends State<MobileAlignedGrid> {
  static const _rowHeight = 48.0;
  static const _colWidth = 148.0;
  static const _indexColWidth = 44.0;

  String filter = 'ALL';
  int page = 0;
  List<AlignedTableRow> rows = const [];
  List<FieldMapping> mappings = const [];
  final counts = <String, int>{};
  final horizontal = [ScrollController(), ScrollController()],
      vertical = [ScrollController(), ScrollController()];
  bool syncing = false;
  bool _landscapeLocked = false;
  double _cellZoom = 1.0;
  double _gestureBaseZoom = 1.0;

  /// List of `(visibleRowIndex, columnIndex, cellId)` for difference navigation.
  List<(int, int, String?)> _diffLocations = const [];
  int _activeDiffCursor = -1;
  (int, int)? _highlightedCoord;

  @override
  void initState() {
    super.initState();
    _rebuild();
    for (final group in [horizontal, vertical]) {
      for (final c in group) {
        c.addListener(() => _sync(c, group));
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _diffLocations.isNotEmpty) {
        _jumpToDifference(0);
      }
    });
  }

  void _sync(ScrollController source, List<ScrollController> group) {
    if (syncing || !source.hasClients) return;
    syncing = true;
    for (final c in group) {
      if (c != source && c.hasClients) {
        final offset = source.offset.clamp(0.0, c.position.maxScrollExtent);
        if ((c.offset - offset).abs() > 0.5) c.jumpTo(offset);
      }
    }
    syncing = false;
  }

  @override
  void didUpdateWidget(covariant MobileAlignedGrid old) {
    super.didUpdateWidget(old);
    if (!identical(old.result, widget.result)) {
      page = 0;
      _rebuild();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _diffLocations.isNotEmpty) {
          _jumpToDifference(0);
        }
      });
    }
  }

  @override
  void dispose() {
    if (_landscapeLocked) {
      unawaited(
        SystemChrome.setPreferredOrientations(const [
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]),
      );
    }
    for (final c in [...horizontal, ...vertical]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _toggleLandscapeOrientation() async {
    final next = !_landscapeLocked;
    setState(() => _landscapeLocked = next);
    await SystemChrome.setPreferredOrientations(
      next
          ? const [
              DeviceOrientation.landscapeLeft,
              DeviceOrientation.landscapeRight,
            ]
          : const [
              DeviceOrientation.portraitUp,
              DeviceOrientation.portraitDown,
              DeviceOrientation.landscapeLeft,
              DeviceOrientation.landscapeRight,
            ],
    );
  }

  String kind(AlignedTableRow row) {
    if (row.unresolved) return 'UNRESOLVED';
    final forward =
        widget.result.plan.config.direction == ComparisonDirection.aToB;
    if (row.a == null) return forward ? 'ADDED' : 'REMOVED';
    if (row.b == null) return forward ? 'REMOVED' : 'ADDED';
    return row.status.name.toUpperCase();
  }

  void _rebuild() {
    final result = widget.result;
    mappings = [
      ...result.plan.config.mappings,
      for (final f in result.plan.a.fields.where(
        (f) => !result.plan.config.mappings.any((m) => m.fieldA == f.id),
      ))
        FieldMapping(f.id, ''),
      for (final f in result.plan.b.fields.where(
        (f) => !result.plan.config.mappings.any((m) => m.fieldB == f.id),
      ))
        FieldMapping('', f.id),
    ];
    counts.clear();
    for (final r in result.alignedRows) {
      counts.update(kind(r), (n) => n + 1, ifAbsent: () => 1);
    }
    _filter();
  }

  void _filter() {
    rows = widget.result.alignedRows
        .where((r) => filter == 'ALL' || kind(r) == filter)
        .toList();
    _recomputeDiffLocations();
  }

  void _recomputeDiffLocations() {
    final visible = rows.skip(page * 100).take(100).toList();
    final locs = <(int, int, String?)>[];
    for (var r = 0; r < visible.length; r++) {
      final row = visible[r];
      final rowKind = kind(row);
      final mapByPair = {
        for (final c in row.cells) (c.mapping.fieldA, c.mapping.fieldB): c,
      };
      var addedForRow = false;
      for (var c = 0; c < mappings.length; c++) {
        final m = mappings[c];
        final cellDiff = mapByPair[(m.fieldA, m.fieldB)];
        final status = cellDiff?.decision.status.name.toUpperCase();
        if (status == 'DIFFERENT' || status == 'UNRESOLVED') {
          locs.add((r, c, cellDiff?.id));
          addedForRow = true;
        }
      }
      if (!addedForRow &&
          (rowKind == 'ADDED' ||
              rowKind == 'REMOVED' ||
              rowKind == 'UNRESOLVED')) {
        locs.add((r, 0, null));
      }
    }
    _diffLocations = locs;
    _activeDiffCursor = locs.isEmpty ? -1 : 0;
    _highlightedCoord = locs.isEmpty ? null : (locs.first.$1, locs.first.$2);
  }

  void _jumpToDifference(int nextIndex) {
    if (_diffLocations.isEmpty) return;
    final wrapped =
        (nextIndex % _diffLocations.length + _diffLocations.length) %
        _diffLocations.length;
    final target = _diffLocations[wrapped];
    setState(() {
      _activeDiffCursor = wrapped;
      _highlightedCoord = (target.$1, target.$2);
      if (_cellZoom < 1.1) {
        _cellZoom = 1.12;
      }
    });

    final scaledColW = _colWidth * _cellZoom;
    final scaledRowH = _rowHeight * _cellZoom;
    final targetX = math.max(0.0, target.$2 * scaledColW - 20.0);
    final targetY = math.max(0.0, target.$1 * scaledRowH - scaledRowH);

    for (final hc in horizontal) {
      if (hc.hasClients) {
        final clampedX = targetX.clamp(0.0, hc.position.maxScrollExtent);
        unawaited(
          hc.animateTo(
            clampedX,
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
          ),
        );
      }
    }
    for (final vc in vertical) {
      if (vc.hasClients) {
        final clampedY = targetY.clamp(0.0, vc.position.maxScrollExtent);
        unawaited(
          vc.animateTo(
            clampedY,
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
          ),
        );
      }
    }
  }

  Color color(String status) => switch (status) {
    'EXACT' => DytavaColors.exactBg,
    'EQUIVALENT' => DytavaColors.equivalentBg,
    'DIFFERENT' => DytavaColors.differentBg,
    'UNRESOLVED' => DytavaColors.unresolvedBg,
    'ADDED' => DytavaColors.softGreen,
    'REMOVED' => DytavaColors.differentBg,
    _ => DytavaColors.background,
  };

  Widget cell(
    String value, {
    double width = _colWidth,
    double height = _rowHeight,
    Color? bg,
    VoidCallback? tap,
    bool header = false,
    bool highlighted = false,
    SourceCell? sourceCell,
  }) => InkWell(
    onTap: tap,
    child: Container(
      width: width,
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(
          color: highlighted ? DytavaColors.primary : DytavaColors.border,
          width: highlighted ? 2.0 : 0.5,
        ),
      ),
      child: (sourceCell != null &&
              sourceCell.kind == CellKind.image &&
              sourceCell.imageBytes != null &&
              sourceCell.imageBytes!.isNotEmpty)
          ? Row(
              children: [
                Container(
                  width: (height - 10).clamp(24.0, 44.0),
                  height: (height - 10).clamp(24.0, 44.0),
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: DytavaColors.border, width: 0.5),
                  ),
                  child: Image.memory(
                    Uint8List.fromList(sourceCell.imageBytes!),
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.none,
                    errorBuilder: (_, _, _) => const Icon(
                      Icons.image_outlined,
                      size: 16,
                      color: DytavaColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sourceCell.imagePlacement == 'drawingAnchor'
                            ? context.l10n.placeOverCells
                            : context.l10n.placeInCellBadge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DytavaTypography.labelSmall.copyWith(
                          fontSize: (10.0 * _cellZoom).clamp(9.0, 13.0),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (sourceCell.imageDigest != null &&
                          sourceCell.imageDigest!.length >= 8)
                        Text(
                          sourceCell.imageDigest!.substring(0, 8),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: DytavaTypography.dataSmall.copyWith(
                            fontSize: (9.5 * _cellZoom).clamp(8.5, 12.0),
                            color: DytavaColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            )
          : Text(
              value.isEmpty ? '—' : value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style:
                  (header
                          ? DytavaTypography.labelLarge
                          : DytavaTypography.dataSmall)
                      .copyWith(
                        fontSize: ((header ? 12.5 : 11.5) * _cellZoom).clamp(
                          10.5,
                          17.0,
                        ),
                      ),
            ),
    ),
  );

  Widget _pane(
    SourceSide side,
    List<AlignedTableRow> visible,
    List<Map<(String, String), CellDifference>> cellsByRow,
    double gridHeight,
  ) {
    final index = side.index;
    final scaledColW = _colWidth * _cellZoom;
    final scaledRowH = _rowHeight * _cellZoom;
    final scaledIndexW = _indexColWidth * _cellZoom;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              side == SourceSide.a ? context.l10n.sourceA : context.l10n.sourceB,
              style: const TextStyle(
                fontFamily: DytavaTypography.primaryFont,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: DytavaColors.textPrimary,
              ),
            ),
          ),
          Scrollbar(
            controller: horizontal[index],
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: horizontal[index],
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: scaledIndexW + scaledColW * mappings.length.toDouble(),
                height: gridHeight,
                child: Column(
                  children: [
                    Row(
                      children: [
                        cell(
                          '#',
                          width: scaledIndexW,
                          height: scaledRowH,
                          header: true,
                          bg: DytavaColors.softBlue,
                        ),
                        for (final m in mappings)
                          cell(
                            side == SourceSide.a ? m.fieldA : m.fieldB,
                            width: scaledColW,
                            height: scaledRowH,
                            header: true,
                            bg: DytavaColors.softBlue,
                          ),
                      ],
                    ),
                    Expanded(
                      child: ListView.builder(
                        controller: vertical[index],
                        primary: false,
                        itemExtent: scaledRowH,
                        itemCount: visible.length,
                        itemBuilder: (context, i) {
                          final row = visible[i],
                              record = side == SourceSide.a
                                  ? visible[i].a
                                  : visible[i].b;
                          return Row(
                            children: [
                              Semantics(
                                key: ValueKey(
                                  'aligned-${side.name}-${record?.id ?? "gap-$i"}',
                                ),
                                label:
                                    'Dòng ${side.name.toUpperCase()} ${record == null ? "trống" : record.ordinal + 1} · ${kind(row)}',
                                child: cell(
                                  record == null
                                      ? '—'
                                      : '${record.ordinal + 1}',
                                  width: scaledIndexW,
                                  height: scaledRowH,
                                  bg: color(kind(row)),
                                  tap: () => showModalBottomSheet<void>(
                                    context: context,
                                    builder: (_) => Padding(
                                      padding: const EdgeInsets.all(24),
                                      child: Text(row.rationale),
                                    ),
                                  ),
                                ),
                              ),
                              for (var colIdx = 0; colIdx < mappings.length; colIdx++)
                                Builder(
                                  builder: (_) {
                                    final m = mappings[colIdx];
                                    final c =
                                        cellsByRow[i][(m.fieldA, m.fieldB)];
                                    final isFocused =
                                        _highlightedCoord == (i, colIdx);
                                    final srcCell = record?.cells[
                                      side == SourceSide.a ? m.fieldA : m.fieldB
                                    ];
                                    return cell(
                                      srcCell?.rawLexeme ?? '',
                                      width: scaledColW,
                                      height: scaledRowH,
                                      highlighted: isFocused,
                                      sourceCell: srcCell,
                                      bg: color(
                                        row.unresolved
                                            ? 'UNRESOLVED'
                                            : c?.decision.status.name
                                                      .toUpperCase() ??
                                                  kind(row),
                                      ),
                                      tap: c == null
                                          ? null
                                          : () => widget.onOpenCell(c.id),
                                    );
                                  },
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = rows.skip(page * 100).take(100).toList();
    final cellsByRow = [
      for (final r in visible)
        {for (final c in r.cells) (c.mapping.fieldA, c.mapping.fieldB): c},
    ];
    final screenH = MediaQuery.sizeOf(context).height;
    final scaledRowH = _rowHeight * _cellZoom;
    final maxGridH = (screenH * 0.62).clamp(240.0, 560.0);
    final gridHeight = ((visible.length + 1) * scaledRowH).clamp(
      110.0,
      maxGridH,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Single-line compact mobile toolbar: Landscape toggle + Difference Auto-Zoom stepper
        Wrap(
          spacing: 6,
          runSpacing: 6,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              key: const ValueKey('table-view-rotate-landscape-button'),
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              ),
              onPressed: _toggleLandscapeOrientation,
              icon: Icon(
                _landscapeLocked
                    ? Icons.screen_lock_rotation_rounded
                    : Icons.screen_rotation_rounded,
                size: 15,
              ),
              label: Text(
                _landscapeLocked
                    ? (context.l10n.isVietnamese ? 'Màn hình dọc' : 'Portrait')
                    : (context.l10n.isVietnamese ? 'Xoay ngang' : 'Landscape'),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
            if (_diffLocations.isNotEmpty)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    key: const ValueKey('table-view-prev-diff-button'),
                    tooltip: context.l10n.previousDifference,
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _jumpToDifference(_activeDiffCursor - 1),
                    icon: const Icon(Icons.keyboard_arrow_up_rounded, size: 20),
                  ),
                  InkWell(
                    key: const ValueKey('table-view-next-diff-chip'),
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _jumpToDifference(_activeDiffCursor + 1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: DytavaColors.modifiedBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        context.l10n.diffIndexRatio(_activeDiffCursor + 1, _diffLocations.length),
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: DytavaColors.modified,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('table-view-next-diff-button'),
                    tooltip: context.l10n.nextDifference,
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _jumpToDifference(_activeDiffCursor + 1),
                    icon: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 20,
                    ),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (visible.isEmpty)
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(context.l10n.noRowsData),
          )
        else
          GestureDetector(
            onScaleStart: (_) => _gestureBaseZoom = _cellZoom,
            onScaleUpdate: (details) {
              if (details.pointerCount >= 2) {
                setState(() {
                  _cellZoom = (_gestureBaseZoom * details.scale).clamp(
                    0.8,
                    1.6,
                  );
                });
              }
            },
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _pane(SourceSide.a, visible, cellsByRow, gridHeight),
                const SizedBox(width: 8),
                _pane(SourceSide.b, visible, cellsByRow, gridHeight),
              ],
            ),
          ),
        if (rows.length > 100)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 36),
                  ),
                  onPressed: page > 0
                      ? () => setState(() {
                          page--;
                          _recomputeDiffLocations();
                        })
                      : null,
                  child: Text(
                    context.l10n.previousPage,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                Expanded(
                  child: Text(
                    '${page * 100 + 1}–${(page * 100 + 100).clamp(0, rows.length)} / ${rows.length}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 36),
                  ),
                  onPressed: (page + 1) * 100 < rows.length
                      ? () => setState(() {
                          page++;
                          _recomputeDiffLocations();
                        })
                      : null,
                  child: Text(
                    context.l10n.nextPage,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
