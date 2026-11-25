import 'dart:convert';
import 'dart:ui';

import 'package:dytava/app/workflow_composition.dart';
import 'package:dytava/domain/workflow.dart';
import 'package:dytava/infrastructure/file_upload_service.dart';
import 'package:dytava/infrastructure/database/comparison_database.dart';
import 'package:dytava/ocr/domain/ocr_models.dart';
import 'package:dytava/ocr/domain/ocr_session.dart';
import 'package:dytava/ocr/infrastructure/mlkit_ocr_adapter.dart';
import 'package:dytava/ocr/infrastructure/ocr_capture_service.dart';
import 'package:excelcompare_core/excelcompare_core.dart';
import 'package:flutter_test/flutter_test.dart' hide ComparisonResult;
import 'package:integration_test/integration_test.dart';
import 'package:sqflite/sqflite.dart';

// Explicit fixture decimal convention; does not change comparison policies.
bool _sameFixtureValue(String actual, String expected) {
  if (actual == expected) return true;
  if (actual.isEmpty || expected.isEmpty) return false;
  final a = double.tryParse(actual.replaceAll(',', '.'));
  final b = double.tryParse(expected.replaceAll(',', '.'));
  return a != null && b != null && (a - b).abs() < 1e-9;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(
    () => ComparisonDatabase.instance.init(
      customPath: inMemoryDatabasePath,
      customFactory: databaseFactory,
    ),
  );
  tearDownAll(() => ComparisonDatabase.instance.close());
  testWidgets('Real Coefficients crop retains blank cells and wrapped headers', (
    tester,
  ) async {
    final session = OcrSession(
      port: MlKitOcrRecognitionAdapter(),
      label: 'coefficients.jpg',
      rawBytes: base64Decode(const String.fromEnvironment('OCR_IMAGE_BASE64')),
    );
    addTearDown(session.dispose);
    await session.confirmTableBboxAndRecognize(
      normalizedBbox: const Rect.fromLTRB(
        30 / 1327,
        25 / 805,
        1045 / 1327,
        400 / 805,
      ),
    );
    expect(session.error, isNull);
    // ignore: avoid_print
    print(
      'COEFFICIENTS_GRID:${jsonEncode([
        for (final row in session.grid.cells) [for (final cell in row) cell.recognizedText],
      ])}',
    );
    expect(session.grid.columnCount, 9);
    expect(session.grid.rowCount, 8);
    expect(session.grid.cells[0][4].recognizedText, 'Beta');
    expect(session.grid.cells[1][1].recognizedText, '(Constant)');
    expect(session.grid.cells[1][4].recognizedText, isNull);
    expect(session.grid.cells[1][7].recognizedText, isNull);
    expect(session.grid.cells[1][8].recognizedText, isNull);
  });
  for (final scale in [2]) {
    testWidgets('Real ML Kit image-to-XLSX workflow (${scale}x)', (
      tester,
    ) async {
      const encodedImage = String.fromEnvironment('OCR_IMAGE_BASE64');
      const encodedWorkbook = String.fromEnvironment('OCR_WORKBOOK_BASE64');
      expect(
        encodedImage,
        isNotEmpty,
        reason: 'Run python3 tool/run_ocr_device_test.py',
      );
      expect(encodedWorkbook, isNotEmpty);
      final flow = createMobileWorkflow();
      addTearDown(flow.dispose);
      addTearDown(OcrCaptureService.clear);
      addTearDown(MobileFileUploadService.clear);
      final workbook = MobileFileUploadService.processFileBytes(
        side: SourceSide.b,
        fileName: 'collinearity.xlsx',
        bytes: base64Decode(encodedWorkbook),
      );
      await flow.selectSource(
        SourceSide.b,
        workbook.format,
        workbook.privateRef,
        workbook.fileName,
      );
      await flow.importSource(SourceSide.b);
      expect(flow.slot(SourceSide.b).ready, isTrue);
      final expected = flow.slot(SourceSide.b).snapshot!;
      expect(expected.records.length, 7);
      expect(expected.fields.length, 11);
      final registered = OcrCaptureService.registerSession(
        side: SourceSide.a,
        fileName: 'spss_tables.jpg',
        format: SourceFormat.jpeg,
        rawBytes: base64Decode(encodedImage),
        port: MlKitOcrRecognitionAdapter(),
      );
      await flow.selectSource(
        SourceSide.a,
        registered.format,
        registered.privateRef,
        registered.fileName,
      );
      await flow.importSource(SourceSide.a);
      expect(flow.slot(SourceSide.a).ready, isFalse);
      final session = OcrCaptureService.session(registered.privateRef)!;
      await session.confirmTableBboxAndRecognize(
        normalizedBbox: const Rect.fromLTRB(
          30 / 1327,
          440 / 805,
          1210 / 1327,
          790 / 805,
        ),
      );
      expect(session.error, isNull);
      expect(session.grid.columnCount, 11);
      expect(session.grid.rowCount, 8);
      expect(session.grid.hasHeader, isTrue);
      expect(session.readyToNormalize, isFalse);
      expect(
        session.grid.cells.first.map((cell) => cell.recognizedText),
        expected.fields.map((field) => field.label),
      );
      final mismatches = <Map<String, Object>>[];
      for (var r = 0; r < 7; r++) {
        for (var c = 0; c < 11; c++) {
          final wanted =
              expected.records[r].cells[expected.fields[c].id]!.rawLexeme ?? '';
          final actual = session.currentText(OcrCellRef(r + 1, c));
          if (!_sameFixtureValue(actual, wanted)) {
            expect(
              session.grid.cells[r + 1][c].risks,
              isNotEmpty,
              reason: 'A misread fixture value must remain visible for review.',
            );
            mismatches.add({
              'row': r + 1,
              'column': c + 1,
              'actual': actual,
              'expected': wanted,
            });
          }
        }
      }
      // ignore: avoid_print
      print(
        'OCR_METRICS:${jsonEncode({'scale': scale, 'correct': 77 - mismatches.length, 'total': 77, 'mismatches': mismatches})}',
      );
      expect(77 - mismatches.length, greaterThanOrEqualTo(71));
      final rawRecognized = [
        for (final row in session.grid.cells.skip(1))
          [for (final cell in row) cell.recognizedText],
      ];
      // Explicitly simulated human correction, separate from OCR accuracy.
      for (var c = 0; c < 11; c++) {
        session.editCellText(OcrCellRef(0, c), expected.fields[c].label);
        for (var r = 0; r < 7; r++) {
          session.editCellText(
            OcrCellRef(r + 1, c),
            expected.records[r].cells[expected.fields[c].id]!.rawLexeme ?? '',
          );
        }
      }
      session.approveTableForImport();
      expect(session.readyToNormalize, isTrue);
      final table = OcrCaptureService.commitFinalized(registered.privateRef);
      expect(table.rows.length, 7);
      expect([
        for (final row in table.rows)
          [for (final cell in row) cell.recognizedText],
      ], rawRecognized);
      for (final row in table.rows) {
        for (final cell in row) {
          for (final point in cell.polygon) {
            expect(point.x, inInclusiveRange(0, 1326));
            expect(point.y, inInclusiveRange(440, 790));
          }
        }
      }
      await flow.changeImportConfig(
        SourceSide.a,
        ImportConfiguration(
          scopeConfirmed: true,
          ocrRevision: session.gridRevision,
          reviewedCells: {
            for (final ref in session.receipts.keys) ref.toString(),
          },
        ),
      );
      await flow.importSource(SourceSide.a);
      expect(flow.inputsReady, isTrue);
      flow.analyzeAndPropose();
      flow.applyProposal();
      flow.configure(
        flow.config.copyWith(
          mappingConfirmed: true,
          modeConfirmed: true,
          policyConfirmed: true,
          directionConfirmed: true,
        ),
      );
      await flow.runComparison();
      expect(flow.resultCurrent, isTrue);
      expect(flow.result!.count(DecisionStatus.different), 0);
      expect(flow.result!.count(DecisionStatus.unresolved), 0);
      expect(flow.result!.cells.length, 77);
    });
  }
}
