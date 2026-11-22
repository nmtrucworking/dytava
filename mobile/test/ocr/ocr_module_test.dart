import 'dart:convert';
import 'dart:typed_data';

import 'package:dytava/app/workflow_composition.dart';
import 'package:dytava/design_system/design_system.dart';
import 'package:dytava/domain/workflow.dart';
import 'package:dytava/features/workflow/workflow_page.dart';
import 'package:dytava/infrastructure/file_upload_service.dart';
import 'package:dytava/ocr/domain/ocr_models.dart';
import 'package:dytava/ocr/domain/ocr_session.dart';
import 'package:dytava/ocr/domain/ocr_table_reconstructor.dart';
import 'package:dytava/ocr/domain/vietnamese_text.dart';
import 'package:dytava/ocr/infrastructure/mlkit_ocr_adapter.dart';
import 'package:dytava/ocr/infrastructure/ocr_capture_service.dart';
import 'package:dytava/ocr/infrastructure/ocr_image_preprocessor.dart';
import 'package:excelcompare_core/excelcompare_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart' hide ComparisonResult;
import 'package:image/image.dart' as img;

Uint8List _testPng({int width = 320, int height = 200}) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(245, 248, 246));
  img.fillRect(
    image,
    x1: 20,
    y1: 20,
    x2: width - 20,
    y2: height - 20,
    color: img.ColorRgb8(16, 124, 65),
  );
  return Uint8List.fromList(img.encodePng(image));
}

