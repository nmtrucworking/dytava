import 'dart:math' as math;

/// OCR module domain models. Coordinates are pixels.
///
/// - *Processed* coordinates: the rotated, rectified image given to the
///   recognizer.
/// - *Oriented* coordinates: the original image after EXIF orientation, origin
///   top-left, x right, y down (`oriented_image_pixels`, INP-010 §3).
final class OcrPoint {
  const OcrPoint(this.x, this.y);
  final double x, y;
  @override
  bool operator ==(Object other) =>
      other is OcrPoint && other.x == x && other.y == y;
  @override
  int get hashCode => Object.hash(x, y);
  @override
  String toString() => '(${x.toStringAsFixed(1)}, ${y.toStringAsFixed(1)})';
}

/// Axis-aligned box in processed coordinates.
final class OcrBox {
  const OcrBox(this.left, this.top, this.right, this.bottom);
  final double left, top, right, bottom;
  double get width => right - left;
  double get height => bottom - top;
  double get centerY => (top + bottom) / 2;
  OcrBox union(OcrBox o) => OcrBox(
    math.min(left, o.left),
    math.min(top, o.top),
    math.max(right, o.right),
    math.max(bottom, o.bottom),
  );
  List<OcrPoint> get corners => [
    OcrPoint(left, top),
    OcrPoint(right, top),
    OcrPoint(right, bottom),
    OcrPoint(left, bottom),
  ];
  static OcrBox fromPoints(Iterable<OcrPoint> points) {
    var l = double.infinity, t = double.infinity;
    var r = -double.infinity, b = -double.infinity;
    for (final p in points) {
      l = math.min(l, p.x);
      t = math.min(t, p.y);
      r = math.max(r, p.x);
      b = math.max(b, p.y);
    }
    return OcrBox(l, t, r, b);
  }
}

/// One recognized word. [text] is the recognizer output, unmodified.
final class OcrToken {
  const OcrToken({
    required this.text,
    required this.polygon,
    this.confidence,
    this.lineIndex,
    this.languages = const [],
  });
  final String text;

  /// Polygon in processed coordinates (usually 4 points, clockwise).
  final List<OcrPoint> polygon;

  /// Model confidence in [0, 1] or null when the engine does not report it.
  final double? confidence;
  final int? lineIndex;
  final List<String> languages;
  OcrBox get box => OcrBox.fromPoints(polygon);
}

/// User-visible preprocessing (INP-010 §3: crop/rotation/flip transform is stored).
final class OcrPreprocessSettings {
  const OcrPreprocessSettings({
    this.quarterTurns = 0,
    this.flipHorizontal = false,
    this.flipVertical = false,
    this.corners,
    this.enhanceContrast = true,
  });

  /// Clockwise quarter turns applied to the oriented image.
  final int quarterTurns;

  /// Horizontal mirror applied after rotation.
  final bool flipHorizontal;

  /// Vertical mirror applied after rotation.
  final bool flipVertical;

  /// Document corners TL, TR, BR, BL in *rotated* image coordinates.
  /// `null` means the full rotated image.
  final List<OcrPoint>? corners;
  final bool enhanceContrast;

  OcrPreprocessSettings copyWith({
    int? quarterTurns,
    bool? flipHorizontal,
    bool? flipVertical,
    List<OcrPoint>? corners,
    bool clearCorners = false,
    bool? enhanceContrast,
  }) => OcrPreprocessSettings(
    quarterTurns: quarterTurns ?? this.quarterTurns,
    flipHorizontal: flipHorizontal ?? this.flipHorizontal,
    flipVertical: flipVertical ?? this.flipVertical,
    corners: clearCorners ? null : (corners ?? this.corners),
    enhanceContrast: enhanceContrast ?? this.enhanceContrast,
  );
}

/// Exact mapping from processed pixels back to oriented image pixels.
///
/// The rectification is a bilinear warp of the four document corners, followed
/// by optional horizontal/vertical flip and a clockwise rotation of the
/// oriented image. All steps are invertible for the forward direction used
/// here (processed → oriented).
final class OcrGeometry {
  const OcrGeometry({
    required this.orientedWidth,
    required this.orientedHeight,
    required this.quarterTurns,
    this.flipHorizontal = false,
    this.flipVertical = false,
    required this.corners,
    required this.outputWidth,
    required this.outputHeight,
  });
  final int orientedWidth, orientedHeight, quarterTurns;
  final bool flipHorizontal, flipVertical;

  /// TL, TR, BR, BL in rotated coordinates.
  final List<OcrPoint> corners;
  final int outputWidth, outputHeight;

