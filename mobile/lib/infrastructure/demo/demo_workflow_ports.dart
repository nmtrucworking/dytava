// Explicit fixture harness only. No production format/OCR/profile is enabled.
import 'dart:convert';

import 'package:excelcompare_core/excelcompare_core.dart';

import '../../domain/workflow.dart';

Future<void> _checkpoint(Cancellation cancel) async {
  cancel.check();
  await Future<void>.delayed(Duration.zero);
  cancel.check();
}

typedef UserFileSnapshotData = ({
  String fileName,
  SourceFormat format,
  List<TableField> fields,
  List<List<String>> values,
});

final class DemoInputPort implements InputPort {
  static final Map<String, UserFileSnapshotData> _userFiles = {};

  static void registerUserFile(
    String ref, {
    required String fileName,
    required SourceFormat format,
    required List<TableField> fields,
    required List<List<String>> values,
  }) {
    _userFiles[ref] = (
      fileName: fileName,
      format: format,
      fields: fields,
      values: values,
    );
  }

  static void clearUserFiles() => _userFiles.clear();

  static const fields = [
    TableField('id', 'Mã'),
    TableField('amount', 'Giá trị'),
  ];
  static const valuesA = [
    ['001', '8.5'],
    ['002', 'abc'],
    ['003', '10'],
    ['004', '7'],
  ];
  static const valuesB = [
    ['001', '8,5'],
    ['002', '9'],
    ['003', '11'],
    ['004', '7'],
    ['005', '1'],
  ];
  @override
  Future<ImportOutcome> importSource(
    SourceArtifact artifact,
    ImportBinding binding,
    ImportConfiguration config,
    Cancellation cancel,
    void Function() onParsing,
  ) async {
    await _checkpoint(cancel);
    final isUserFile = artifact.privateRef.startsWith('userfile:');
    if (!isUserFile &&
        (!const {
          'fixture:a',
          'fixture:b',
          'fixture:image-a',
        }.contains(artifact.privateRef) ||
        (artifact.privateRef == 'fixture:image-a'
            ? artifact.format != SourceFormat.png
            : artifact.format != SourceFormat.csv))) {
      throw const WorkflowIssue(
        'INPUT_CAPABILITY_DISABLED',
        'Bản flow chỉ đọc nguồn mẫu. Adapter tệp thật chưa được bật.',
      );
    }

    if (isUserFile) {
      final userData = _userFiles[artifact.privateRef];
      if (userData == null) {
        throw const WorkflowIssue(
          'FILE_NOT_FOUND',
          'Không tìm thấy dữ liệu tệp tải lên.',
        );
      }
      onParsing();
      await _checkpoint(cancel);
      return ImportOutcome.ready(
        InputSnapshot(
          id: '${artifact.id}-snapshot-${binding.revision}-${binding.attempt}',
          binding: binding,
          fields: userData.fields,
          fullValidation: true,
          ocrReviewed: false,
          records: [
            for (var r = 0; r < userData.values.length; r++)
              TableRecord(
                '${artifact.id}-row-$r',
                r,
                {
                  for (var c = 0; c < userData.fields.length; c++)
                    userData.fields[c].id: SourceCell(
                      CellKind.text,
                      rawLexeme: c < userData.values[r].length ? userData.values[r][c] : '',
                      ocrReviewed: true,
                    ),
                },
                {
                  for (final f in userData.fields)
                    f.id: 'userfile/${artifact.id}/record-${r + 1}/${f.id}',
                },
              ),
          ],
        ),
      );
    }
    final isA = artifact.privateRef != 'fixture:b';
    final values = isA ? valuesA : valuesB;
    final reviewCells = [
      for (var r = 0; r < values.length; r++)
        for (var c = 0; c < fields.length; c++)
          ReviewCell('$r:${fields[c].id}', values[r][c]),
    ];
    if (artifact.format.isImage &&
        (config.ocrRevision < 0 ||
            reviewCells.any((c) => !config.reviewedCells.contains(c.id)))) {
      return ImportOutcome.review(
        ImportReview(
          const WorkflowIssue(
            'OCR_REVIEW_REQUIRED',
            'Dữ liệu OCR giả lập: cần xác nhận từng ô. Không có nhận dạng ảnh thật.',
          ),
          cells: reviewCells,
        ),
      );
    }
    if (!config.scopeConfirmed) {
      return ImportOutcome.review(
        ImportReview(
          const WorkflowIssue(
            'SCOPE_CONFIRMATION_REQUIRED',
            'Xác nhận bảng mẫu, header Mã/Giá trị và dấu thập phân: A dùng chấm, B dùng phẩy.',
          ),
        ),
      );
    }
    onParsing();
    await _checkpoint(cancel);
    return ImportOutcome.ready(
      InputSnapshot(
        id: '${artifact.id}-snapshot-${binding.revision}-${binding.attempt}',
        binding: binding,
        fields: fields,
        fullValidation: true,
        ocrReviewed: artifact.format.isImage,
        records: [
          for (var r = 0; r < values.length; r++)
            TableRecord(
              '${artifact.id}-row-$r',
              r,
              {
                for (var c = 0; c < fields.length; c++)
                  fields[c].id: SourceCell(
                    artifact.format.isImage ? CellKind.ocrText : CellKind.text,
                    rawLexeme: values[r][c],
                    ocrReviewed: true,
                  ),
              },
              {
                for (final f in fields)
                  f.id: 'fixture/${isA ? 'A' : 'B'}/record-${r + 1}/${f.id}',
              },
            ),
        ],
      ),
    );
  }
}

