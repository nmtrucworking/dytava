import 'package:excelcompare_core/excelcompare_core.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../../domain/workflow.dart';
import '../../infrastructure/demo/demo_workflow_ports.dart';
import '../domain/ocr_models.dart';
import '../domain/ocr_session.dart';
import 'mlkit_ocr_adapter.dart';

/// Isolated OCR repository and bridge into the normalized comparison model
/// (OCR-RULE-001 to OCR-RULE-003).
///
/// The Comparison Engine never imports OCR classes: once an `OcrSession` is
/// finalized (grid confirmed + every cell confirmed with a current receipt),
/// [buildValidatedSnapshot] materializes a standard `InputSnapshot` with
/// `CellKind.ocrText` and `ocrReviewed: true`.
abstract final class OcrCaptureService {
  static final Map<String, OcrSession> _sessions = {};
  static final Map<String, OcrReviewedTable> _finalized = {};

  /// Picks an image via camera or gallery, or creates a realistic Vietnamese
  /// table image session.
  static Future<({String privateRef, String fileName, SourceFormat format})?>
  acquireImage({
    required SourceSide side,
    required OcrImageSourceKind sourceKind,
    OcrRecognitionPort? customPort,
  }) async {
    Uint8List bytes;
    String fileName;
    SourceFormat format;

    switch (sourceKind) {
      case OcrImageSourceKind.camera:
        final picker = ImagePicker();
        final file = await picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 95,
        );
        if (file == null) return null;
        bytes = await file.readAsBytes();
        fileName = file.name.isNotEmpty ? file.name : 'camera_${side.name}.jpg';
        format = _formatForName(fileName);
      case OcrImageSourceKind.gallery:
        final files = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: const ['png', 'jpg', 'jpeg'],
        );
        if (files.isEmpty) return null;
        final picked = files.first;
        bytes = await picked.readAsBytes();
        fileName = picked.name;
        format = _formatForName(fileName);
      case OcrImageSourceKind.vietnameseSample:
        bytes = _buildSampleVietnameseSheetPng();
        fileName = 'bang_doi_soat_tieng_viet.png';
        format = SourceFormat.png;
    }

    if (bytes.isEmpty) {
      throw const FormatException('INP-ERR-004: Tệp ảnh không có dữ liệu.');
    }

    final port =
        customPort ??
        (sourceKind == OcrImageSourceKind.vietnameseSample
            ? const SampleVietnameseOcrRecognitionAdapter()
            : MlKitOcrRecognitionAdapter());

    return registerSession(
      side: side,
      fileName: fileName,
      format: format,
      rawBytes: bytes,
      port: port,
    );
  }

  /// Registers an OCR session directly (used by device pickers and tests).
  static ({String privateRef, String fileName, SourceFormat format})
  registerSession({
    required SourceSide side,
    required String fileName,
    required SourceFormat format,
    required Uint8List rawBytes,
    required OcrRecognitionPort port,
  }) {
    _sessions.removeWhere((k, _) => k.endsWith('_${side.name}'));
    _finalized.removeWhere((k, _) => k.endsWith('_${side.name}'));
    final ref = 'ocr:${DateTime.now().microsecondsSinceEpoch}_${side.name}';
    _sessions[ref] = OcrSession(
      port: port,
      label: fileName,
      rawBytes: rawBytes,
    );
    return (privateRef: ref, fileName: fileName, format: format);
  }

  static bool isOcrRef(String privateRef) => privateRef.startsWith('ocr:');

  static OcrSession? session(String privateRef) => _sessions[privateRef];

  static String? sha256Of(String privateRef) =>
      _sessions[privateRef]?.artifactSha256;

  /// Returns estimated byte size of currently loaded OCR image sessions.
  static int estimatedMemoryBytes() {
    int total = 0;
    for (final s in _sessions.values) {
      total += s.rawBytes.length;
    }
    return total;
  }

  static OcrReviewedTable? finalizedTable(String privateRef) =>
      _finalized[privateRef];

  /// Finalizes [session] after all grid and cell receipts are confirmed and
  /// stores the normalized `OcrReviewedTable`.
  static OcrReviewedTable commitFinalized(String privateRef) {
    final current = _sessions[privateRef];
    if (current == null) {
      throw const WorkflowIssue(
        'OCR_SESSION_NOT_FOUND',
        'Không tìm thấy phiên OCR của ảnh đã chọn.',
      );
    }
    if (!current.readyToNormalize) {
      throw const WorkflowIssue(
        'OCR_REVIEW_REQUIRED',
        'Cần xác nhận cấu trúc lưới bảng và mọi ô dữ liệu trước khi chuẩn hóa.',
      );
    }
    final table = current.finalizeTable();
    _finalized[privateRef] = table;
    DemoInputPort.registerUserFile(
      privateRef,
      fileName: table.label,
      format: _formatForName(table.label),
      fields: [for (final h in table.headers) TableField(h, h)],
      values: [
        for (final row in table.rows)
          [for (final cell in row) cell.reviewedText],
      ],
      headerRow: current.grid.hasHeader ? 1 : 0,
    );
    return table;
  }

  /// Materializes the `InputOutcome` for `MobileInputPort`.
  ///
  /// If the session has not yet been finalized (or its receipts were invalidated
  /// by a crop/grid edit), returns `ImportOutcome.review` with the cells that
  /// still require review.
  static ImportOutcome outcomeFor({
    required SourceArtifact artifact,
    required ImportBinding binding,
  }) {
    final current = _sessions[artifact.privateRef];
    final table = _finalized[artifact.privateRef];
    if (current != null &&
        table != null &&
        current.readyToNormalize &&
        table.extractionRevision == current.extractionRevision &&
        table.gridRevision == current.gridRevision) {
      return ImportOutcome.ready(
        buildValidatedSnapshot(
          artifact: artifact,
          binding: binding,
          table: table,
        ),
      );
    }

    final pendingCells = <ReviewCell>[];
    if (current != null && current.grid.cellCount > 0) {
      for (var r = 0; r < current.grid.rowCount; r++) {
        for (var c = 0; c < current.grid.columnCount; c++) {
          final ref = OcrCellRef(r, c);
          if (!current.isCellConfirmed(ref)) {
            pendingCells.add(
              ReviewCell(ref.toString(), current.currentText(ref)),
            );
          }
        }
      }
    }
    if (pendingCells.isEmpty) {
      pendingCells.add(const ReviewCell('R1C1', ''));
    }

    return ImportOutcome.review(
      ImportReview(
        const WorkflowIssue(
          'OCR_REVIEW_REQUIRED',
          'Cần hoàn tất tiền xử lý, xác nhận cấu trúc hàng/cột và duyệt từng ô OCR trước khi đối chiếu.',
        ),
        cells: pendingCells,
      ),
    );
  }

  /// Converts a finalized `OcrReviewedTable` into the standard `InputSnapshot`
  /// consumed by the Comparison Engine.
  static InputSnapshot buildValidatedSnapshot({
    required SourceArtifact artifact,
    required ImportBinding binding,
    required OcrReviewedTable table,
  }) {
    final fields = [for (final h in table.headers) TableField(h, h)];
    final records = <TableRecord>[];
    for (var r = 0; r < table.rows.length; r++) {
      final row = table.rows[r];
      final cells = <String, SourceCell>{};
      final locations = <String, String>{};
      for (var c = 0; c < fields.length; c++) {
        final field = fields[c];
        final value = row[c];
        cells[field.id] = SourceCell(
          CellKind.ocrText,
          rawLexeme: value.reviewedText,
          ocrReviewed: true,
        );
        locations[field.id] = _formatOrientedLocation(
          artifact.label,
          value,
        );
      }
      records.add(
        TableRecord(
          '${artifact.id}-ocr-row-$r',
          r,
          cells,
          locations,
        ),
      );
    }
    return InputSnapshot(
      id: '${artifact.id}-ocr-snapshot-${binding.revision}-${binding.attempt}',
      binding: binding,
      fields: fields,
      records: records,
      fullValidation: true,
      ocrReviewed: true,
    );
  }

  static void release(String privateRef) {
    _sessions.remove(privateRef)?.dispose();
    _finalized.remove(privateRef);
    DemoInputPort.forgetUserFile(privateRef);
  }

  static void clear() {
    for (final s in _sessions.values) {
      s.dispose();
    }
    _sessions.clear();
    _finalized.clear();
  }

  static SourceFormat _formatForName(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return SourceFormat.jpeg;
    }
    return SourceFormat.png;
  }

  static String _formatOrientedLocation(
    String label,
    OcrReviewedValue value,
  ) {
    final rc = 'R${value.gridRow + 1}C${value.gridColumn + 1}';
    if (value.polygon.isEmpty) {
      return '$label!$rc[user_entered]';
    }
    final box = OcrBox.fromPoints(value.polygon);
    return '$label!$rc'
        '[px:${box.left.round()},${box.top.round()}-${box.right.round()},${box.bottom.round()}]';
  }

  /// Renders a clean synthetic spreadsheet image with grid lines and cell blocks
  /// so the preprocessing crop, rotation, contrast and overlay boxes are
  /// visibly interactive in sample/test sessions.
  static Uint8List _buildSampleVietnameseSheetPng() {
    final canvas = img.Image(width: 520, height: 280);
    img.fill(canvas, color: img.ColorRgb8(248, 250, 249));
    // Header band
    img.fillRect(
      canvas,
      x1: 16,
      y1: 16,
      x2: 504,
      y2: 56,
      color: img.ColorRgb8(231, 243, 235),
    );
    // Horizontal grid lines
    for (final y in [16, 56, 104, 152, 200, 248]) {
      img.drawLine(
        canvas,
        x1: 16,
        y1: y,
        x2: 504,
        y2: y,
        color: img.ColorRgb8(203, 213, 225),
      );
    }
    // Vertical grid lines
    for (final x in [16, 136, 344, 504]) {
      img.drawLine(
        canvas,
        x1: x,
        y1: 16,
        x2: x,
        y2: 248,
        color: img.ColorRgb8(203, 213, 225),
      );
    }
    // Simulated glyph bars inside cells
    for (final tok in SampleVietnameseOcrRecognitionAdapter.defaultVietnameseTokens()) {
      final b = tok.box;
      final isHeader = tok.lineIndex == 0;
      img.fillRect(
        canvas,
        x1: b.left.round(),
        y1: (b.top + 4).round(),
        x2: b.right.round(),
        y2: (b.bottom - 4).round(),
        color: isHeader
            ? img.ColorRgb8(16, 124, 65)
            : img.ColorRgb8(100, 116, 139),
      );
    }
    return Uint8List.fromList(img.encodePng(canvas));
  }
}

enum OcrImageSourceKind { camera, gallery, vietnameseSample }
