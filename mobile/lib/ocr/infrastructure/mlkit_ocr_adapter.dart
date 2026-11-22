import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../domain/ocr_models.dart';
import '../domain/ocr_session.dart';
import 'ocr_image_preprocessor.dart';

/// On-device bundled ML Kit Text Recognition v2 (Latin script, which natively
/// covers Vietnamese diacritics `vi` / `Latn`).
///
/// Temporary scratch files written for the native plugin are deleted immediately
/// in a `finally` block (INP-ADR-009: no raw retention).
final class MlKitOcrRecognitionAdapter implements OcrRecognitionPort {
  MlKitOcrRecognitionAdapter();

  @override
  String get engineId => 'mlkit-text-recognition-v2-latin';

  @override
  Future<OcrProcessedImage> preprocess(
    Uint8List rawBytes,
    OcrPreprocessSettings settings,
  ) => OcrImagePreprocessor.process(rawBytes, settings);

  @override
  Future<List<OcrToken>> recognize(OcrProcessedImage image) async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      throw UnsupportedError(
        'ML Kit on-device OCR chỉ chạy trên Android/iOS.',
      );
    }

    final tempDir = await Directory.systemTemp.createTemp('dytava_ocr_');
    final tempFile = File('${tempDir.path}/frame.png');
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      await tempFile.writeAsBytes(image.pngBytes, flush: true);
      final inputImage = InputImage.fromFilePath(tempFile.path);
      final recognized = await recognizer.processImage(inputImage);
      final tokens = <OcrToken>[];
      var lineIndex = 0;
      for (final block in recognized.blocks) {
        for (final line in block.lines) {
          final currentLine = lineIndex++;
          for (final element in line.elements) {
            final corners = element.cornerPoints;
            final rect = element.boundingBox;
            final polygon = corners.length >= 4
                ? [
                    for (final pt in corners)
                      OcrPoint(pt.x.toDouble(), pt.y.toDouble()),
                  ]
                : [
                    OcrPoint(rect.left, rect.top),
                    OcrPoint(rect.right, rect.top),
                    OcrPoint(rect.right, rect.bottom),
                    OcrPoint(rect.left, rect.bottom),
                  ];
            tokens.add(
              OcrToken(
                text: element.text,
                polygon: polygon,
                confidence: element.confidence ?? line.confidence,
                lineIndex: currentLine,
                languages: element.recognizedLanguages.isNotEmpty
                    ? element.recognizedLanguages
                    : line.recognizedLanguages,
              ),
            );
          }
        }
      }
      return tokens;
    } finally {
      await recognizer.close();
      try {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      } catch (_) {}
    }
  }
}

/// Deterministic, offline Vietnamese spreadsheet OCR sample used for desktop/test
/// environments and the "Mẫu bảng tiếng Việt" preview flow.
final class SampleVietnameseOcrRecognitionAdapter implements OcrRecognitionPort {
  const SampleVietnameseOcrRecognitionAdapter({this.customTokens});

  final List<OcrToken>? customTokens;

  @override
  String get engineId => 'dytava-vietnamese-sample-v1';

  @override
  Future<OcrProcessedImage> preprocess(
    Uint8List rawBytes,
    OcrPreprocessSettings settings,
  ) => OcrImagePreprocessor.process(rawBytes, settings);

  @override
  Future<List<OcrToken>> recognize(OcrProcessedImage image) async {
    if (customTokens != null) return customTokens!;
    return defaultVietnameseTokens();
  }

  /// Generates a valid PNG image for the sample Vietnamese table.
  static Uint8List samplePngBytes() {
    // 1x1 white PNG encoded bytes resized via preprocessor or simple valid PNG.
    return Uint8List.fromList(const [
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
      0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
      0x00, 0x00, 0x02, 0x80, 0x00, 0x00, 0x01, 0x90,
      0x08, 0x02, 0x00, 0x00, 0x00, 0x53, 0x35, 0x7A,
      0xD5, 0x00, 0x00, 0x00, 0x1D, 0x49, 0x44, 0x41,
      0x54, 0x78, 0x9C, 0xED, 0xC1, 0x01, 0x0D, 0x00,
      0x00, 0x00, 0xC2, 0xA0, 0xF7, 0x4F, 0x6D, 0x0E,
      0x37, 0xA0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
      0x00, 0x80, 0x77, 0x03, 0x95, 0x40, 0x00, 0x01,
      0x9A, 0x60, 0xE1, 0xD5, 0x00, 0x00, 0x00, 0x00,
      0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
    ]);
  }

  /// Sample tokens featuring:
  /// - Vietnamese headers & full diacritics (including decomposed NFD input to
  ///   exercise NFC canonicalization)
  /// - Leading-zero identifiers (`001`, `002`, `003`, `004`)
  /// - High-confidence and low-confidence cells
  static List<OcrToken> defaultVietnameseTokens() {
    OcrToken tok(
      String text,
      double x,
      double y,
      double w,
      double h,
      int line,
      double conf,
    ) => OcrToken(
      text: text,
      polygon: [
        OcrPoint(x, y),
        OcrPoint(x + w, y),
        OcrPoint(x + w, y + h),
        OcrPoint(x, y + h),
      ],
      confidence: conf,
      lineIndex: line,
      languages: const ['vi'],
    );

    return [
      // Header row (line 0)
      tok('Mã', 24, 24, 48, 22, 0, 0.98),
      tok('Khoản mục', 160, 24, 110, 22, 0, 0.96),
      tok('Giá trị', 360, 24, 80, 22, 0, 0.97),
      // Row 1 (line 1) — NFD decomposed "Đơn hàng xuất khẩu"
      tok('001', 24, 72, 46, 22, 1, 0.99),
      tok('Đo\u031Bn ha\u0300ng xuâ\u0301t khâ\u0309u', 160, 72, 160, 22, 1, 0.91),
      tok('8.5', 360, 72, 54, 22, 1, 0.96),
      // Row 2 (line 2) — Low confidence cell requiring careful check
      tok('002', 24, 120, 46, 22, 2, 0.98),
      tok('Phí vận chuyển nội địa', 160, 120, 165, 22, 2, 0.88),
      tok('9.0', 360, 120, 54, 22, 2, 0.79),
      // Row 3 (line 3)
      tok('003', 24, 168, 46, 22, 3, 0.99),
      tok('Chiết khấu đại lý', 160, 168, 140, 22, 3, 0.94),
      tok('10', 360, 168, 54, 22, 3, 0.97),
      // Row 4 (line 4)
      tok('004', 24, 216, 46, 22, 4, 0.99),
      tok('Thuế giá trị gia tăng', 160, 216, 155, 22, 4, 0.95),
      tok('7', 360, 216, 54, 22, 4, 0.98),
    ];
  }
}