/// Bounded in-memory fixture comparator. Production UDG3.1 external-sort,
/// byte-credit queues, result stores and durable publication remain separate.
final class DemoComparisonPort implements ComparisonPort {
  @override
  List<WorkflowIssue> get startBlockers => const [];
  static const maxFixtureRecords = 10000;
  @override
  Future<ComparisonResult> compare(
    FrozenPlan plan,
    Cancellation cancel,
    void Function(String, int, int?) onProgress,
  ) async {
    if (plan.a.records.length > maxFixtureRecords ||
        plan.b.records.length > maxFixtureRecords) {
      throw const WorkflowIssue(
        'FIXTURE_LIMIT',
        'Nguồn vượt phạm vi bộ chạy mẫu.',
      );
    }
    await _checkpoint(cancel);
    onProgress('Ghép hàng mẫu', 0, null);
    final pairs = <(TableRecord, TableRecord)>[];
    final unmatchedA = <TableRecord>[];
    final unmatchedB = <TableRecord>[];
    final unresolved = <RecordUnresolved>[];
    if (plan.config.mode == MatchingMode.positional) {
      final common = plan.a.records.length < plan.b.records.length
          ? plan.a.records.length
          : plan.b.records.length;
      for (var i = 0; i < common; i++) {
        pairs.add((plan.a.records[i], plan.b.records[i]));
      }
      unmatchedA.addAll(plan.a.records.skip(common));
      unmatchedB.addAll(plan.b.records.skip(common));
    } else {
      final map = {for (final m in plan.config.mappings) m.fieldA: m.fieldB};
      final invalidA = <TableRecord>[];
      final invalidB = <TableRecord>[];
      Map<String, List<TableRecord>> group(
        List<TableRecord> rows,
        bool sideA,
        List<TableRecord> invalid,
      ) {
        final groups = <String, List<TableRecord>>{};
        for (final row in rows) {
          final tuple = <String>[];
          for (final field in plan.config.keys) {
            final cell = row.cells[sideA ? field : map[field]];
            if (cell == null ||
                (cell.kind != CellKind.text && cell.kind != CellKind.ocrText) ||
                (cell.kind == CellKind.ocrText && !cell.ocrReviewed) ||
                cell.rawLexeme == null ||
                cell.rawLexeme!.isEmpty) {
              break;
            }
            tuple.add(cell.rawLexeme!);
          }
          if (tuple.length != plan.config.keys.length || tuple.isEmpty) {
            invalid.add(row);
          } else {
            // JSON string-array framing is injective for this fixture subset.
            // This is not CE-1 encoding or digest identity.
            groups.putIfAbsent(jsonEncode(tuple), () => []).add(row);
          }
        }
        return groups;
      }

      final a = group(plan.a.records, true, invalidA);
      final b = group(plan.b.records, false, invalidB);
      if (invalidA.isNotEmpty || invalidB.isNotEmpty) {
        unresolved.add(
          RecordUnresolved(
            'KEY_INVALID',
            invalidA.map((r) => r.id),
            invalidB.map((r) => r.id),
          ),
        );
      }
      for (final key in {...a.keys, ...b.keys}) {
        await _checkpoint(cancel);
        final left = a[key] ?? const <TableRecord>[];
        final right = b[key] ?? const <TableRecord>[];
        if (left.length > 1 || right.length > 1) {
          unresolved.add(
            RecordUnresolved(
              'KEY_DUPLICATE',
              left.map((r) => r.id),
              right.map((r) => r.id),
            ),
          );
        } else if (left.isNotEmpty && right.isNotEmpty) {
          pairs.add((left.single, right.single));
        } else if ((left.isNotEmpty && invalidB.isNotEmpty) ||
            (right.isNotEmpty && invalidA.isNotEmpty)) {
          unresolved.add(
            RecordUnresolved(
              'ABSENCE_NOT_PROVEN_INVALID_KEYS',
              left.map((r) => r.id),
              right.map((r) => r.id),
            ),
          );
        } else {
          unmatchedA.addAll(left);
          unmatchedB.addAll(right);
        }
      }
      pairs.sort((x, y) => x.$1.ordinal.compareTo(y.$1.ordinal));
    }
    final cells = <CellDifference>[];
    final total = pairs.length * plan.config.mappings.length;
    onProgress('So sánh ô mẫu', 0, total);
    for (final pair in pairs) {
      for (final mapping in plan.config.mappings) {
        await _checkpoint(cancel);
        final a =
            pair.$1.cells[mapping.fieldA] ?? const SourceCell(CellKind.missing);
        final b =
            pair.$2.cells[mapping.fieldB] ?? const SourceCell(CellKind.missing);
        cells.add(
          CellDifference(
            id: '${plan.id}-cell-${cells.length}',
            rowA: pair.$1.id,
            rowB: pair.$2.id,
            mapping: mapping,
            a: a,
            b: b,
            locationA: pair.$1.locations[mapping.fieldA],
            locationB: pair.$2.locations[mapping.fieldB],
            decision: const SemanticPolicyEngine().compare(
              a,
              b,
              plan.config.rules[mapping.fieldA]!.compile(mapping.fieldA),
            ),
          ),
        );
        onProgress('So sánh ô mẫu', cells.length, total);
      }
    }
    final forward = plan.config.direction == ComparisonDirection.aToB;
    final structural = <StructuralChange>[
      for (final row in unmatchedA)
        StructuralChange(
          forward ? 'ROW_REMOVED' : 'ROW_ADDED',
          SourceSide.a,
          row.id,
        ),
      for (final row in unmatchedB)
        StructuralChange(
          forward ? 'ROW_ADDED' : 'ROW_REMOVED',
          SourceSide.b,
          row.id,
        ),
      for (final f in plan.a.fields.where(
        (f) => !plan.config.mappings.any((m) => m.fieldA == f.id),
      ))
        StructuralChange(
          forward ? 'FIELD_REMOVED' : 'FIELD_ADDED',
          SourceSide.a,
          f.id,
        ),
      for (final f in plan.b.fields.where(
        (f) => !plan.config.mappings.any((m) => m.fieldB == f.id),
      ))
        StructuralChange(
          forward ? 'FIELD_ADDED' : 'FIELD_REMOVED',
          SourceSide.b,
          f.id,
        ),
    ];
    onProgress('Kiểm tra đủ phạm vi mẫu', 0, null);
    if (pairs.length +
                unmatchedA.length +
                unresolved.fold<int>(0, (n, g) => n + g.recordsA.length) !=
            plan.a.records.length ||
        pairs.length +
                unmatchedB.length +
                unresolved.fold<int>(0, (n, g) => n + g.recordsB.length) !=
            plan.b.records.length ||
        cells.length != total) {
      throw const WorkflowIssue(
        'COVERAGE_FAILED',
        'Dữ liệu mẫu chưa được xử lý đầy đủ.',
      );
    }
    await _checkpoint(cancel);
    return ComparisonResult(
      id: '${plan.id}-result',
      plan: plan,
      cells: cells,
      structural: structural,
      unresolvedRecords: unresolved,
      matchedRecords: pairs.length,
    );
  }
}

