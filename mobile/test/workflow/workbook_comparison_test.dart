import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:archive/archive.dart';
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

  test(
    'merged cells blank non-anchor child cells, formulas normalize (=sum(A1;B2) == =SUM(A1,B2)) and shared formulas expand',
    () {
      final baseBytes = File('../tests/fixtures/workbook-a.xlsx').readAsBytesSync();
      final decoded = ZipDecoder().decodeBytes(baseBytes);
      final customSheetXml = '''
<?xml version="1.0" encoding="UTF-8"?>
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <sheetData>
    <row r="1">
      <c r="A1" t="inlineStr"><is><t>ID</t></is></c>
      <c r="B1" t="inlineStr"><is><t>MergedNote</t></is></c>
      <c r="C1" t="inlineStr"><is><t>ChildCol</t></is></c>
      <c r="D1" t="inlineStr"><is><t>FormulaCol</t></is></c>
      <c r="E1" t="inlineStr"><is><t>SharedCol</t></is></c>
    </row>
    <row r="2">
      <c r="A2" t="inlineStr"><is><t>001</t></is></c>
      <c r="B2" t="inlineStr"><is><t>AnchorOnly</t></is></c>
      <c r="C2" t="inlineStr"><is><t>DuplicateInChild</t></is></c>
      <c r="D2"><f>=sum(A2;B2)</f></c>
      <c r="E2"><f t="shared" ref="E2:E3" si="0">A2+B2</f></c>
    </row>
    <row r="3">
      <c r="A3" t="inlineStr"><is><t>002</t></is></c>
      <c r="B3" t="inlineStr"><is><t>Row3Note</t></is></c>
      <c r="C3" t="inlineStr"><is><t>Row3Child</t></is></c>
      <c r="D3" t="str"><f>_xlfn.CONCAT(A3;B3)</f><v></v></c>
      <c r="E3"><f t="shared" si="0"/></c>
    </row>
  </sheetData>
  <mergeCells count="1">
    <mergeCell ref="B2:C2"/>
  </mergeCells>
</worksheet>
''';

      final archive = Archive();
      for (final file in decoded.files) {
        if (file.name == 'xl/worksheets/sheet2.xml') {
          final bytes = utf8.encode(customSheetXml);
          archive.addFile(ArchiveFile(file.name, bytes.length, bytes));
        } else {
          archive.addFile(
            ArchiveFile(file.name, file.size, file.content),
          );
        }
      }
      final encoded = Uint8List.fromList(ZipEncoder().encode(archive)!);
      final info = MobileFileUploadService.processFileBytes(
        side: SourceSide.a,
        fileName: 'merged-formula.xlsx',
        bytes: encoded,
      );
      final snap = MobileFileUploadService.snapshot(
        info.privateRef,
        SourceArtifact(
          id: 'a',
          label: 'merged-formula.xlsx',
          format: SourceFormat.xlsx,
          privateRef: info.privateRef,
        ),
        const ImportBinding('a', 0, 0, 1),
      )!;
      final sheet2 = snap.workbookSheets.firstWhere(
        (s) => s.sheetName == 'Sheet2',
      );

      // 1. Merge cell B2:C2 keeps anchor B2 ('AnchorOnly') and blanks child C2 ('')
      expect(sheet2.records[0].cells['MergedNote']!.rawLexeme, 'AnchorOnly');
      expect(sheet2.records[0].cells['ChildCol']!.rawLexeme, '');
      expect(
        sheet2.warnings.any((w) => w.contains('ô gộp')),
        isTrue,
      );

      // 2. Formula with semicolons `=sum(A2;B2)` and `_xlfn.CONCAT(A3;B3)` normalizes nicely
      expect(
        sheet2.records[0].cells['FormulaCol']!.rawLexeme,
        '=sum(A2,B2)',
      );
      expect(
        sheet2.records[1].cells['FormulaCol']!.rawLexeme,
        '=CONCAT(A3,B3)',
      );

      // 3. Shared formula child E3 (`<f t="shared" si="0"/>`) expands relative row ref A2+B2 → A3+B3
      expect(
        sheet2.records[0].cells['SharedCol']!.rawLexeme,
        '=A2+B2',
      );
      expect(
        sheet2.records[1].cells['SharedCol']!.rawLexeme,
        '=A3+B3',
      );

      // 4. WebCellEngine compares `=sum(A1;B2)` and `=SUM(A1, B2)` as EQUIVALENT
      const engine = WebCellEngine();
      final decision = engine.compare(
        const SourceCell(CellKind.text, rawLexeme: '=sum(A1;B2)'),
        const SourceCell(CellKind.text, rawLexeme: '=SUM(A1, B2)'),
      );
      expect(decision.status, DecisionStatus.equivalent);
      expect(decision.ruleId, 'formula/syntax_normalized');
    },
  );
}
