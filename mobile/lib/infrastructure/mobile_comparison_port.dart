import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:excelcompare_core/excelcompare_core.dart';

import '../domain/workflow.dart';
import '../domain/workbook_comparison.dart';
import '../domain/smart_proposal_engine.dart';

/// Web engine pipeline on a native worker isolate, terminated on cancel/timeout.
final class MobileComparisonPort implements ComparisonPort {
  @override
  List<WorkflowIssue> get startBlockers => const [];
  @override
  Future<ComparisonResult> compare(
    FrozenPlan plan,
    Cancellation cancel,
    void Function(String, int, int?) onProgress,
  ) async {
    cancel.check();
    if (kIsWeb) {
      await Future<void>.delayed(Duration.zero);
      cancel.check();
      try {
        final result = compareMobileTables(plan, (phase, done, total) {
          if (!cancel.cancelled) {
            onProgress(phase, done, total);
          }
        });
        cancel.check();
        return result;
      } on WorkflowIssue {
        rethrow;
      } catch (e) {
        throw const WorkflowIssue(
          'COMPARE_FAILED',
          'Không xử lý được dữ liệu.',
        );
      }
    }
    final messages = ReceivePort();
    final errors = ReceivePort();
    final done = Completer<ComparisonResult>();
    final subscription = messages.listen((message) {
      if (done.isCompleted) return;
      if (cancel.cancelled) {
        done.completeError(const WorkCancelled());
        return;
      }
      if (message is ComparisonResult) {
        // Rebind to the original frozen plan: isolate transfer copies identity.
        done.complete(
          ComparisonResult(
            id: message.id,
            plan: plan,
            cells: message.cells,
            structural: message.structural,
            unresolvedRecords: message.unresolvedRecords,
            matchedRecords: message.matchedRecords,
            alignedRows: message.alignedRows,
            durationMs: message.durationMs,
            sheetResults: message.sheetResults,
            sheetPair: message.sheetPair,
            warnings: message.warnings,
          ),
        );
      } else if (message is WorkflowIssue) {
        done.completeError(message);
      } else if (message is List) {
        onProgress(message[0] as String, message[1] as int, message[2] as int?);
      }
    });
    final errorSub = errors.listen((error) {
      if (!done.isCompleted) {
        done.completeError(
          const WorkflowIssue('WORKER_FAILED', 'Bộ xử lý gặp lỗi.'),
        );
      }
    });
    Isolate? worker;
    final timer = Timer(const Duration(seconds: 30), () {
      if (!done.isCompleted) {
        done.completeError(
          const WorkflowIssue(
            'PROCESSING_TIMEOUT',
            'Tác vụ vượt 30 giây. Hãy chọn phạm vi nhỏ hơn hoặc ghép theo khóa.',
          ),
        );
      }
    });
    // Poll only cancellation, not work; the isolate is killed in finally.
    final cancellation = Timer.periodic(const Duration(milliseconds: 20), (_) {
      if (cancel.cancelled && !done.isCompleted) {
        done.completeError(const WorkCancelled());
      }
    });
    try {
      worker = await Isolate.spawn(_worker, (
        messages.sendPort,
        plan,
      ), onError: errors.sendPort);
      return await done.future;
    } finally {
      timer.cancel();
      cancellation.cancel();
      worker?.kill(priority: Isolate.immediate);
      await subscription.cancel();
      await errorSub.cancel();
      messages.close();
      errors.close();
    }
  }
}

void _worker((SendPort, FrozenPlan) input) {
  try {
    input.$1.send(
      compareMobileTables(
        input.$2,
        (phase, done, total) => input.$1.send([phase, done, total]),
      ),
    );
  } on WorkflowIssue catch (e) {
    input.$1.send(e);
  } catch (_) {
    input.$1.send(
      const WorkflowIssue('COMPARE_FAILED', 'Không xử lý được dữ liệu.'),
    );
  }
}

