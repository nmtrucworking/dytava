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
      // "Đo\u031Bn ha\u0300ng xuâ\u0301t khâ\u0309u" → "Đơn hàng xuất khẩu"
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
      // Stacked grave + acute on a single vowel
      expect(VietnameseText.hasDiacriticAnomaly('a\u0300\u0301'), isTrue);
      // Tone mark placed on a consonant
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

  group('OcrTableReconstructor & OcrSession gates', () {
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
        expect(session.grid.rowCount, 5); // 1 header + 4 data rows
        expect(session.grid.columnCount, 3);
        expect(session.grid.hasHeader, isTrue);

        // OCR-TC-001 / OCR-RULE-005: Cannot confirm a cell before confirming grid structure
        session.confirmCell(const OcrCellRef(0, 0));
        expect(session.isCellConfirmed(const OcrCellRef(0, 0)), isFalse);
        expect(session.readyToNormalize, isFalse);

        // Confirm grid structure first
        session.confirmGridStructure();
        expect(session.gridConfirmed, isTrue);
        expect(session.stage, OcrPipelineStage.cellReview);

        // Confirm all cells
        for (var r = 0; r < session.grid.rowCount; r++) {
          for (var c = 0; c < session.grid.columnCount; c++) {
            session.confirmCell(OcrCellRef(r, c));
          }
        }
        expect(session.readyToNormalize, isTrue);

        // OCR-TC-006: Leading zeros ("001") and NFC Vietnamese text preserved
        final table1 = session.finalizeTable();
        expect(table1.headers, ['Mã', 'Khoản mục', 'Giá trị']);
        expect(table1.rows.first[0].reviewedText, '001');
        expect(table1.rows.first[1].reviewedText, 'Đơn hàng xuất khẩu');

        // OCR-TC-004: Insert an empty row (no OCR detection) → invalidates all receipts
        session.insertRow(session.grid.rowCount);
        expect(session.gridConfirmed, isFalse);
        expect(session.confirmedCellCount, 0);
        expect(session.readyToNormalize, isFalse);

        // Confirm new grid and enter user text for the missing detection
        session.confirmGridStructure();
        final lastRow = session.grid.rowCount - 1;
        session.editCellText(OcrCellRef(lastRow, 0), '005');
        session.editCellText(
          OcrCellRef(lastRow, 1),
          'Phu\u0323 phi\u0301 kiê\u0309m đi\u0323nh',
        );
        session.editCellText(OcrCellRef(lastRow, 2), '12.5');
        for (var r = 0; r < session.grid.rowCount; r++) {
          for (var c = 0; c < session.grid.columnCount; c++) {
            session.confirmCell(OcrCellRef(r, c));
          }
        }
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

    test('OCR-TC-003: row missing a cell raises rowShape and blank risks without shifting cells', () {
      final tokens = [
        const OcrToken(
          text: 'Mã',
          polygon: [OcrPoint(10, 10), OcrPoint(50, 10), OcrPoint(50, 30), OcrPoint(10, 30)],
          confidence: 0.99,
          lineIndex: 0,
        ),
        const OcrToken(
          text: 'Tên',
          polygon: [OcrPoint(120, 10), OcrPoint(170, 10), OcrPoint(170, 30), OcrPoint(120, 30)],
          confidence: 0.99,
          lineIndex: 0,
        ),
        const OcrToken(
          text: 'Số tiền',
          polygon: [OcrPoint(260, 10), OcrPoint(320, 10), OcrPoint(320, 30), OcrPoint(260, 30)],
          confidence: 0.99,
          lineIndex: 0,
        ),
        // Row 1 is missing middle column ("Tên"), has col 0 and col 2
        const OcrToken(
          text: '001',
          polygon: [OcrPoint(10, 60), OcrPoint(50, 60), OcrPoint(50, 80), OcrPoint(10, 80)],
          confidence: 0.99,
          lineIndex: 1,
        ),
        const OcrToken(
          text: '150',
          polygon: [OcrPoint(260, 60), OcrPoint(310, 60), OcrPoint(310, 80), OcrPoint(260, 80)],
          confidence: 0.99,
          lineIndex: 1,
        ),
      ];
      final grid = OcrTableReconstructor.reconstruct(tokens);
      expect(grid.rowCount, 2);
      expect(grid.columnCount, 3);
      // Middle cell is kept blank at column 1, not shifted from column 2
      expect(grid.cells[1][0].recognizedText, '001');
      expect(grid.cells[1][1].recognizedText, isNull);
      expect(grid.cells[1][1].risks, containsAll([OcrRisk.blank, OcrRisk.rowShape]));
      expect(grid.cells[1][2].recognizedText, '150');
    });
  });

  group('End-to-end OCR → Comparison Engine & Mobile UI', () {
    test(
      'OCR-TC-008: finalized Vietnamese OCR table compares against CSV in MobileWorkflow',
      () async {
        final flow = createMobileWorkflow();
        addTearDown(flow.dispose);

        // Source A: Vietnamese OCR session
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
        // Before review, Source A is gated in needsReview
        expect(flow.slot(SourceSide.a).state, InputState.needsReview);
        expect(flow.slot(SourceSide.a).ready, isFalse);

        // Run recognition, confirm grid structure & all cells
        final session = OcrCaptureService.session(registered.privateRef)!;
        await session.runRecognition();
        session.confirmGridStructure();
        for (var r = 0; r < session.grid.rowCount; r++) {
          for (var c = 0; c < session.grid.columnCount; c++) {
            session.confirmCell(OcrCellRef(r, c));
          }
        }
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

        // Source B: CSV with Vietnamese diacritics and one modified value
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
        expect(infoBUtf8.columnCount, 3);
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
      'Interactive 6-step OCR UI flow walks from preprocess → grid structure → cell review → normalization',
      (tester) async {
        tester.view.physicalSize = const Size(412, 915);
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
          final session = OcrCaptureService.session(registered.privateRef)!;
          await session.runPreprocessPreview();
          flow.navigate(WorkflowScreen.ocrReview, side: SourceSide.a);
        });

        await tester.pumpWidget(
          MaterialApp(
            theme: DytavaTheme.lightTheme,
            home: WorkflowPage(controller: flow),
          ),
        );
        await tester.pumpAndSettle();

        // Step 1/2: Preprocess stage visible
        expect(find.text('Tiền xử lý ảnh bảng tính'), findsOneWidget);
        expect(find.text('Tiếng Việt NFC'), findsOneWidget);

        // Run recognition → moves to Step 4/5a (Grid Structure stage)
        await tester.runAsync(() async {
          final ref = flow.slot(SourceSide.a).artifact!.privateRef;
          await OcrCaptureService.session(ref)!.runRecognition();
        });
        await tester.pumpAndSettle();

        expect(find.text('Tái cấu trúc hàng, cột và ô'), findsOneWidget);
        expect(
          find.text('Lưu ý kỹ thuật: Văn bản ≠ Cấu trúc bảng'),
          findsOneWidget,
        );

        // Confirm grid structure → moves to Step 5b (Cell Review stage)
        final confirmGridBtn = find.text('Xác nhận cấu trúc (5×3)');
        await tester.ensureVisible(confirmGridBtn);
        await tester.tap(confirmGridBtn);
        await tester.pumpAndSettle();

        expect(find.text('Kiểm tra và hiệu chỉnh ô dữ liệu'), findsOneWidget);

        // Confirm all cells via session and tap normalize
        final ref = flow.slot(SourceSide.a).artifact!.privateRef;
        final session = OcrCaptureService.session(ref)!;
        for (var r = 0; r < session.grid.rowCount; r++) {
          for (var c = 0; c < session.grid.columnCount; c++) {
            session.confirmCell(OcrCellRef(r, c));
          }
        }
        await tester.pumpAndSettle();

        final normalizeBtn = find.text(
          'Chuẩn hóa dữ liệu → Comparison Engine',
        );
        expect(normalizeBtn, findsOneWidget);
        await tester.runAsync(() async {
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
  });
}