  int get rotatedWidth => quarterTurns.isOdd ? orientedHeight : orientedWidth;
  int get rotatedHeight => quarterTurns.isOdd ? orientedWidth : orientedHeight;

  /// Processed → rotated (bilinear, same formula as the warp, then inverse flip).
  OcrPoint toRotated(OcrPoint p) {
    final u = outputWidth <= 1 ? 0.0 : p.x / (outputWidth - 1);
    final v = outputHeight <= 1 ? 0.0 : p.y / (outputHeight - 1);
    final tl = corners[0], tr = corners[1], br = corners[2], bl = corners[3];
    var x =
        tl.x * (1 - u) * (1 - v) +
        tr.x * u * (1 - v) +
        bl.x * (1 - u) * v +
        br.x * u * v;
    var y =
        tl.y * (1 - u) * (1 - v) +
        tr.y * u * (1 - v) +
        bl.y * (1 - u) * v +
        br.y * u * v;
    if (flipHorizontal) {
      x = (rotatedWidth - 1) - x;
    }
    if (flipVertical) {
      y = (rotatedHeight - 1) - y;
    }
    return OcrPoint(x, y);
  }

  /// Rotated → oriented (inverse of clockwise quarter turns).
  OcrPoint rotatedToOriented(OcrPoint p) {
    final w = orientedWidth.toDouble(), h = orientedHeight.toDouble();
    return switch (quarterTurns % 4) {
      0 => p,
      1 => OcrPoint(p.y, h - 1 - p.x),
      2 => OcrPoint(w - 1 - p.x, h - 1 - p.y),
      _ => OcrPoint(w - 1 - p.y, p.x),
    };
  }

  OcrPoint toOriented(OcrPoint p) => rotatedToOriented(toRotated(p));

  /// Oriented polygon, clamped to the image bounds (INP-ERR-014 guard).
  List<OcrPoint> polygonToOriented(Iterable<OcrPoint> polygon) => [
    for (final p in polygon)
      (() {
        final o = toOriented(p);
        return OcrPoint(
          o.x.clamp(0, orientedWidth - 1).toDouble(),
          o.y.clamp(0, orientedHeight - 1).toDouble(),
        );
      })(),
  ];
}

/// Four explicit domain outcomes for OCR extraction and table reconstruction.
enum OcrDetectionState {
  /// No text tokens were recognized in the image.
  noTextDetected,

  /// Text tokens were found, but a reliable row/column table structure could
  /// not be reconstructed.
  textWithoutTable,

  /// A tabular grid structure was reconstructed and is ready for review/edit.
  tableDetected,

  /// Decoding, preprocessing or recognition failed.
  processingFailed,
}

/// Structure and recognition warnings (OCR-RULE-006). Warnings focus the
/// reviewer; they never exempt any cell from review.
enum OcrRisk {
  lowConfidence,
  diacritics,
  spansColumns,
  multipleSegments,
  rowShape,
  typeOutlier,
  numericFormat,
  blank,
}

extension OcrRiskInfo on OcrRisk {
  String get label => switch (this) {
    OcrRisk.lowConfidence => 'Độ tin cậy thấp',
    OcrRisk.diacritics => 'Kiểm tra dấu tiếng Việt',
    OcrRisk.spansColumns => 'Chồng biên cột',
    OcrRisk.multipleSegments => 'Nhiều cụm từ gộp',
    OcrRisk.rowShape => 'Hàng thiếu ô',
    OcrRisk.typeOutlier => 'Khác kiểu cột',
    OcrRisk.numericFormat => 'Kiểm tra dấu thập phân',
    OcrRisk.blank => 'Ô trống / chưa nhận diện',
  };

  String get help => switch (this) {
    OcrRisk.numericFormat => 'Chuỗi số khác định dạng thập phân của các ô cùng cột. Hãy đối chiếu ảnh gốc trước khi xác nhận.',
    OcrRisk.lowConfidence => 'Bộ nhận dạng chưa chắc chắn về chuỗi ký tự này.',
    OcrRisk.diacritics =>
      'Dấu thanh tiếng Việt có thể bị mờ, chồng dấu hoặc đặt sai nguyên âm.',
    OcrRisk.spansColumns => 'Văn bản nằm vắt qua ranh giới hai cột, cần kiểm tra có bị gộp cột không.',
    OcrRisk.multipleSegments =>
      'Nhiều cụm từ cách xa nhau đã được gộp vào cùng một ô.',
    OcrRisk.rowShape => 'Hàng này có số ô ít hơn các hàng còn lại trong bảng.',
    OcrRisk.typeOutlier =>
      'Đa số giá trị trong cột là số nhưng ô này chứa chữ (dễ nhầm O/0, l/1).',
    OcrRisk.blank => 'Không phát hiện ký tự tại vị trí này. Hãy xác nhận ô trống hoặc nhập bổ sung.',
  };
}