ComparisonResult _compareWorkbooks(
  FrozenPlan plan,
  void Function(String, int, int?) progress,
) {
  final watch = Stopwatch()..start(),
      a = workbookTables(plan.a),
      b = workbookTables(plan.b);
  final mapping = mapWorkbookSnapshots(
    plan.a,
    plan.b,
    overrides: plan.sheetOverrides,
  );
  if (!mapping.complete) {
    throw const WorkflowIssue(
      'SHEET_MAPPING_REQUIRED',
      'Cần chọn các cặp sheet chưa xác định được.',
    );
  }
  final results = <ComparisonResult>[];
  InputSnapshot empty(InputSnapshot other) => InputSnapshot(
    id: '${other.id}-absent',
    binding: other.binding,
    fields: const [],
    records: const [],
    fullValidation: true,
    ocrReviewed: false,
  );
  for (final pair in mapping.pairs) {
    final left = pair.a == null ? empty(b[pair.b!]) : a[pair.a!],
        right = pair.b == null ? empty(a[pair.a!]) : b[pair.b!];
    final inferred = SmartProposalEngine.analyze(left, right);
    final previewPair =
        left.sheetName == plan.a.sheetName &&
        right.sheetName == plan.b.sheetName;
    final inferredConfig = SmartProposalEngine.toConfiguration(
      inferred,
      direction: plan.config.direction,
    );
    final config = previewPair && pair.a != null && pair.b != null
        ? plan.config
        : ComparisonConfiguration(
            mappings: inferredConfig.mappings,
            rules: {
              for (final m in inferredConfig.mappings)
                m.fieldA:
                    plan.config.rules[m.fieldA] ??
                    inferredConfig.rules[m.fieldA]!,
            },
            mode:
                pair.a == null ||
                    pair.b == null ||
                    plan.config.mode == MatchingMode.positional
                ? MatchingMode.positional
                : inferredConfig.mode,
            keys: inferredConfig.keys,
            direction: plan.config.direction,
            webPolicy: plan.config.webPolicy,
            mappingConfirmed: true,
            modeConfirmed: true,
            policyConfirmed: true,
            directionConfirmed: true,
          );
    final scoped = FrozenPlan(
      '${plan.id}-${pair.id}',
      plan.revision,
      left,
      right,
      config,
    );
    final raw = compareMobileTables(
      scoped,
      (phase, done, total) => progress('${pair.label} · $phase', done, total),
    );
    final structural = [...raw.structural];
    if (pair.a == null || pair.b == null) {
      final added = plan.config.direction == ComparisonDirection.aToB
          ? pair.a == null
          : pair.b == null;
      structural.add(
        StructuralChange(
          added ? 'SHEET_ADDED' : 'SHEET_REMOVED',
          pair.a == null ? SourceSide.b : SourceSide.a,
          pair.nameA ?? pair.nameB!,
        ),
      );
    }
    results.add(
      ComparisonResult(
        id: raw.id,
        plan: scoped,
        cells: raw.cells,
        structural: structural,
        unresolvedRecords: raw.unresolvedRecords,
        matchedRecords: raw.matchedRecords,
        alignedRows: raw.alignedRows,
        durationMs: raw.durationMs,
        sheetPair: pair,
        warnings: [...left.warnings, ...right.warnings],
      ),
    );
  }
  return ComparisonResult(
    id: '${plan.id}-workbook',
    plan: plan,
    cells: results.expand((r) => r.cells),
    structural: results.expand((r) => r.structural),
    unresolvedRecords: results.expand((r) => r.unresolvedRecords),
    matchedRecords: results.fold(0, (n, r) => n + r.matchedRecords),
    alignedRows: results.expand((r) => r.alignedRows).toList(),
    durationMs: watch.elapsedMilliseconds,
    sheetResults: results,
    warnings: {...plan.a.warnings, ...plan.b.warnings}.toList(),
  );
}

typedef _Pair = (TableRecord?, TableRecord?, String, bool);