void main() {
  tearDown(() {
    OcrCaptureService.clear();
    MobileFileUploadService.clear();
  });

  group('VietnameseText NFC & diacritics', () {
    test('normalizes decomposed NFD Vietnamese tones & circumflexes to NFC', () {
      const decomposed =
          'Đo\u031Bn ha\u0300ng xu\u0061\u0302\u0301t kh\u0061\u0302\u0309u';
      expect(VietnameseText.nfc(decomposed), 'Đơn hàng xuất khẩu');
      expect(VietnameseText.hasVietnameseMarks('Đơn hàng xuất khẩu'), isTrue);
      expect(
        VietnameseText.hasDiacriticAnomaly('Đơn hàng xuất khẩu'),
        isFalse,
      );
    });

    test('detects stacked or misplaced tone marks on consonants', () {
      expect(VietnameseText.hasDiacriticAnomaly('a\u0300\u0301'), isTrue);
      expect(VietnameseText.hasDiacriticAnomaly('t\u0301a'), isTrue);
    });
  });

  group('OcrImagePreprocessor & OcrGeometry', () {
    test(
      'OCR-TC-005: rotation, perspective rectification and inverse polygon mapping stay within bounds',
      () {
        final raw = _testPng(width: 400, height: 240);
        final processed = OcrImagePreprocessor.processSync(
          raw,
          const OcrPreprocessSettings(
            quarterTurns: 1,
            corners: [
              OcrPoint(10, 15),
              OcrPoint(220, 18),
              OcrPoint(225, 380),
              OcrPoint(12, 375),
            ],
            enhanceContrast: true,
          ),
        );
        expect(processed.geometry.orientedWidth, 400);
        expect(processed.geometry.orientedHeight, 240);
        expect(processed.geometry.rotatedWidth, 240);
        expect(processed.geometry.rotatedHeight, 400);

        final cellPolygon = [
          const OcrPoint(0, 0),
          OcrPoint(processed.geometry.outputWidth - 1, 0),
          OcrPoint(
            processed.geometry.outputWidth - 1,
            processed.geometry.outputHeight - 1,
          ),
          OcrPoint(0, processed.geometry.outputHeight - 1),
        ];
        final orientedPoly = processed.geometry.polygonToOriented(cellPolygon);
        expect(orientedPoly, hasLength(4));
        for (final pt in orientedPoly) {
          expect(pt.x, inInclusiveRange(0, 399));
          expect(pt.y, inInclusiveRange(0, 239));
        }
      },
    );
  });

  group('OcrTableReconstructor, OcrDetectionState & OcrSession gates', () {
    test(
      'distinguishes noTextDetected, textWithoutTable and tableDetected states',
      () async {
        // 1. noTextDetected (e.g., sample_avatar.png with 0 tokens)
        final emptySession = OcrSession(
          port: const SampleVietnameseOcrRecognitionAdapter(customTokens: []),
          label: 'sample_avatar.png',
          rawBytes: _testPng(),
        );
        addTearDown(emptySession.dispose);
        await emptySession.runRecognition();
        expect(emptySession.detectionState, OcrDetectionState.noTextDetected);
        expect(emptySession.grid.cellCount, 0);

        // User chooses "Tạo bảng thủ công"
        emptySession.createManualTable(rows: 3, columns: 2);
        expect(emptySession.detectionState, OcrDetectionState.tableDetected);
        expect(emptySession.grid.rowCount, 3);
        expect(emptySession.grid.columnCount, 2);

        // 2. textWithoutTable (single isolated phrase, 1 row x 1 col)
        final singlePhraseSession = OcrSession(
          port: const SampleVietnameseOcrRecognitionAdapter(
            customTokens: [
              OcrToken(
                text: 'Ảnh chân dung nhân sự',
                polygon: [
                  OcrPoint(20, 20),
                  OcrPoint(180, 20),
                  OcrPoint(180, 44),
                  OcrPoint(20, 44),
                ],
                confidence: 0.96,
                lineIndex: 0,
              ),
            ],
          ),
          label: 'note.png',
          rawBytes: _testPng(),
        );
        addTearDown(singlePhraseSession.dispose);
        await singlePhraseSession.runRecognition();
        expect(
          singlePhraseSession.detectionState,
          OcrDetectionState.textWithoutTable,
        );
      },
    );

    test(
      'OCR-TC-001/002/003/004/006: grid confirmation precedes cell receipts; crop/grid edits invalidate receipts; leading zeros preserved',
      () async {
        final session = OcrSession(
          port: const SampleVietnameseOcrRecognitionAdapter(),
          label: 'bang_tieng_viet.png',
          rawBytes: _testPng(),
        );
        addTearDown(session.dispose);

        await session.runRecognition();
        expect(session.stage, OcrPipelineStage.gridStructure);
        expect(session.detectionState, OcrDetectionState.tableDetected);
        expect(session.grid.rowCount, 5);
        expect(session.grid.columnCount, 3);
        expect(session.grid.hasHeader, isTrue);

        // Cannot confirm a cell before confirming grid structure
        session.confirmCell(const OcrCellRef(0, 0));
        expect(session.isCellConfirmed(const OcrCellRef(0, 0)), isFalse);
        expect(session.readyToNormalize, isFalse);

        // Confirm grid structure first (with autoConfirmCleanCells: true)
        session.confirmGridStructure(autoConfirmCleanCells: true);
        expect(session.gridConfirmed, isTrue);
        expect(session.stage, OcrPipelineStage.cellReview);
        // Clean cells are automatically pre-confirmed; flagged cells still require confirmation
        expect(session.confirmedCellCount, greaterThan(0));
        expect(session.readyToNormalize, isFalse);

        // Confirm remaining flagged cells
        session.confirmAllCells();
        expect(session.readyToNormalize, isTrue);

        // Leading zeros ("001") and NFC Vietnamese text preserved
        final table1 = session.finalizeTable();
        expect(table1.headers, ['Mã', 'Khoản mục', 'Giá trị']);
        expect(table1.rows.first[0].reviewedText, '001');
        expect(table1.rows.first[1].reviewedText, 'Đơn hàng xuất khẩu');

        // Insert an empty row (no OCR detection) → invalidates all receipts
        session.insertRow(session.grid.rowCount);
        expect(session.gridConfirmed, isFalse);
        expect(session.confirmedCellCount, 0);
        expect(session.readyToNormalize, isFalse);

        // Confirm new grid and enter user text for the missing detection
        session.confirmGridStructure();
        final lastRow = session.grid.rowCount - 1;
        session.saveAndConfirmCell(OcrCellRef(lastRow, 0), '005');
        session.saveAndConfirmCell(
          OcrCellRef(lastRow, 1),
          'Phu\u0323 phi\u0301 kiê\u0309m đi\u0323nh',
        );
        session.saveAndConfirmCell(OcrCellRef(lastRow, 2), '12.5');
        session.confirmAllCells();
        expect(session.readyToNormalize, isTrue);
        final table2 = session.finalizeTable();
        expect(table2.rows.last[0].reviewedText, '005');
        expect(table2.rows.last[0].recognizedText, isNull);
        expect(table2.rows.last[0].origin, OcrCorrectionOrigin.userEntered);
        expect(table2.rows.last[1].reviewedText, 'Phụ phí kiểm định');

        // Changing preprocess settings invalidates extraction & receipts
        await session.updatePreprocess(
          session.settings.copyWith(quarterTurns: 1),
        );
        expect(session.readyToNormalize, isFalse);
        expect(session.confirmedCellCount, 0);
      },
    );

    test(
      'OCR-TC-003: row missing a cell raises rowShape and blank risks without shifting cells',
      () {
        final tokens = [
          const OcrToken(
            text: 'Mã',
            polygon: [
              OcrPoint(10, 10),
              OcrPoint(50, 10),
              OcrPoint(50, 30),
              OcrPoint(10, 30),
            ],
            confidence: 0.99,
            lineIndex: 0,
          ),
          const OcrToken(
            text: 'Tên',
            polygon: [
              OcrPoint(120, 10),
              OcrPoint(170, 10),
              OcrPoint(170, 30),
              OcrPoint(120, 30),
            ],
            confidence: 0.99,
            lineIndex: 0,
          ),
          const OcrToken(
            text: 'Số tiền',
            polygon: [
              OcrPoint(260, 10),
              OcrPoint(320, 10),
              OcrPoint(320, 30),
              OcrPoint(260, 30),
            ],
            confidence: 0.99,
            lineIndex: 0,
          ),
          const OcrToken(
            text: '001',
            polygon: [
              OcrPoint(10, 60),
              OcrPoint(50, 60),
              OcrPoint(50, 80),
              OcrPoint(10, 80),
            ],
            confidence: 0.99,
            lineIndex: 1,
          ),
          const OcrToken(
            text: '150',
            polygon: [
              OcrPoint(260, 60),
              OcrPoint(310, 60),
              OcrPoint(310, 80),
              OcrPoint(260, 80),
            ],
            confidence: 0.99,
            lineIndex: 1,
          ),
        ];
        final grid = OcrTableReconstructor.reconstruct(tokens);
        expect(grid.rowCount, 2);
        expect(grid.columnCount, 3);
        expect(grid.cells[1][0].recognizedText, '001');
        expect(grid.cells[1][1].recognizedText, isNull);
        expect(
          grid.cells[1][1].risks,
          containsAll([OcrRisk.blank, OcrRisk.rowShape]),
        );
        expect(grid.cells[1][2].recognizedText, '150');
      },
    );

    test(
      'SPSS / academic multi-level header tables (Coefficients & Collinearity Diagnostics) prune title banners/footnotes and align leaf columns accurately',
      () {
        OcrToken tok(String text, double x, double y, double w, int line) =>
            OcrToken(
              text: text,
              polygon: [
                OcrPoint(x, y),
                OcrPoint(x + w, y),
                OcrPoint(x + w, y + 18),
                OcrPoint(x, y + 18),
              ],
              confidence: 0.96,
              lineIndex: line,
            );

        // Simulated OCR tokens from the uploaded SPSS "Coefficients^a" table:
        // - Title banner ("Coefficients^a")
        // - Multi-column super-header ("Unstandardized Coefficients", "Standardized Coefficients", "Collinearity Statistics")
        // - Leaf header row (Model, Variable, B, Std. Error, Beta, t, Sig., Tolerance, VIF)
        // - Data rows with missing cells in row 1 (Constant has no Beta/Tolerance/VIF) and leading-comma decimals (",829", ",142")
        // - Trailing footnote ("a. Dependent Variable: HL")
        const xCols = [20.0, 90.0, 190.0, 270.0, 360.0, 440.0, 510.0, 590.0, 670.0];
        final spssTokens = <OcrToken>[
          // Title banner (line 0)
          tok('Coefficientsa', 320, 10, 110, 0),
          // Super-header row (line 1) — spans multiple columns
          tok('Unstandardized Coefficients', 180, 40, 155, 1),
          tok('Standardized Coefficients', 350, 40, 130, 1),
          tok('Collinearity Statistics', 580, 40, 140, 1),
          // Leaf header row (line 2)
          tok('Model', xCols[0], 70, 45, 2),
          tok('B', xCols[2], 70, 25, 2),
          tok('Std. Error', xCols[3], 70, 60, 2),
          tok('Beta', xCols[4], 70, 35, 2),
          tok('t', xCols[5], 70, 20, 2),
          tok('Sig.', xCols[6], 70, 30, 2),
          tok('Tolerance', xCols[7], 70, 60, 2),
          tok('VIF', xCols[8], 70, 30, 2),
          // Data row 1: 1 | (Constant) | ,829 | ,185 | [blank] | 4,475 | ,000 | [blank] | [blank]
          tok('1', xCols[0], 100, 15, 3),
          tok('(Constant)', xCols[1], 100, 65, 3),
          tok(',829', xCols[2], 100, 35, 3),
          tok(',185', xCols[3], 100, 35, 3),
          tok('4,475', xCols[5], 100, 40, 3),
          tok(',000', xCols[6], 100, 35, 3),
          // Data row 2: [blank] | AN | ,142 | ,046 | ,171 | 3,098 | ,002 | ,598 | 1,673
          tok('AN', xCols[1], 130, 28, 4),
          tok(',142', xCols[2], 130, 35, 4),
          tok(',046', xCols[3], 130, 35, 4),
          tok(',171', xCols[4], 130, 35, 4),
          tok('3,098', xCols[5], 130, 40, 4),
          tok(',002', xCols[6], 130, 35, 4),
          tok(',598', xCols[7], 130, 35, 4),
          tok('1,673', xCols[8], 130, 40, 4),
          // Data row 3: [blank] | CS | ,172 | ,054 | ,192 | 3,161 | ,002 | ,489 | 2,047
          tok('CS', xCols[1], 160, 28, 5),
          tok(',172', xCols[2], 160, 35, 5),
          tok(',054', xCols[3], 160, 35, 5),
          tok(',192', xCols[4], 160, 35, 5),
          tok('3,161', xCols[5], 160, 40, 5),
          tok(',002', xCols[6], 160, 35, 5),
          tok(',489', xCols[7], 160, 35, 5),
          tok('2,047', xCols[8], 160, 40, 5),
          // Trailing footnote (line 6)
          tok('a. Dependent Variable: HL', 40, 195, 160, 6),
        ];

        final grid = OcrTableReconstructor.reconstruct(spssTokens);

        // Title banner, 3-span super-header and trailing footnote are pruned;
        // remaining rows are: 1 leaf header row + 3 data rows = 4 rows, 9 columns.
        expect(grid.rowCount, 4);
        expect(grid.columnCount, 9);
        expect(grid.hasHeader, isTrue);

        // Leaf headers stay in their exact columns (col 1 is empty header above "(Constant)"/"AN"/"CS")
        expect(grid.cells[0][0].recognizedText, 'Model');
        expect(grid.cells[0][1].recognizedText, isNull);
        expect(grid.cells[0][2].recognizedText, 'B');
        expect(grid.cells[0][3].recognizedText, 'Std. Error');
        expect(grid.cells[0][4].recognizedText, 'Beta');
        expect(grid.cells[0][5].recognizedText, 't');
        expect(grid.cells[0][6].recognizedText, 'Sig.');
        expect(grid.cells[0][7].recognizedText, 'Tolerance');
        expect(grid.cells[0][8].recognizedText, 'VIF');

        // Row 1 ("(Constant)") keeps Beta (col 4), Tolerance (col 7), VIF (col 8) blank without shifting 4,475 into Beta
        expect(grid.cells[1][0].recognizedText, '1');
        expect(grid.cells[1][1].recognizedText, '(Constant)');
        expect(grid.cells[1][2].recognizedText, ',829');
        expect(grid.cells[1][3].recognizedText, ',185');
        expect(grid.cells[1][4].recognizedText, isNull);
        expect(grid.cells[1][5].recognizedText, '4,475');
        expect(grid.cells[1][6].recognizedText, ',000');
        expect(grid.cells[1][7].recognizedText, isNull);
        expect(grid.cells[1][8].recognizedText, isNull);

        // Row 2 ("AN") keeps col 0 ("Model") blank and places AN in col 1
        expect(grid.cells[2][0].recognizedText, isNull);
        expect(grid.cells[2][1].recognizedText, 'AN');
        expect(grid.cells[2][2].recognizedText, ',142');
        expect(grid.cells[2][8].recognizedText, '1,673');
        // Leading-comma decimal ",142" is recognized as numeric, not flagged as typeOutlier
        expect(grid.cells[2][2].risks.contains(OcrRisk.typeOutlier), isFalse);

        // And WebCellEngine compares SPSS leading-comma ",85" with "0.85" as EQUIVALENT numeric values
        const engine = WebCellEngine();
        final numDecision = engine.compare(
          const SourceCell(CellKind.ocrText, rawLexeme: ',85', ocrReviewed: true),
          const SourceCell(CellKind.text, rawLexeme: '0.85'),
        );
        expect(numDecision.status, DecisionStatus.equivalent);
      },
    );
  });

  group('End-to-end OCR → Comparison Engine & Mobile Task-Oriented UI', () {
    test(
      'OCR-TC-008: finalized Vietnamese OCR table compares against CSV in MobileWorkflow',
      () async {
        final flow = createMobileWorkflow();
        addTearDown(flow.dispose);

        final registered = OcrCaptureService.registerSession(
          side: SourceSide.a,
          fileName: 'bang_a_ocr.png',
          format: SourceFormat.png,
          rawBytes: _testPng(),
          port: const SampleVietnameseOcrRecognitionAdapter(),
        );
        await flow.selectSource(
          SourceSide.a,
          registered.format,
          registered.privateRef,
          registered.fileName,
        );
        await flow.importSource(SourceSide.a);
        expect(flow.slot(SourceSide.a).state, InputState.needsReview);
        expect(flow.slot(SourceSide.a).ready, isFalse);

        final session = OcrCaptureService.session(registered.privateRef)!;
        await session.runRecognition();
        session.confirmGridStructure(autoConfirmCleanCells: true);
        session.confirmAllCells();
        OcrCaptureService.commitFinalized(registered.privateRef);
        await flow.changeImportConfig(
          SourceSide.a,
          ImportConfiguration(
            scopeConfirmed: true,
            ocrRevision: session.gridRevision,
            reviewedCells: {
              for (final e in session.receipts.keys) e.toString(),
            },
          ),
        );
        await flow.importSource(SourceSide.a);
        expect(flow.slot(SourceSide.a).ready, isTrue);
        expect(flow.slot(SourceSide.a).snapshot!.ocrReviewed, isTrue);

        const csvB =
            'Mã,Khoản mục,Giá trị\n'
            '001,Đơn hàng xuất khẩu,8.5\n'
            '002,Phí vận chuyển nội địa,12.0\n'
            '003,Chiết khấu đại lý,10\n'
            '004,Thuế giá trị gia tăng,7\n';
        final infoBUtf8 = MobileFileUploadService.processFileBytes(
          side: SourceSide.b,
          fileName: 'bang_b.csv',
          bytes: Uint8List.fromList(utf8.encode(csvB)),
        );
        await flow.selectSource(
          SourceSide.b,
          infoBUtf8.format,
          infoBUtf8.privateRef,
          infoBUtf8.fileName,
        );
        await flow.importSource(SourceSide.b);
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
        expect(flow.result!.count(DecisionStatus.different), 1);
      },
    );

    testWidgets(
      'Empty image (sample_avatar.png) shows dedicated "Chưa phát hiện bảng dữ liệu" state without table editing clutter, and allows manual table creation',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final flow = createMobileWorkflow();
        addTearDown(flow.dispose);

        await tester.runAsync(() async {
          final registered = OcrCaptureService.registerSession(
            side: SourceSide.a,
            fileName: 'sample_avatar.png',
            format: SourceFormat.png,
            rawBytes: _testPng(),
            port: const SampleVietnameseOcrRecognitionAdapter(customTokens: []),
          );
          await flow.selectSource(
            SourceSide.a,
            registered.format,
            registered.privateRef,
            registered.fileName,
          );
          await flow.importSource(SourceSide.a);
          await OcrCaptureService.session(registered.privateRef)!
              .runRecognition();
          flow.navigate(WorkflowScreen.ocrReview, side: SourceSide.a);
        });

        await tester.pumpWidget(
          MaterialApp(
            theme: DytavaTheme.lightTheme,
            home: WorkflowPage(controller: flow),
          ),
        );
        await tester.pumpAndSettle();

        // Compact native task header & empty state without noisy headers/filename
        expect(find.text('Kiểm tra bảng'), findsOneWidget);
        expect(find.text('Xem ảnh nguồn'), findsOneWidget);
        expect(find.text('Chưa phát hiện bảng dữ liệu'), findsOneWidget);
        expect(find.text('Chọn ảnh khác'), findsOneWidget);
        expect(find.text('Tạo bảng thủ công'), findsOneWidget);

        // No bottom confirmation bar or row/column editors when no table is detected
        expect(
          find.byKey(const ValueKey('ocr-approve-and-import-button')),
          findsNothing,
        );

        // Tap "Tạo bảng thủ công" → transitions to tableDetected with 3x2 grid
        await tester.tap(
          find.byKey(const ValueKey('ocr-create-manual-table')),
        );
        await tester.pumpAndSettle();

        expect(find.text('3 hàng × 2 cột'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('ocr-approve-and-import-button')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Touch BBox selection (Chọn vùng bảng) → Unified Table Review (Kiểm tra bảng) → 1-tap Dùng bảng này',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final flow = createMobileWorkflow();
        addTearDown(flow.dispose);

        await tester.runAsync(() async {
          final registered = OcrCaptureService.registerSession(
            side: SourceSide.a,
            fileName: 'bang_doi_soat_tieng_viet.png',
            format: SourceFormat.png,
            rawBytes: _testPng(),
            port: const SampleVietnameseOcrRecognitionAdapter(),
          );
          await flow.selectSource(
            SourceSide.a,
            registered.format,
            registered.privateRef,
            registered.fileName,
          );
          await flow.importSource(SourceSide.a);
          await OcrCaptureService.session(registered.privateRef)!
              .runPreprocessPreview();
          flow.navigate(WorkflowScreen.ocrReview, side: SourceSide.a);
        });

        await tester.pumpWidget(
          MaterialApp(
            theme: DytavaTheme.lightTheme,
            home: WorkflowPage(controller: flow),
          ),
        );
        await tester.pumpAndSettle();

        // Screen 1: Full-viewport Touch BBox Canvas ("Chọn vùng bảng", "Quét bảng")
        expect(find.text('Chọn vùng bảng'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('ocr-bbox-selector')),
          findsOneWidget,
        );
        expect(find.text('Quét bảng'), findsOneWidget);

        // Touch-drag top-left BBox corner handle
        await tester.drag(
          find.byKey(const ValueKey('ocr-bbox-handle-tl')),
          const Offset(12, 10),
        );
        await tester.pumpAndSettle();

        final ref = flow.slot(SourceSide.a).artifact!.privateRef;
        final session = OcrCaptureService.session(ref)!;
        await tester.runAsync(() async {
          await session.confirmTableBboxAndRecognize(
            normalizedBbox: const Rect.fromLTRB(0.05, 0.08, 0.95, 0.92),
          );
        });
        await tester.pumpAndSettle();

        // Screen 2: Unified Table Review ("Kiểm tra bảng") — immediately ready to use
        expect(find.text('Kiểm tra bảng'), findsOneWidget);
        expect(find.text('5 hàng × 3 cột'), findsOneWidget);
        expect(find.text('Dùng bảng này'), findsOneWidget);

        // 1-tap approval and import via session + controller
        await tester.runAsync(() async {
          session.approveTableForImport();
          OcrCaptureService.commitFinalized(ref);
          await flow.changeImportConfig(
            SourceSide.a,
            ImportConfiguration(
              scopeConfirmed: true,
              ocrRevision: session.gridRevision,
              reviewedCells: {
                for (final e in session.receipts.keys) e.toString(),
              },
            ),
          );
          await flow.importSource(SourceSide.a);
        });
        await tester.pumpAndSettle();

        expect(flow.slot(SourceSide.a).ready, isTrue);
        expect(flow.slot(SourceSide.a).snapshot!.fields.length, 3);
        expect(flow.slot(SourceSide.a).snapshot!.records.length, 4);
        expect(tester.takeException(), isNull);
      },
    );

    test(
      'Image-to-image (A & B both OCR images) and duplicate file SHA-256 detection work cleanly',
      () async {
        final flow = createMobileWorkflow();
        addTearDown(flow.dispose);

        final rawPng = _testPng();
        final regA = OcrCaptureService.registerSession(
          side: SourceSide.a,
          fileName: 'scan_a.png',
          format: SourceFormat.png,
          rawBytes: rawPng,
          port: const SampleVietnameseOcrRecognitionAdapter(),
        );
        final regB = OcrCaptureService.registerSession(
          side: SourceSide.b,
          fileName: 'scan_b.png',
          format: SourceFormat.png,
          rawBytes: rawPng,
          port: const SampleVietnameseOcrRecognitionAdapter(),
        );

        await flow.selectSource(
          SourceSide.a,
          regA.format,
          regA.privateRef,
          regA.fileName,
        );
        await flow.selectSource(
          SourceSide.b,
          regB.format,
          regB.privateRef,
          regB.fileName,
        );

        // Both A and B are accepted as image sources (no IMAGE_PAIR_UNSUPPORTED block)
        expect(flow.slot(SourceSide.a).artifact, isNotNull);
        expect(flow.slot(SourceSide.b).artifact, isNotNull);
        // Same file content triggers inline duplicate detection on the newly uploaded slot (B) without global technical error banners
        expect(flow.duplicateSourceFiles, isTrue);
        expect(flow.duplicateSlotSide, SourceSide.b);
        expect(flow.issue, isNull);
      },
    );
  });
}