/// One reconstructed cell. [recognizedText] is the raw recognizer text (tokens
/// joined by a space); never modified after recognition.
final class OcrCell {
  const OcrCell({
    this.recognizedText,
    this.confidence,
    this.box,
    this.tokenCount = 0,
    this.risks = const {},
  });

  /// `null` when nothing was detected (`OCR_NO_DETECTION`).
  final String? recognizedText;
  final double? confidence;
  final OcrBox? box;
  final int tokenCount;
  final Set<OcrRisk> risks;

  bool get detected => recognizedText != null && recognizedText!.isNotEmpty;

  OcrCell merge(OcrCell right) {
    final texts = [
      if (detected) recognizedText!,
      if (right.detected) right.recognizedText!,
    ];
    final conf = [?confidence, ?right.confidence];
    return OcrCell(
      recognizedText: texts.isEmpty ? null : texts.join(' '),
      confidence: conf.isEmpty ? null : conf.reduce(math.min),
      box: box == null
          ? right.box
          : (right.box == null ? box : box!.union(right.box!)),
      tokenCount: tokenCount + right.tokenCount,
      risks: {
        ...risks,
        ...right.risks,
        if (texts.length > 1) OcrRisk.multipleSegments,
      }..remove(OcrRisk.blank),
    );
  }
}

/// Row-major grid proposal. Cell `[r][c]`.
final class OcrGrid {
  OcrGrid(List<List<OcrCell>> cells, {this.hasHeader = false})
    : cells = List.unmodifiable(cells.map(List<OcrCell>.unmodifiable)) {
    if (cells.isNotEmpty && cells.any((r) => r.length != cells.first.length)) {
      throw ArgumentError('OCR grid rows must have equal width.');
    }
  }
  final List<List<OcrCell>> cells;
  final bool hasHeader;
  int get rowCount => cells.length;
  int get columnCount => cells.isEmpty ? 0 : cells.first.length;
  int get cellCount => rowCount * columnCount;

  OcrGrid copyWith({List<List<OcrCell>>? cells, bool? hasHeader}) =>
      OcrGrid(cells ?? this.cells, hasHeader: hasHeader ?? this.hasHeader);
}

/// Grid-cell address. Stable only within one grid revision.
final class OcrCellRef {
  const OcrCellRef(this.row, this.column);
  final int row, column;
  @override
  bool operator ==(Object other) =>
      other is OcrCellRef && other.row == row && other.column == column;
  @override
  int get hashCode => Object.hash(row, column);
  @override
  String toString() => 'R${row + 1}C${column + 1}';
}

/// Review receipt bound to artifact, extraction, grid and reviewed text
/// (INP-011 `OcrReviewReceipt`).
final class OcrReviewReceipt {
  const OcrReviewReceipt({
    required this.cell,
    required this.artifactSha256,
    required this.extractionRevision,
    required this.gridRevision,
    required this.reviewedTextDigest,
    required this.reviewedAt,
  });
  final OcrCellRef cell;
  final String artifactSha256;
  final int extractionRevision, gridRevision;
  final String reviewedTextDigest;
  final DateTime reviewedAt;
}

/// Where a reviewed value came from.
enum OcrCorrectionOrigin { recognized, userEdited, userEntered }

/// A frozen, fully reviewed table ready for the Comparison Engine.
final class OcrReviewedTable {
  OcrReviewedTable({
    required this.label,
    required this.artifactSha256,
    required this.engine,
    required this.extractionRevision,
    required this.gridRevision,
    required List<String> headers,
    required List<List<OcrReviewedValue>> rows,
    required this.orientedWidth,
    required this.orientedHeight,
  }) : headers = List.unmodifiable(headers),
       rows = List.unmodifiable(rows.map(List<OcrReviewedValue>.unmodifiable));
  final String label, artifactSha256, engine;
  final int extractionRevision, gridRevision;
  final List<String> headers;
  final List<List<OcrReviewedValue>> rows;
  final int orientedWidth, orientedHeight;
}

final class OcrReviewedValue {
  const OcrReviewedValue({
    required this.reviewedText,
    required this.recognizedText,
    required this.origin,
    required this.polygon,
    required this.gridRow,
    required this.gridColumn,
  });

  /// NFC text used by the Comparison Engine.
  final String reviewedText;

  /// Raw recognizer output; `null` when the user typed a missed value.
  final String? recognizedText;
  final OcrCorrectionOrigin origin;

  /// Source region in oriented image pixels; empty when no region is known.
  final List<OcrPoint> polygon;
  final int gridRow, gridColumn;
}