/// Same anchor + LIS + Needleman-Wunsch workflow as web; bounded cumulative DP.
/// Over-budget segments remain explicitly unresolved, never positional matches.
ComparisonResult compareMobileTables(
  FrozenPlan plan,
  void Function(String, int, int?) progress,
) {
  if (plan.a.workbookSheets.isNotEmpty || plan.b.workbookSheets.isNotEmpty) {
    return _compareWorkbooks(plan, progress);
  }
  final watch = Stopwatch()..start();
  final config = plan.config;
  final engine = WebCellEngine(config.webPolicy);
  final ordinals = <String>{};
  for (final m in config.mappings) {
    if (!WebCellEngine.isOrdinal(m.fieldA)) continue;
    final sample = [
      ...plan.a.records
          .take(25)
          .map((r) => r.cells[m.fieldA]?.rawLexeme?.trim() ?? ''),
      ...plan.b.records
          .take(25)
          .map((r) => r.cells[m.fieldB]?.rawLexeme?.trim() ?? ''),
    ].where((v) => v.isNotEmpty).toList();
    if (sample.isNotEmpty &&
        sample.every((v) => v == '-' || num.tryParse(v) != null)) {
      ordinals.add(m.fieldA);
    }
  }
  progress('Căn chỉnh hàng', 0, null);
  final pairs = <_Pair>[];
  if (config.mode == MatchingMode.orderedSequence) {
    pairs.addAll(_sequence(plan, ordinals));
  } else if (config.mode == MatchingMode.positional) {
    for (
      var i = 0;
      i < math.max(plan.a.records.length, plan.b.records.length);
      i++
    ) {
      pairs.add((
        i < plan.a.records.length ? plan.a.records[i] : null,
        i < plan.b.records.length ? plan.b.records[i] : null,
        'So sánh theo vị trí dòng',
        false,
      ));
    }
  } else {
    final fieldsB = {for (final m in config.mappings) m.fieldA: m.fieldB};
    Map<String, TableRecord> keyed(List<TableRecord> rows, bool sideA) {
      final map = <String, TableRecord>{};
      for (final row in rows) {
        final tuple = config.keys
            .map(
              (k) => row.cells[sideA ? k : fieldsB[k]]?.rawLexeme?.trim() ?? '',
            )
            .toList();
        final key = jsonEncode(tuple);
        if (tuple.isEmpty ||
            tuple.any((v) => v.isEmpty) ||
            map.containsKey(key)) {
          throw const WorkflowIssue(
            'KEY_INVALID',
            'Cột khóa có giá trị trống hoặc trùng. Chọn khóa duy nhất hoặc căn chỉnh chuỗi.',
          );
        }
        map[key] = row;
      }
      return map;
    }

    final a = keyed(plan.a.records, true), b = keyed(plan.b.records, false);
    for (final key in {...a.keys, ...b.keys}) {
      pairs.add((a[key], b[key], 'Ghép theo khóa định danh', false));
    }
  }
  final cells = <CellDifference>[];
  final aligned = <AlignedTableRow>[];
  final structural = <StructuralChange>[];
  final unresolved = <RecordUnresolved>[];
  final forward = config.direction == ComparisonDirection.aToB;
  var matched = 0;
  final mappedA = config.mappings.map((m) => m.fieldA).toSet(),
      mappedB = config.mappings.map((m) => m.fieldB).toSet();
  for (final f in plan.a.fields.where((f) => !mappedA.contains(f.id))) {
    structural.add(
      StructuralChange(
        forward ? 'FIELD_REMOVED' : 'FIELD_ADDED',
        SourceSide.a,
        f.id,
      ),
    );
  }
  for (final f in plan.b.fields.where((f) => !mappedB.contains(f.id))) {
    structural.add(
      StructuralChange(
        forward ? 'FIELD_ADDED' : 'FIELD_REMOVED',
        SourceSide.b,
        f.id,
      ),
    );
  }
  var processed = 0;
  for (final (a, b, rationale, unknown) in pairs) {
    final rowCells = <CellDifference>[];
    if (unknown) {
      unresolved.add(
        RecordUnresolved(
          'SEQUENCE_WORK_LIMIT',
          [if (a != null) a.id],
          [if (b != null) b.id],
        ),
      );
    } else if (a == null || b == null) {
      final side = a != null ? SourceSide.a : SourceSide.b;
      final added = forward ? b != null : a != null;
      structural.add(
        StructuralChange(
          added ? 'ROW_ADDED' : 'ROW_REMOVED',
          side,
          (a ?? b)!.id,
        ),
      );
    } else {
      matched++;
      void addCell(FieldMapping m, ComparisonDecision decision) {
        final cell = CellDifference(
          id: '${plan.id}-cell-${cells.length}',
          rowA: a.id,
          rowB: b.id,
          mapping: m,
          a: a.cells[m.fieldA] ?? const SourceCell(CellKind.missing),
          b: b.cells[m.fieldB] ?? const SourceCell(CellKind.missing),
          locationA: a.locations[m.fieldA],
          locationB: b.locations[m.fieldB],
          decision: decision,
        );
        cells.add(cell);
        rowCells.add(cell);
      }

      for (final m in config.mappings) {
        final rule = config.rules[m.fieldA]!;
        final left = a.cells[m.fieldA] ?? const SourceCell(CellKind.missing),
            right = b.cells[m.fieldB] ?? const SourceCell(CellKind.missing);
        final explicitEngine = WebCellEngine(
          WebComparisonPolicy(
            trimText: rule.trim,
            caseSensitiveText: config.webPolicy.caseSensitiveText,
            preserveLeadingZeros: config.webPolicy.preserveLeadingZeros,
            caseSensitiveIdentifier: config.webPolicy.caseSensitiveIdentifier,
            distinctNullZero: config.webPolicy.distinctNullZero,
          ),
        );
        var decision = rule.webAuto
            ? engine.compare(
                left,
                right,
                tolerance: double.tryParse(rule.tolerance) ?? 0,
              )
            : (rule.type == SemanticType.identifier ||
                  rule.type == SemanticType.freeText)
            ? explicitEngine.compare(
                left,
                right,
                explicitType: rule.type == SemanticType.identifier
                    ? 'identifier'
                    : 'text',
              )
            : const SemanticPolicyEngine().compare(
                left,
                right,
                rule.compile(m.fieldA),
              );
        if (ordinals.contains(m.fieldA) &&
            config.webPolicy.treatOrdinalAsMetadata &&
            decision.status == DecisionStatus.different &&
            left.kind != CellKind.image &&
            right.kind != CellKind.image &&
            left.kind != CellKind.unsupported &&
            right.kind != CellKind.unsupported) {
          decision = ComparisonDecision(
            status: DecisionStatus.equivalent,
            ruleId: 'metadata/ordinal_renumbered',
            explanation: 'Số thứ tự thay đổi do dịch chuyển hàng.',
            left: TextValue(left.rawLexeme ?? ''),
            right: TextValue(right.rawLexeme ?? ''),
          );
        }
        addCell(m, decision);
      }
      for (final f in plan.a.fields.where((f) => !mappedA.contains(f.id))) {
        addCell(
          FieldMapping(f.id, ''),
          ComparisonDecision(
            status: DecisionStatus.different,
            ruleId: 'schema/missing_column',
            explanation: 'Cột chỉ tồn tại ở nguồn A.',
            left: TextValue(a.cells[f.id]?.rawLexeme ?? ''),
            right: const TextValue(''),
          ),
        );
      }
      for (final f in plan.b.fields.where((f) => !mappedB.contains(f.id))) {
        addCell(
          FieldMapping('', f.id),
          ComparisonDecision(
            status: DecisionStatus.different,
            ruleId: 'schema/missing_column',
            explanation: 'Cột chỉ tồn tại ở nguồn B.',
            left: const TextValue(''),
            right: TextValue(b.cells[f.id]?.rawLexeme ?? ''),
          ),
        );
      }
    }
    aligned.add(
      AlignedTableRow(
        a,
        b,
        rationale,
        List.unmodifiable(rowCells),
        unresolved: unknown,
      ),
    );
    processed++;
    if (processed % 250 == 0 || processed == pairs.length) {
      progress('So sánh và chuẩn hóa ô', processed, pairs.length);
    }
  }
  return ComparisonResult(
    id: '${plan.id}-result',
    plan: plan,
    cells: cells,
    structural: structural,
    unresolvedRecords: unresolved,
    matchedRecords: matched,
    alignedRows: List.unmodifiable(aligned),
    durationMs: watch.elapsedMilliseconds,
  );
}

