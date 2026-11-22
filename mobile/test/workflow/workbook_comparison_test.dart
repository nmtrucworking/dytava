import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:excel/excel.dart' as xlsx;
import 'package:dytava/design_system/design_system.dart';
import 'package:dytava/features/workflow/screens/results_and_detail_view.dart';
import 'package:excelcompare_core/excelcompare_core.dart';
import 'package:dytava/app/workflow_composition.dart';
import 'package:dytava/domain/workflow.dart';
import 'package:dytava/domain/workbook_comparison.dart';
import 'package:dytava/infrastructure/file_upload_service.dart';
import 'package:dytava/infrastructure/mobile_comparison_port.dart';
import 'package:dytava/infrastructure/mobile_export_port.dart';

InputSnapshot load(String name, SourceSide side) {
  final info = MobileFileUploadService.processFileBytes(
    side: side,
    fileName: name,
    bytes: Uint8List.fromList(
      File('../tests/fixtures/$name').readAsBytesSync(),
    ),
  );
  final artifact = SourceArtifact(
    id: side.name,
    privateRef: info.privateRef,
    label: name,
    format: SourceFormat.xlsx,
  );
  return MobileFileUploadService.snapshot(
    info.privateRef,
    artifact,
    ImportBinding(side.name, 0, 0, 1),
  )!;
}