/// Preview sink, never a user-owned file. No EX-1 success/capability claim.
final class DemoExportPort implements ExportPort {
  @override
  bool supports(ExportKind kind) => kind == ExportKind.jsonReport;
  @override
  Future<PreparedExport> render(
    ComparisonResult result,
    ExportRequest request,
    Cancellation cancel,
  ) async {
    await _checkpoint(cancel);
    if (!supports(request.kind)) {
      throw const WorkflowIssue(
        'EXPORT_CAPABILITY_DISABLED',
        'Chỉ có preview JSON mẫu.',
      );
    }
    final cells = result.cells
        .where(
          (c) =>
              request.selection == ExportSelection.fullComparison ||
              c.decision.status == DecisionStatus.different ||
              c.decision.status == DecisionStatus.unresolved,
        )
        .toList();
    final json = const JsonEncoder.withIndent('  ').convert({
      'format': 'dytava-fixture-preview/0.1',
      'preview_only': true,
      'result_id': result.id,
      'selection': request.selection.name,
      'direction': result.plan.config.direction.name,
      'full_counts': {
        for (final status in DecisionStatus.values)
          status.name: result.count(status),
      },
      'selected_cell_count': cells.length,
      'cells': [
        for (final c in cells)
          {
            'id': c.id,
            'field_a': c.mapping.fieldA,
            'field_b': c.mapping.fieldB,
            'status': c.decision.status.name,
            'raw_kind_a': c.a.kind.name,
            'raw_a': c.a.rawLexeme,
            'raw_kind_b': c.b.kind.name,
            'raw_b': c.b.rawLexeme,
            'canonical_a': c.decision.left?.label,
            'canonical_b': c.decision.right?.label,
            'rule': c.decision.ruleId,
            'reason': c.decision.reason?.name,
            'fixture_location_a': c.locationA,
            'fixture_location_b': c.locationB,
          },
      ],
      'structural': [
        for (final s in result.structural)
          {'kind': s.kind, 'side': s.side.name, 'record': s.recordId},
      ],
      'unresolved_records': [
        for (final g in result.unresolvedRecords)
          {'reason': g.reason, 'a': g.recordsA, 'b': g.recordsB},
      ],
    });
    return PreparedExport(json, cells.length);
  }

