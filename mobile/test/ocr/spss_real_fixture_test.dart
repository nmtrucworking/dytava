import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:dytava/domain/workflow.dart';
import 'package:dytava/infrastructure/file_upload_service.dart';
import 'package:dytava/ocr/domain/ocr_models.dart';
import 'package:dytava/ocr/domain/ocr_table_reconstructor.dart';
import 'package:dytava/ocr/domain/ocr_session.dart';
import 'package:dytava/ocr/infrastructure/mlkit_ocr_adapter.dart';
import 'package:dytava/ocr/infrastructure/ocr_image_preprocessor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

List<OcrToken> recordedCollinearityTokens() {
  final json = jsonDecode(
    File('test/ocr/fixtures/collinearity_mlkit_tokens.json').readAsStringSync(),
  ) as List;
  return [
    for (final t in json)
      OcrToken(
        text: t['text'] as String,
        polygon: [
          for (final p in t['polygon'] as List)
            OcrPoint((p[0] as num).toDouble(), (p[1] as num).toDouble()),
        ],
        confidence: (t['confidence'] as num?)?.toDouble(),
        lineIndex: t['lineIndex'] as int?,
      ),
  ];
}

void main() {
  test('three caption lines do not become rows of the extracted table', () {
    OcrToken token(String text, double x, double y) => OcrToken(
      text: text,
      polygon: [
        OcrPoint(x, y),
        OcrPoint(x + 40, y),
        OcrPoint(x + 40, y + 16),
        OcrPoint(x, y + 16),
      ],
    );
    final grid = OcrTableReconstructor.reconstruct([
      token('Coefficients', 100, 0),
      token('Standardized', 100, 30),
      token('Coefficients', 100, 60),
      for (final entry in ['Variable', 'B', 'Beta'].asMap().entries)
        token(entry.value, entry.key * 100, 90),
      for (var r = 0; r < 2; r++) ...[
        token(r == 0 ? 'AN' : 'CS', 0, 120 + r * 30),
        token(',142', 100, 120 + r * 30),
        token(',171', 200, 120 + r * 30),
      ],
    ]);
    expect(grid.columnCount, 3);
    expect(grid.rowCount, 3);
    expect(grid.cells[0][0].recognizedText, 'Variable');
    expect(grid.cells[0][1].recognizedText, 'B');
    expect(grid.cells[1][0].recognizedText, 'AN');
  });
  test(
    'ML Kit words joined across a border split only at actual symbol gaps',
    () {
      const text = 'DimensionEigenvalue';
      final symbols = [
        for (var i = 0; i < text.length; i++)
          TextSymbol(
            text: text[i],
            boundingBox: Rect.fromLTWH(i * 10.0 + (i >= 9 ? 50 : 0), 10, 8, 16),
            recognizedLanguages: const [],
            cornerPoints: const [],
            confidence: null,
            angle: null,
          ),
      ];
      TextElement element(List<TextSymbol> characters) => TextElement(
        text: text,
        symbols: characters,
        boundingBox: const Rect.fromLTWH(0, 10, 238, 16),
        recognizedLanguages: const [],
        cornerPoints: const [],
        confidence: null,
        angle: null,
      );
      final tokens = MlKitOcrRecognitionAdapter.tokensForElement(
        element(symbols),
        lineIndex: 0,
        scaleX: 0.5,
        scaleY: 0.5,
      );
      expect(tokens.map((t) => t.text), ['Dimension', 'Eigenvalue']);
      expect(tokens.map((t) => t.text).join(), text);
      expect(tokens.first.confidence, isNull);
      expect(tokens.first.box.left, 0);
      expect(tokens.last.box.left, 70);
      final fallback = MlKitOcrRecognitionAdapter.tokensForElement(
        element([]),
        lineIndex: 0,
      );
      expect(fallback.single.text, text);
    },
  );
  test(
    'small-text enhancement keeps inverse crop geometry and pixel bounds',
    () async {
      final processed = OcrImagePreprocessor.processSync(
        File('test/ocr/fixtures/spss_tables.jpg').readAsBytesSync(),
        const OcrPreprocessSettings(
          corners: [
            OcrPoint(30, 440),
            OcrPoint(1210, 440),
            OcrPoint(1210, 790),
            OcrPoint(30, 790),
          ],
        ),
      );
      final enhanced = await OcrImagePreprocessor.enhanceSmallText(processed);
      expect(enhanced.geometry.outputWidth, processed.geometry.outputWidth * 2);
      expect(
        enhanced.geometry.outputHeight,
        processed.geometry.outputHeight * 2,
      );
      expect(
        enhanced.geometry.outputWidth * enhanced.geometry.outputHeight,
        lessThanOrEqualTo(OcrImagePreprocessor.maxPixels),
      );
      final originalCorner = processed.geometry.toOriented(
        OcrPoint(
          processed.geometry.outputWidth - 1,
          processed.geometry.outputHeight - 1,
        ),
      );
      final enhancedCorner = enhanced.geometry.toOriented(
        OcrPoint(
          enhanced.geometry.outputWidth - 1,
          enhanced.geometry.outputHeight - 1,
        ),
      );
      expect(enhancedCorner, originalCorner);
    },
  );

  test(
    'possible missing decimals stay raw and flagged even at high confidence',
    () {
      final tokens = [
        for (final t in recordedCollinearityTokens())
          OcrToken(
            text: t.text,
            polygon: t.polygon,
            confidence: 0.99,
            lineIndex: t.lineIndex,
          ),
      ];
      final grid = OcrTableReconstructor.reconstruct(tokens);
      expect(grid.cells[4][7].recognizedText, '38');
      expect(grid.cells[4][7].risks, contains(OcrRisk.numericFormat));
      expect(grid.cells[4][7].risks, isNot(contains(OcrRisk.lowConfidence)));
      expect(grid.cells[3][1].risks, isNot(contains(OcrRisk.numericFormat)));
      final updated = OcrTableReconstructor.recomputeRisks(grid);
      expect(updated.cells[4][7].recognizedText, '38');
      expect(updated.cells[4][7].risks, contains(OcrRisk.numericFormat));

      // All 6 remaining SPSS decimal errors („00, 013, 10, 13, „88, 38) are flagged
      // with OcrRisk.numericFormat without mutating raw text:
      final allSixDecimalAnomalyRows = <List<String?>>[
        ['Dim', 'Eigenvalue', '(Constant)', 'AN', 'GC', 'DV', 'TN'],
        ['1', '6,932', '0,00', '0,00', '0,00', '0,00', '0,00'],
        ['2', '0,104', '0,00', '0,04', '„00', '0,01', '0,01'],
        ['3', '013', '0,01', '0,52', '0,05', '0,04', '0,19'],
        ['4', '0,011', '0,00', '0,02', '0,81', '0,11', '0,01'],
        ['5', '0,008', '10', '0,08', '0,01', '0,04', '0,41'],
        ['6', '0,004', '0,87', '0,21', '0,12', '0,02', '0,00'],
        ['7', '0,003', '0,02', '13', '0,01', '„88', '38'],
      ];
      final sampleGrid = OcrTableReconstructor.recomputeRisks(
        OcrGrid(
          [
            for (final row in allSixDecimalAnomalyRows)
              [
                for (final cellText in row)
                  OcrCell(
                    recognizedText: cellText,
                    confidence: 0.99,
                    tokenCount: cellText == null ? 0 : 1,
                  ),
              ],
          ],
          hasHeader: true,
        ),
      );
      expect(sampleGrid.cells[2][4].recognizedText, '„00');
      expect(sampleGrid.cells[2][4].risks, contains(OcrRisk.numericFormat));
      expect(sampleGrid.cells[3][1].recognizedText, '013');
      expect(sampleGrid.cells[3][1].risks, contains(OcrRisk.numericFormat));
      expect(sampleGrid.cells[5][2].recognizedText, '10');
      expect(sampleGrid.cells[5][2].risks, contains(OcrRisk.numericFormat));
      expect(sampleGrid.cells[7][3].recognizedText, '13');
      expect(sampleGrid.cells[7][3].risks, contains(OcrRisk.numericFormat));
      expect(sampleGrid.cells[7][5].recognizedText, '„88');
      expect(sampleGrid.cells[7][5].risks, contains(OcrRisk.numericFormat));
      expect(sampleGrid.cells[7][6].recognizedText, '38');
      expect(sampleGrid.cells[7][6].risks, contains(OcrRisk.numericFormat));
      // Dimension column (integer 1..7) is never falsely flagged as numericFormat
      for (var r = 1; r <= 7; r++) {
        expect(
          sampleGrid.cells[r][0].risks,
          isNot(contains(OcrRisk.numericFormat)),
        );
      }
    },
  );
  for (final failPreprocess in [false, true]) {
    test(
      'failed OCR retry invalidates previously approved data (crop: $failPreprocess)',
      () async {
        final port = _RetryPort();
        final session = OcrSession(
          port: port,
          label: 'spss_tables.jpg',
          rawBytes: File('test/ocr/fixtures/spss_tables.jpg').readAsBytesSync(),
        );
        addTearDown(session.dispose);
        await session.runRecognition();
        session.approveTableForImport();
        expect(session.readyToNormalize, isTrue);
        port.failPreprocess = failPreprocess;
        port.failRecognition = !failPreprocess;
        if (failPreprocess) {
          await session.confirmTableBboxAndRecognize(
            normalizedBbox: const Rect.fromLTRB(0.1, 0.1, 0.9, 0.9),
          );
        } else {
          await session.runRecognition();
        }
        expect(session.error, isNotNull);
        expect(session.readyToNormalize, isFalse);
        expect(session.receipts, isEmpty);
        expect(session.grid.cellCount, 0);
        expect(session.finalizeTable, throwsStateError);
      },
    );
  }
  test(
    'actual Android tokens retain 11 columns despite header/value alignment',
    () {
      final grid = OcrTableReconstructor.reconstruct(
        recordedCollinearityTokens(),
      );
      expect(grid.columnCount, 11);
      expect(grid.rowCount, 8);
      expect(grid.cells.first.map((c) => c.recognizedText), [
        'Model',
        'Dimension',
        'Eigenvalue',
        'Condition Index',
        '(Constant)',
        'AN',
        'CS',
        'GO',
        'NL',
        'DV',
        'TN',
      ]);
      expect(grid.cells[1][2].recognizedText, '6,932');
      expect(grid.cells[1][3].recognizedText, '1,000');
      expect(
        grid.cells[4][1].recognizedText,
        isNull,
        reason: 'ML Kit missed dimension 4; never invent the missing value.',
      );
      expect(grid.cells[4][1].risks, contains(OcrRisk.blank));
      expect(grid.cells[7][9].recognizedText, '88');
      expect(grid.cells[7][10].recognizedText, '38');
    },
  );

  test(
    'reference workbook imports both merged header levels as one header',
    () {
      addTearDown(MobileFileUploadService.clear);
      final info = MobileFileUploadService.processFileBytes(
        side: SourceSide.b,
        fileName: 'collinearity_diagnostics.xlsx',
        bytes: File('test/ocr/fixtures/collinearity_diagnostics.xlsx')
            .readAsBytesSync(),
      );
      expect(info.columnCount, 11);
      expect(info.rowCount, 7);
    },
  );

  test(
    'reselect (returnToPreprocess) restores full uncropped image and subsequent crop maps to full image coordinates',
    () async {
      final session = OcrSession(
        port: const SampleVietnameseOcrRecognitionAdapter(),
        label: 'spss_tables.jpg',
        rawBytes: File('test/ocr/fixtures/spss_tables.jpg').readAsBytesSync(),
      );
      addTearDown(session.dispose);

      // 1st scan: select lower table (Collinearity Diagnostics: y in [440/805, 790/805])
      await session.confirmTableBboxAndRecognize(
        normalizedBbox: const Rect.fromLTRB(
          30 / 1327,
          440 / 805,
          1210 / 1327,
          790 / 805,
        ),
      );
      expect(session.processed!.geometry.outputHeight, closeTo(350, 2));

      // User taps "Reselect" (returnToPreprocess)
      session.returnToPreprocess();
      // Wait for async runPreprocessPreview triggered by returnToPreprocess
      while (session.busy) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      expect(session.stage, OcrPipelineStage.preprocess);
      expect(session.settings.corners, isNull);
      expect(session.processed!.geometry.outputWidth, 1327);
      expect(session.processed!.geometry.outputHeight, 805);

      // 2nd scan: re-confirming the same lower table bbox crops full 350px height, not a 2-row slice
      await session.confirmTableBboxAndRecognize(
        normalizedBbox: const Rect.fromLTRB(
          30 / 1327,
          440 / 805,
          1210 / 1327,
          790 / 805,
        ),
      );
      expect(session.processed!.geometry.outputHeight, closeTo(350, 2));
      expect(session.processed!.geometry.corners[0].y, closeTo(440, 2));
      expect(session.processed!.geometry.corners[2].y, closeTo(790, 2));
    },
  );

  group('Multi-image OCR Corpus (Invoices, Financial Ledgers, Rotated Scans)', () {
    OcrToken tok(
      String text,
      double x,
      double y,
      double w,
      int line, {
      double conf = 0.96,
    }) => OcrToken(
      text: text,
      polygon: [
        OcrPoint(x, y),
        OcrPoint(x + w, y),
        OcrPoint(x + w, y + 18),
        OcrPoint(x, y + 18),
      ],
      confidence: conf,
      lineIndex: line,
    );

    test(
      'Corpus 1: Vietnamese Commercial Invoice (Hóa đơn GTGT) with currency symbols, diacritics, and sparse discount cells',
      () {
        const cols = [20.0, 110.0, 320.0, 410.0, 520.0, 640.0];
        final tokens = <OcrToken>[
          tok('HÓA ĐƠN GIÁ TRỊ GIA TĂNG', 240, 10, 220, 0),
          tok('Mã SP', cols[0], 45, 50, 1),
          tok('Tên hàng hóa, dịch vụ', cols[1], 45, 160, 1),
          tok('ĐVT', cols[2], 45, 40, 1),
          tok('SL', cols[3], 45, 30, 1),
          tok('Đơn giá (₫)', cols[4], 45, 85, 1),
          tok('Thành tiền (₫)', cols[5], 45, 100, 1),
          // Row 1
          tok('SP-001', cols[0], 80, 55, 2),
          tok('Nguyễn Văn An - Gói tư vấn ERP', cols[1], 80, 185, 2),
          tok('Gói', cols[2], 80, 35, 2),
          tok('1', cols[3], 80, 20, 2),
          tok('15.500.000', cols[4], 80, 80, 2),
          tok('15.500.000', cols[5], 80, 80, 2),
          // Row 2 (missing ĐVT cell intentionally)
          tok('SP-002', cols[0], 115, 55, 3),
          tok('Phần mềm đối soát dữ liệu Dytava', cols[1], 115, 190, 3),
          tok('2', cols[3], 115, 20, 3),
          tok('4.250.000', cols[4], 115, 75, 3),
          tok('8.500.000', cols[5], 115, 75, 3),
          // Row 3
          tok('SP-003', cols[0], 150, 55, 4),
          tok('Bảo trì hệ thống năm 2026', cols[1], 150, 165, 4),
          tok('Năm', cols[2], 150, 35, 4),
          tok('1', cols[3], 150, 20, 4),
          tok('2.000.000', cols[4], 150, 75, 4),
          tok('2.000.000', cols[5], 150, 75, 4),
        ];

        final grid = OcrTableReconstructor.reconstruct(tokens);
        expect(grid.columnCount, 6);
        expect(grid.rowCount, 4); // Title banner pruned; 1 header + 3 items
        expect(grid.hasHeader, isTrue);
        expect(grid.cells[0][1].recognizedText, 'Tên hàng hóa, dịch vụ');
        expect(
          grid.cells[1][1].recognizedText,
          'Nguyễn Văn An - Gói tư vấn ERP',
        );
        expect(grid.cells[2][2].recognizedText, isNull);
        expect(
          grid.cells[2][2].risks,
          containsAll([OcrRisk.blank, OcrRisk.rowShape]),
        );
        expect(grid.cells[2][5].recognizedText, '8.500.000');
      },
    );

    test(
      'Corpus 2: Multi-level Accounting Trial Balance (Bảng cân đối phát sinh) with wrapped leaf headers and dropped decimal warning',
      () {
        const cols = [20.0, 120.0, 280.0, 400.0, 520.0, 640.0];
        final tokens = <OcrToken>[
          tok('BẢNG CÂN ĐỐI SỐ PHÁT SINH QUÝ IV/2026', 200, 10, 260, 0),
          tok('Số dư đầu kỳ', 280, 40, 180, 1),
          tok('Số phát sinh trong kỳ', 520, 40, 190, 1),
          // Wrapped leaf header line 1
          tok('Số hiệu', cols[0], 70, 55, 2),
          tok('Tên tài khoản', cols[1], 70, 110, 2),
          tok('Nợ', cols[2], 70, 35, 2),
          tok('Có', cols[3], 70, 35, 2),
          tok('Nợ', cols[4], 70, 35, 2),
          tok('Có', cols[5], 70, 35, 2),
          // Data rows with 2-decimal precision, plus one dropped-decimal outlier ("145" instead of "1,45")
          tok('1111', cols[0], 105, 45, 3),
          tok('Tiền mặt Việt Nam', cols[1], 105, 130, 3),
          tok('120,50', cols[2], 105, 55, 3),
          tok('0,00', cols[3], 105, 40, 3),
          tok('85,25', cols[4], 105, 50, 3),
          tok('40,10', cols[5], 105, 50, 3),
          tok('1121', cols[0], 140, 45, 4),
          tok('Tiền gửi ngân hàng', cols[1], 140, 130, 4),
          tok('540,75', cols[2], 140, 55, 4),
          tok('0,00', cols[3], 140, 40, 4),
          tok('310,80', cols[4], 140, 55, 4),
          tok('145', cols[5], 140, 45, 4), // Dropped decimal in 2-decimal column
          tok('1311', cols[0], 175, 45, 5),
          tok('Phải thu khách hàng', cols[1], 175, 135, 5),
          tok('90,25', cols[2], 175, 50, 5),
          tok('12,40', cols[3], 175, 45, 5),
          tok('44,00', cols[4], 175, 50, 5),
          tok('19,75', cols[5], 175, 50, 5),
        ];

        final grid = OcrTableReconstructor.reconstruct(tokens);
        expect(grid.columnCount, 6);
        expect(grid.rowCount, 4);
        // Account codes 1111, 1121, 1311 in column 0 are integers -> no numericFormat risk
        expect(
          grid.cells[1][0].risks,
          isNot(contains(OcrRisk.numericFormat)),
        );
        // "145" in column 5 (which has 2-decimal peers "40,10" and "19,75") is flagged with numericFormat
        expect(grid.cells[2][5].recognizedText, '145');
        expect(grid.cells[2][5].risks, contains(OcrRisk.numericFormat));
      },
    );

    test(
      'Corpus 3: Skewed / low-confidence Warehouse Inventory scan flags diacritic & lowConfidence risks without dropping tokens',
      () {
        const cols = [15.0, 120.0, 310.0, 430.0];
        final tokens = <OcrToken>[
          tok('Mã kho', cols[0], 20, 55, 0),
          tok('Vật tư thiết bị', cols[1], 21, 130, 0),
          tok('Tồn đầu', cols[2], 19, 60, 0),
          tok('Tồn cuối', cols[3], 22, 65, 0),
          tok('KHO-A1', cols[0], 58, 60, 1),
          tok('Cảm biến nhiệt độ PT100', cols[1], 60, 165, 1, conf: 0.78),
          tok('12,5', cols[2], 57, 45, 1),
          tok('10,5', cols[3], 61, 45, 1),
          tok('KHO-A2', cols[0], 96, 60, 2),
          tok('Bộ điều khiển PLC S7', cols[1], 95, 155, 2, conf: 0.95),
          tok('8,0', cols[2], 98, 40, 2),
          tok('„5', cols[3], 97, 35, 2, conf: 0.94),
        ];

        final grid = OcrTableReconstructor.reconstruct(tokens);
        expect(grid.columnCount, 4);
        expect(grid.rowCount, 3);
        expect(
          grid.cells[1][1].risks,
          containsAll([OcrRisk.lowConfidence, OcrRisk.diacritics]),
        );
        expect(grid.cells[2][3].recognizedText, '„5');
        expect(grid.cells[2][3].risks, contains(OcrRisk.numericFormat));
      },
    );
  });
}

class _RetryPort implements OcrRecognitionPort {
  bool failPreprocess = false;
  bool failRecognition = false;
  final delegate = const SampleVietnameseOcrRecognitionAdapter();
  @override
  String get engineId => 'retry-test';
  @override
  Future<OcrProcessedImage> preprocess(
    Uint8List bytes,
    OcrPreprocessSettings settings,
  ) {
    if (failPreprocess) throw const FormatException('test crop failure');
    return delegate.preprocess(bytes, settings);
  }

  @override
  Future<List<OcrToken>> recognize(OcrProcessedImage image) {
    if (failRecognition) throw StateError('test recognizer failure');
    return delegate.recognize(image);
  }
}