ComparisonConfiguration config() => ComparisonConfiguration(
  mappings: const [
    FieldMapping('ProductID', 'ProductID'),
    FieldMapping('Photo', 'Photo'),
    FieldMapping('Cost', 'Cost'),
  ],
  rules: {
    for (final h in ['ProductID', 'Photo', 'Cost'])
      h: const FieldRule(type: SemanticType.freeText, webAuto: true),
  },
  mode: MatchingMode.positional,
  mappingConfirmed: true,
  modeConfirmed: true,
  policyConfirmed: true,
  directionConfirmed: true,
);
void main() {
  tearDown(MobileFileUploadService.clear);
  test('workbook inventory includes hidden/empty tabs and maps swapped default sheet labels by structure', () {
    final a = load('workbook-a.xlsx', SourceSide.a),
        b = load('workbook-b.xlsx', SourceSide.b);
    expect(a.workbookSheets.length, 4);
    expect(b.workbookSheets.length, 5);
    final mapping = mapWorkbookSnapshots(a, b);
    expect(mapping.complete, isTrue);
    expect(
      mapping.pairs.firstWhere((p) => p.nameA == 'Sheet1').nameB,
      'Sheet2',
    );
    final output = compareMobileTables(
      FrozenPlan('p', 1, a, b, config()),
      (_, _, _) {},
    );
    expect(output.sheetResults.length, 5);
    expect(output.count(DecisionStatus.different), 2);
    expect(output.cells.length, 11);
    expect(
      output.structural.where((s) => s.kind == 'SHEET_ADDED').single.recordId,
      'New empty',
    );
    final products = output.sheetResults.firstWhere(
      (r) => r.sheetPair!.nameA == 'Sheet1',
    );
    expect(
      products.cells
          .firstWhere((c) => c.mapping.fieldA == 'Photo')
          .decision
          .status,
      DecisionStatus.exact,
    );
    expect(
      products.cells
          .where((c) => c.mapping.fieldA == 'Photo')
          .last
          .decision
          .status,
      DecisionStatus.different,
    );
    expect(products.cells.first.locationA, 'Sheet1!A2');
    expect(products.cells.first.locationB, 'Sheet2!A2');
    final report = jsonDecode(
      renderMobileReport(
        output,
        const ExportRequest(
          ExportKind.jsonReport,
          ExportSelection.fullComparison,
        ),
      ).previewText,
    ) as Map;
    expect(report['sheets'].length, 5);
    expect(report['scope'], 'ALL_WORKSHEETS');
    final csv = renderMobileReport(
      output,
      const ExportRequest(ExportKind.csvDiff, ExportSelection.fullComparison),
    ).previewText;
    expect(csv, contains('"sheet_a","sheet_b"'));
    expect(csv, contains('"Sheet1","Sheet2","CELL"'));
    expect(csv, contains('SHEET_ADDED'));
  });
  test(
    'missing image content stays unresolved for equal cached #VALUE! cells',
    () {
      final a = load('workbook-broken.xlsx', SourceSide.a);
      final output = compareMobileTables(
        FrozenPlan('p', 1, a, a, config()),
        (_, _, _) {},
      );
      expect(output.count(DecisionStatus.unresolved), 1);
      expect(
        output.cells
            .firstWhere((c) => c.decision.status == DecisionStatus.unresolved)
            .decision
            .ruleId,
        'content/unsupported',
      );
    },
  );
  test('mapping ties require user choice and cannot reuse a counterpart', () {
    final a = [
      SheetDescriptor('Sheet1', ['id']),
      SheetDescriptor('Sheet2', ['id']),
    ];
    expect(mapSheets(a, a).complete, isFalse);
    expect(mapSheets(a, a, overrides: [('Sheet1', 'Sheet2')]).complete, isTrue);
    expect(
      () => mapSheets(
        a,
        a,
        overrides: [('Sheet1', 'Sheet2'), ('Sheet2', 'Sheet2')],
      ),
      throwsFormatException,
    );
  });
  test('controller imports all worksheets, aligns previews, runs all and filters without rerunning', () async {
    final flow = createMobileWorkflow();
    addTearDown(flow.dispose);
    for (final side in SourceSide.values) {
      final name = side == SourceSide.a ? 'workbook-a.xlsx' : 'workbook-b.xlsx';
      final info = MobileFileUploadService.processFileBytes(
        side: side,
        fileName: name,
        bytes: Uint8List.fromList(
          File('../tests/fixtures/$name').readAsBytesSync(),
        ),
      );
      await flow.selectSource(
        side,
        info.format,
        info.privateRef,
        info.fileName,
      );
      await flow.importSource(side);
    }
    expect(flow.inputsReady, isTrue);
    expect(flow.sheetMapping!.complete, isTrue);
    flow.applyProposal();
    flow.configure(
      flow.config.copyWith(mode: MatchingMode.positional, keys: const []),
    );
    await flow.runComparison();
    expect(flow.resultCurrent, isTrue, reason: flow.issue?.message);
    expect(flow.result!.sheetResults.length, 5);
    final id = flow.result!.id;
    flow.selectResultSheet(
      flow.result!.sheetResults
          .firstWhere((r) => r.sheetPair!.nameA == 'Sheet1')
          .sheetPair!
          .id,
    );
    expect(flow.displayedResult!.cells.length, 6);
    expect(flow.selectedCells.length, 6);
    expect(flow.result!.id, id);
    flow.selectResultSheet(null);
    expect(flow.selectedCells.length, flow.result!.cells.length);
  });
  test('empty workbooks and added empty sheets complete without field-mapping blockers', () async {
    final flow = createMobileWorkflow();
    addTearDown(flow.dispose);
    for (final side in SourceSide.values) {
      final wb = xlsx.Excel.createExcel();
      wb.rename('Sheet1', 'Empty');
      if (side == SourceSide.b) wb['New empty'];
      final info = MobileFileUploadService.processFileBytes(
        side: side,
        fileName: 'empty.xlsx',
        bytes: Uint8List.fromList(wb.save()!),
      );
      await flow.selectSource(
        side,
        info.format,
        info.privateRef,
        info.fileName,
      );
      await flow.importSource(side);
    }
    expect(flow.structuralWorkbookOnly, isTrue);
    flow.applyProposal();
    await flow.runComparison();
    expect(flow.resultCurrent, isTrue, reason: flow.issue?.message);
    expect(flow.result!.sheetResults.length, 2);
    expect(
      flow.result!.structural.where((s) => s.kind == 'SHEET_ADDED').length,
      1,
    );
  });
  testWidgets(
    'results show all sheet groups and switch to one pair without replacing the result',
    (tester) async {
      final a = load('workbook-a.xlsx', SourceSide.a),
          b = load('workbook-b.xlsx', SourceSide.b);
      final flow = createMobileWorkflow();
      addTearDown(flow.dispose);
      final result = compareMobileTables(
        FrozenPlan('widget', 1, a, b, config()),
        (_, _, _) {},
      );
      flow.result = result;
      flow.validity = ResultValidity.current;
      flow.jobState = JobState.completed;
      await tester.pumpWidget(
        MaterialApp(
          theme: DytavaTheme.lightTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: AnimatedBuilder(
                animation: flow,
                builder: (context, _) => ResultsScreenView(
                  flow: flow,
                  resultViewTab: 2,
                  onResultViewTabChanged: (_) {},
                  onOpenDetail: (_) {},
                  onOpenExport: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('All sheets (${result.sheetResults.length})'), findsOneWidget);
      final products = result.sheetResults.firstWhere(
        (r) => r.sheetPair!.nameA == 'Sheet1',
      );
      await tester.tap(find.byType(DropdownButton<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(products.sheetPair!.label).last);
      await tester.pumpAndSettle();
      expect(flow.displayedResult, same(products));
      expect(flow.result, same(result));
      expect(tester.takeException(), isNull);
    },
  );
}
