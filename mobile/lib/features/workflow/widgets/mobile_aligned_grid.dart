import 'package:flutter/material.dart';

import '../../../domain/workflow.dart';
import '../../../design_system/design_system.dart';

/// Both panes use the same alignment/page and synchronize horizontal/vertical scroll.
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
  String filter = 'ALL';
  int page = 0;
  List<AlignedTableRow> rows = const [];
  List<FieldMapping> mappings = const [];
  final counts = <String, int>{};
  final horizontal = [ScrollController(), ScrollController()],
      vertical = [ScrollController(), ScrollController()];
  bool syncing = false;
  @override
  void initState() {
    super.initState();
    _rebuild();
    for (final group in [horizontal, vertical]) {
      for (final c in group) {
        c.addListener(() => _sync(c, group));
      }
    }
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
    }
  }

  @override
  void dispose() {
    for (final c in [...horizontal, ...vertical]) {
      c.dispose();
    }
    super.dispose();
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
    double width = 156,
    Color? bg,
    VoidCallback? tap,
    bool header = false,
  }) => InkWell(
    onTap: tap,
    child: Container(
      width: width,
      height: 52,
      padding: const EdgeInsets.all(6),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: DytavaColors.border, width: 0.5),
      ),
      child: Text(
        value.isEmpty ? '—' : value,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: header
            ? DytavaTypography.labelLarge
            : DytavaTypography.dataSmall,
      ),
    ),
  );
  Widget _pane(
    SourceSide side,
    List<AlignedTableRow> visible,
    List<Map<(String, String), CellDifference>> cellsByRow,
  ) {
    final index = side.index;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Nguồn ${side.name.toUpperCase()}',
            style: DytavaTypography.titleMedium,
          ),
          Scrollbar(
            controller: horizontal[index],
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: horizontal[index],
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: 52 + 156 * mappings.length.toDouble(),
                height: ((visible.length + 1) * 52.0).clamp(104, 468),
                child: Column(
                  children: [
                    Row(
                      children: [
                        cell(
                          '#',
                          width: 52,
                          header: true,
                          bg: DytavaColors.softBlue,
                        ),
                        for (final m in mappings)
                          cell(
                            side == SourceSide.a ? m.fieldA : m.fieldB,
                            header: true,
                            bg: DytavaColors.softBlue,
                          ),
                      ],
                    ),
                    Expanded(
                      child: ListView.builder(
                        controller: vertical[index],
                        primary: false,
                        itemExtent: 52,
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
                                  width: 52,
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
                              for (final m in mappings)
                                Builder(
                                  builder: (_) {
                                    final c =
                                        cellsByRow[i][(m.fieldA, m.fieldB)];
                                    return cell(
                                      record
                                              ?.cells[side == SourceSide.a
                                                  ? m.fieldA
                                                  : m.fieldB]
                                              ?.rawLexeme ??
                                          '',
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
    final result = widget.result,
        visible = rows.skip(page * 100).take(100).toList();
    final cellsByRow = [
      for (final r in visible)
        {for (final c in r.cells) (c.mapping.fieldA, c.mapping.fieldB): c},
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Hai nguồn A | B · ${result.durationMs} ms xử lý · ${result.alignedRows.length} hàng sau căn chỉnh',
          style: DytavaTypography.bodySmall,
        ),
        Wrap(
          spacing: 6,
          children: [
            for (final value in [
              'ALL',
              'DIFFERENT',
              'UNRESOLVED',
              'EQUIVALENT',
              'EXACT',
              'ADDED',
              'REMOVED',
            ])
              ChoiceChip(
                label: Text(
                  '${value == 'ALL' ? 'Tất cả' : value} (${value == 'ALL' ? result.alignedRows.length : counts[value] ?? 0})',
                ),
                selected: filter == value,
                onSelected: (_) => setState(() {
                  filter = value;
                  page = 0;
                  _filter();
                }),
              ),
          ],
        ),
        if (visible.isEmpty)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text('Không có dòng phù hợp.'),
          )
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _pane(SourceSide.a, visible, cellsByRow),
              const SizedBox(width: 8),
              _pane(SourceSide.b, visible, cellsByRow),
            ],
          ),
        Row(
          children: [
            TextButton(
              onPressed: page > 0 ? () => setState(() => page--) : null,
              child: const Text('Trang trước'),
            ),
            Expanded(
              child: Text(
                '${rows.isEmpty ? 0 : page * 100 + 1}–${(page * 100 + 100).clamp(0, rows.length)} / ${rows.length} dòng',
                textAlign: TextAlign.center,
              ),
            ),
            TextButton(
              onPressed: (page + 1) * 100 < rows.length
                  ? () => setState(() => page++)
                  : null,
              child: const Text('Trang sau'),
            ),
          ],
        ),
        const Text(
          'Chạm ô để xem giá trị gốc, chuẩn hóa và quy tắc; chạm số dòng để xem lý do căn chỉnh.',
        ),
      ],
    );
  }
}