  @override
  Future<void> verify(PreparedExport pending, Cancellation cancel) async {
    await _checkpoint(cancel);
    final body = jsonDecode(pending.previewText) as Map<String, dynamic>;
    if (body['preview_only'] != true ||
        (body['cells'] as List).length != pending.selectedCellCount) {
      throw const WorkflowIssue(
        'EXPORT_VERIFICATION_FAILED',
        'Preview không khớp số ô đã chọn.',
      );
    }
  }

  @override
  Future<ExportReceipt> publish(
    PreparedExport pending,
    String attemptId,
    Cancellation cancel,
  ) async {
    await _checkpoint(cancel);
    return ExportReceipt(attemptId, pending.previewText, previewOnly: true);
  }

  @override
  Future<void> discard(PreparedExport? pending) async {}
}

/// Reserved for production composition. No permissive fallback to demo.
final class UnavailableComparisonPort implements ComparisonPort {
  @override
  List<WorkflowIssue> get startBlockers => const [
    WorkflowIssue(
      'CAPABILITY_NOT_VERIFIED',
      'Adapter và runtime Android chưa được kiểm chứng.',
    ),
    WorkflowIssue(
      'RESOURCE_PROFILE_NOT_ENABLED',
      'Chưa có resource profile Android được bật.',
    ),
  ];
  @override
  Future<ComparisonResult> compare(
    FrozenPlan plan,
    Cancellation cancel,
    void Function(String, int, int?) onProgress,
  ) async => throw startBlockers.first;
}
