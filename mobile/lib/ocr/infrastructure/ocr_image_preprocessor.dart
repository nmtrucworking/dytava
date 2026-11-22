import 'dart:isolate';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../domain/ocr_models.dart';
import '../domain/ocr_session.dart';

/// Step 2 of the OCR pipeline:
/// - Decode with pixel ceiling guard (INP-ERR-004: max 12 MP)
/// - Apply EXIF orientation (`bakeOrientation`)
/// - Apply clockwise 90° quarter turns
/// - Apply perspective rectification / crop (`copyRectify`) with exact
///   invertible coordinate mapping back to `oriented_image_pixels`
/// - Optionally enhance contrast for crisp text & Vietnamese diacritics
abstract final class OcrImagePreprocessor {
  static const maxPixels = 12 * 1000 * 1000; // 12 MP ceiling (INP-ADR-004)

  static Future<OcrProcessedImage> process(
    Uint8List rawBytes,
    OcrPreprocessSettings settings,
  ) {
    if (kIsWeb) {
      return Future.value(_processSync(rawBytes, settings));
    }
    return Isolate.run(() => _processSync(rawBytes, settings));
  }

  static OcrProcessedImage processSync(
    Uint8List rawBytes,
    OcrPreprocessSettings settings,
  ) => _processSync(rawBytes, settings);

  static OcrProcessedImage _processSync(
    Uint8List rawBytes,
    OcrPreprocessSettings settings,
  ) {
    if (rawBytes.isEmpty) {
      throw const FormatException('INP-ERR-004: Tệp ảnh rỗng.');
    }
    final decoded = img.decodeImage(rawBytes);
    if (decoded == null) {
      throw const FormatException(
        'INP-ERR-004: Không giải mã được định dạng ảnh (chỉ hỗ trợ PNG/JPEG).',
      );
    }
    final oriented = img.bakeOrientation(decoded);
    final orientedWidth = oriented.width;
    final orientedHeight = oriented.height;
    if (orientedWidth <= 0 ||
        orientedHeight <= 0 ||
        orientedWidth * orientedHeight > maxPixels) {
      throw FormatException(
        'INP-ERR-004: Kích thước ảnh ($orientedWidth×$orientedHeight) vượt trần 12 MP.',
      );
    }

    final turns = settings.quarterTurns % 4;
    var rotated = switch (turns) {
      1 => img.copyRotate(oriented, angle: 90),
      2 => img.copyRotate(oriented, angle: 180),
      3 => img.copyRotate(oriented, angle: 270),
      _ => oriented,
    };

    if (settings.flipHorizontal && settings.flipVertical) {
      rotated = img.flip(rotated, direction: img.FlipDirection.both);
    } else if (settings.flipHorizontal) {
      rotated = img.flip(rotated, direction: img.FlipDirection.horizontal);
    } else if (settings.flipVertical) {
      rotated = img.flip(rotated, direction: img.FlipDirection.vertical);
    }

    final rw = rotated.width.toDouble();
    final rh = rotated.height.toDouble();
    final defaultCorners = <OcrPoint>[
      const OcrPoint(0, 0),
      OcrPoint(rw - 1, 0),
      OcrPoint(rw - 1, rh - 1),
      OcrPoint(0, rh - 1),
    ];

    final corners = _sanitizeCorners(settings.corners, rw, rh) ?? defaultCorners;
    final isFullFrame = _isFullFrame(corners, rw, rh);

    img.Image working;
    if (isFullFrame) {
      working = rotated;
    } else {
      final topW = _distance(corners[0], corners[1]);
      final bottomW = _distance(corners[3], corners[2]);
      final leftH = _distance(corners[0], corners[3]);
      final rightH = _distance(corners[1], corners[2]);
      final outW = math.max(16, ((topW + bottomW) / 2).round());
      final outH = math.max(16, ((leftH + rightH) / 2).round());
      final target = img.Image(
        width: outW,
        height: outH,
        numChannels: rotated.numChannels,
      );
      working = img.copyRectify(
        rotated,
        topLeft: img.Point(corners[0].x, corners[0].y),
        topRight: img.Point(corners[1].x, corners[1].y),
        bottomRight: img.Point(corners[2].x, corners[2].y),
        bottomLeft: img.Point(corners[3].x, corners[3].y),
        interpolation: img.Interpolation.linear,
        toImage: target,
      );
    }

    if (settings.enhanceContrast) {
      working = img.adjustColor(
        working,
        contrast: 1.18,
      );
    }

    final geometry = OcrGeometry(
      orientedWidth: orientedWidth,
      orientedHeight: orientedHeight,
      quarterTurns: turns,
      flipHorizontal: settings.flipHorizontal,
      flipVertical: settings.flipVertical,
      corners: corners,
      outputWidth: working.width,
      outputHeight: working.height,
    );

    return OcrProcessedImage(
      pngBytes: Uint8List.fromList(img.encodePng(working)),
      geometry: geometry,
    );
  }

  static List<OcrPoint>? _sanitizeCorners(
    List<OcrPoint>? corners,
    double width,
    double height,
  ) {
    if (corners == null || corners.length != 4) return null;
    for (final p in corners) {
      if (!p.x.isFinite || !p.y.isFinite) {
        throw const FormatException('INP-ERR-014: Tọa độ vùng cắt không hợp lệ.');
      }
    }
    return [
      for (final p in corners)
        OcrPoint(
          p.x.clamp(0.0, math.max(0.0, width - 1)),
          p.y.clamp(0.0, math.max(0.0, height - 1)),
        ),
    ];
  }

  static bool _isFullFrame(List<OcrPoint> c, double w, double h) =>
      (c[0].x).abs() < 0.5 &&
      (c[0].y).abs() < 0.5 &&
      (c[1].x - (w - 1)).abs() < 0.5 &&
      (c[1].y).abs() < 0.5 &&
      (c[2].x - (w - 1)).abs() < 0.5 &&
      (c[2].y - (h - 1)).abs() < 0.5 &&
      (c[3].x).abs() < 0.5 &&
      (c[3].y - (h - 1)).abs() < 0.5;

  static double _distance(OcrPoint a, OcrPoint b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    return math.sqrt(dx * dx + dy * dy);
  }
}
