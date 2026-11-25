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