List<_Pair> _sequence(FrozenPlan plan, Set<String> ordinals) {
  final a = plan.a.records, b = plan.b.records;
  var fields = plan.config.mappings
      .where((m) => !ordinals.contains(m.fieldA))
      .toList();
  if (fields.isEmpty) fields = plan.config.mappings;
  List<String> values(TableRecord r, bool sideA) => fields
      .map((m) => r.cells[sideA ? m.fieldA : m.fieldB]?.rawLexeme?.trim() ?? '')
      .toList();
  final va = a.map((r) => values(r, true)).toList(),
      vb = b.map((r) => values(r, false)).toList();
  bool blank(List<String> r) => r.every((v) => v.isEmpty || v == '-');
  Map<String, List<int>> signatures(List<List<String>> rows) {
    final map = <String, List<int>>{};
    for (var i = 0; i < rows.length; i++) {
      if (!blank(rows[i])) {
        map.putIfAbsent(jsonEncode(rows[i]), () => []).add(i);
      }
    }
    return map;
  }

  final sa = signatures(va), sb = signatures(vb);
  final candidates = <(int, int)>[];
  for (final entry in sa.entries) {
    if (entry.value.length == 1 && sb[entry.key]?.length == 1) {
      candidates.add((entry.value.single, sb[entry.key]!.single));
    }
  }
  final tails = <int>[], parent = List.filled(candidates.length, -1);
  for (var k = 0; k < candidates.length; k++) {
    var low = 0, high = tails.length;
    while (low < high) {
      final mid = (low + high) ~/ 2;
      if (candidates[tails[mid]].$2 < candidates[k].$2) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    if (low > 0) parent[k] = tails[low - 1];
    if (low == tails.length) {
      tails.add(k);
    } else {
      tails[low] = k;
    }
  }
  final anchors = <(int, int)>[];
  var cursor = tails.isEmpty ? -1 : tails.last;
  while (cursor >= 0) {
    anchors.add(candidates[cursor]);
    cursor = parent[cursor];
  }
  final result = <_Pair>[];
  var states = 0;
  double similarity(int i, int j) {
    if (blank(va[i]) && blank(vb[j])) return 1;
    if (blank(va[i]) || blank(vb[j]) || fields.isEmpty) return 0;
    var count = 0.0;
    for (var c = 0; c < fields.length; c++) {
      final x = va[i][c], y = vb[j][c];
      if (x == y) {
        count++;
      } else if (x.toLowerCase() == y.toLowerCase()) {
        count += 0.9;
      } else if (num.tryParse(x) != null &&
          num.tryParse(x) == num.tryParse(y)) {
        count++;
      }
    }
    return count / fields.length;
  }

  void segment(int startA, int endA, int startB, int endB) {
    final m = endA - startA, n = endB - startB;
    if (m == 0 || n == 0) {
      for (var i = startA; i < endA; i++) {
        result.add((a[i], null, 'Dòng bị xóa ở nguồn A', false));
      }
      for (var j = startB; j < endB; j++) {
        result.add((null, b[j], 'Dòng thêm ở nguồn B', false));
      }
      return;
    }
    // Work budget counts columns too, cumulatively across all anchor segments.
    final work = m * n * math.max(1, fields.length);
    if (states + work > 400000) {
      for (var i = startA; i < endA; i++) {
        result.add((
          a[i],
          null,
          'Đoạn vượt ngân sách căn chỉnh; chưa xác định cặp hàng',
          true,
        ));
      }
      for (var j = startB; j < endB; j++) {
        result.add((
          null,
          b[j],
          'Đoạn vượt ngân sách căn chỉnh; chưa xác định cặp hàng',
          true,
        ));
      }
      return;
    }
    states += work.toInt();
    var prev = Float64List(n + 1), curr = Float64List(n + 1);
    final trace = Uint8List((m + 1) * (n + 1));
    for (var j = 0; j <= n; j++) {
      prev[j] = j.toDouble();
      trace[j] = 2;
    }
    for (var i = 1; i <= m; i++) {
      curr[0] = i.toDouble();
      trace[i * (n + 1)] = 1;
      for (var j = 1; j <= n; j++) {
        final sim = similarity(startA + i - 1, startB + j - 1);
        final sub = sim >= 0.5 ? 2 * (1 - sim) : 2.5;
        final diag = prev[j - 1] + sub,
            del = prev[j] + 1,
            ins = curr[j - 1] + 1;
        final best = math.min(diag, math.min(del, ins));
        curr[j] = best;
        trace[i * (n + 1) + j] = (sub < 2 && (best - diag).abs() < 1e-6)
            ? 0
            : (best - del).abs() < 1e-6
            ? 1
            : 2;
      }
      final temp = prev;
      prev = curr;
      curr = temp;
    }
    var i = m, j = n;
    final reverse = <_Pair>[];
    while (i > 0 || j > 0) {
      final direction = trace[i * (n + 1) + j];
      if (i > 0 && j > 0 && direction == 0) {
        reverse.add((
          a[startA + i - 1],
          b[startB + j - 1],
          'Khớp chuỗi tương đồng (${(similarity(startA + i - 1, startB + j - 1) * 100).round()}%)',
          false,
        ));
        i--;
        j--;
      } else if (i > 0 && (j == 0 || direction == 1)) {
        reverse.add((a[startA + i - 1], null, 'Dòng bị xóa ở nguồn A', false));
        i--;
      } else {
        reverse.add((null, b[startB + j - 1], 'Dòng thêm ở nguồn B', false));
        j--;
      }
    }
    result.addAll(reverse.reversed);
  }

  var i = 0, j = 0;
  for (final anchor in anchors.reversed) {
    segment(i, anchor.$1, j, anchor.$2);
    result.add((
      a[anchor.$1],
      b[anchor.$2],
      'Mốc chuỗi chính xác (Anchor)',
      false,
    ));
    i = anchor.$1 + 1;
    j = anchor.$2 + 1;
  }
  segment(i, a.length, j, b.length);
  return result;
}
