import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import 'ocr_models.dart';
import 'ocr_table_reconstructor.dart';
import 'vietnamese_text.dart';

/// Port for Step 2 (image preprocessing: EXIF orientation, rotation, crop /
/// perspective rectification, contrast enhancement) and Step 3 (OCR character
/// recognition).
abstract interface class OcrRecognitionPort {
  String get engineId;

  Future<OcrProcessedImage> preprocess(
    Uint8List rawBytes,
    OcrPreprocessSettings settings,
  );

  Future<List<OcrToken>> recognize(OcrProcessedImage image);
}

final class OcrProcessedImage {
  const OcrProcessedImage({
    required this.pngBytes,
    required this.geometry,
  });
  final Uint8List pngBytes;
  final OcrGeometry geometry;
}

enum OcrPipelineStage {
  preprocess,
  recognizing,
  gridStructure,
  cellReview,
}

/// Manages the 6-step OCR workflow for a single captured/selected image:
///
/// 1. Image artifact capture/selection + SHA-256 provenance
/// 2. Image preprocessing (rotate, crop/perspective, contrast)
/// 3. Character recognition (OCR)
/// 4. Table row/column/cell reconstruction
/// 5. User inspection & correction (grid confirmation FIRST, then per-cell receipts)
/// 6. Normalization → `OcrReviewedTable` ready for the Comparison Engine
///
/// Enforces:
/// - **INP-RULE-037 / OCR-RULE-004**: High confidence never bypasses review.
/// - **INP-RULE-038 / OCR-RULE-005**: Changing image, crop, perspective or grid
///   structure invalidates affected cell receipts; grid must be confirmed before
///   cells can be confirmed.
/// - **INP-RULE-039 / OCR-RULE-007**: Leading zeros (`00123`) stay text;
///   missing detections entered by the user are traced as `userEntered` with
///   `recognizedText == null`.
final class OcrSession extends ChangeNotifier {
  OcrSession({
    required this.port,
    required this.label,
    required this.rawBytes,
    OcrPreprocessSettings initialSettings = const OcrPreprocessSettings(),
  }) : artifactSha256 = sha256.convert(rawBytes).toString(),
       _settings = initialSettings;

  final OcrRecognitionPort port;
  final String label;
  final Uint8List rawBytes;
  final String artifactSha256;

  OcrPipelineStage _stage = OcrPipelineStage.preprocess;
  OcrPipelineStage get stage => _stage;

  OcrPreprocessSettings _settings;
  OcrPreprocessSettings get settings => _settings;

  OcrProcessedImage? _processed;
  OcrProcessedImage? get processed => _processed;

  List<OcrToken> _tokens = const [];
  List<OcrToken> get tokens => _tokens;

  OcrGrid _grid = OcrGrid(const []);
  OcrGrid get grid => _grid;

  int _extractionRevision = 0;
  int get extractionRevision => _extractionRevision;

  int _gridRevision = 0;
  int get gridRevision => _gridRevision;

  bool _gridConfirmed = false;
  bool get gridConfirmed => _gridConfirmed;

  bool _busy = false;
  bool get busy => _busy;

  String? _error;
  String? get error => _error;

  final Map<OcrCellRef, String> _editedTexts = {};
  final Map<OcrCellRef, OcrReviewReceipt> _receipts = {};

  Map<OcrCellRef, OcrReviewReceipt> get receipts => Map.unmodifiable(_receipts);

  /// Updates preprocessing parameters and invalidates extraction, grid
  /// confirmation and all review receipts (INP-RULE-038).
  Future<void> updatePreprocess(OcrPreprocessSettings next) async {
    _settings = next;
    _invalidateExtraction();
    await runPreprocessPreview();
  }

  /// Renders the preprocessed preview image without running recognition yet.
  Future<void> runPreprocessPreview() async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      _processed = await port.preprocess(rawBytes, _settings);
      _stage = OcrPipelineStage.preprocess;
    } catch (e) {
      _error = e.toString();
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Runs Step 2 (if needed), Step 3 (OCR) and Step 4 (table reconstruction),
  /// then advances to Step 5a (grid structure confirmation).
  Future<void> runRecognition({int? targetColumns}) async {
    _busy = true;
    _error = null;
    _stage = OcrPipelineStage.recognizing;
    notifyListeners();
    try {
      _processed ??= await port.preprocess(rawBytes, _settings);
      final recognized = await port.recognize(_processed!);
      _extractionRevision++;
      _tokens = List.unmodifiable(recognized);
      _grid = OcrTableReconstructor.reconstruct(
        _tokens,
        targetColumns: targetColumns,
      );
      _gridRevision++;
      _gridConfirmed = false;
      _editedTexts.clear();
      _receipts.clear();
      _stage = OcrPipelineStage.gridStructure;
    } catch (e) {
      _error = e.toString();
      _stage = OcrPipelineStage.preprocess;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  void returnToPreprocess() {
    _stage = OcrPipelineStage.preprocess;
    notifyListeners();
  }

  // ===========================================================================
  // Step 4 & 5a: Table Structure Inspection & Adjustment
  // ===========================================================================

  /// Re-clusters tokens with an explicit column count and invalidates all
  /// previous cell receipts.
  void reclusterColumns(int columnCount) {
    if (columnCount < 1 || columnCount > 32) return;
    _grid = OcrTableReconstructor.reconstruct(
      _tokens,
      targetColumns: columnCount,
      hasHeader: _grid.hasHeader,
    );
    _bumpGridRevision();
  }

  void setHasHeader(bool value) {
    if (_grid.hasHeader == value) return;
    _grid = OcrTableReconstructor.recomputeRisks(
      _grid.copyWith(hasHeader: value),
    );
    _bumpGridRevision();
  }

  void insertRow(int index) {
    if (_grid.columnCount == 0) return;
    final clamped = index.clamp(0, _grid.rowCount);
    final rows = [
      for (final r in _grid.cells) [...r],
    ];
    rows.insert(
      clamped,
      List.generate(
        _grid.columnCount,
        (_) => const OcrCell(risks: {OcrRisk.blank}),
      ),
    );
    _grid = OcrTableReconstructor.recomputeRisks(
      OcrGrid(rows, hasHeader: _grid.hasHeader),
    );
    _bumpGridRevision();
  }

  void removeRow(int index) {
    if (_grid.rowCount <= 1 || index < 0 || index >= _grid.rowCount) return;
    final rows = [
      for (var r = 0; r < _grid.rowCount; r++)
        if (r != index) [..._grid.cells[r]],
    ];
    _grid = OcrTableReconstructor.recomputeRisks(
      OcrGrid(rows, hasHeader: _grid.hasHeader),
    );
    _bumpGridRevision();
  }

  void insertColumn(int index) {
    if (_grid.rowCount == 0) return;
    final clamped = index.clamp(0, _grid.columnCount);
    final rows = <List<OcrCell>>[];
    for (final r in _grid.cells) {
      final copy = [...r];
      copy.insert(clamped, const OcrCell(risks: {OcrRisk.blank}));
      rows.add(copy);
    }
    _grid = OcrTableReconstructor.recomputeRisks(
      OcrGrid(rows, hasHeader: _grid.hasHeader),
    );
    _bumpGridRevision();
  }

  void removeColumn(int index) {
    if (_grid.columnCount <= 1 || index < 0 || index >= _grid.columnCount) {
      return;
    }
    final rows = <List<OcrCell>>[
      for (final r in _grid.cells)
        [
          for (var c = 0; c < _grid.columnCount; c++)
            if (c != index) r[c],
        ],
    ];
    _grid = OcrTableReconstructor.recomputeRisks(
      OcrGrid(rows, hasHeader: _grid.hasHeader),
    );
    _bumpGridRevision();
  }

  /// Merges column [index] with [index + 1].
  void mergeColumnRight(int index) {
    if (index < 0 || index >= _grid.columnCount - 1) return;
    final rows = <List<OcrCell>>[];
    for (final r in _grid.cells) {
      final nextRow = <OcrCell>[];
      for (var c = 0; c < _grid.columnCount; c++) {
        if (c == index) {
          nextRow.add(r[c].merge(r[c + 1]));
        } else if (c != index + 1) {
          nextRow.add(r[c]);
        }
      }
      rows.add(nextRow);
    }
    _grid = OcrTableReconstructor.recomputeRisks(
      OcrGrid(rows, hasHeader: _grid.hasHeader),
    );
    _bumpGridRevision();
  }

  /// Splits a cell's text across [cell] and its right neighbour at whitespace
  /// (inserting a new column if [cell] is in the last column).
  void splitCellRight(OcrCellRef cell) {
    if (cell.row < 0 ||
        cell.row >= _grid.rowCount ||
        cell.column < 0 ||
        cell.column >= _grid.columnCount) {
      return;
    }
    final source = _grid.cells[cell.row][cell.column];
    final raw = (currentText(cell)).trim();
    if (raw.isEmpty) return;
    final parts = raw.split(RegExp(r'\s+'));
    if (parts.length < 2) return;
    final mid = parts.length ~/ 2;
    final leftText = parts.sublist(0, mid).join(' ');
    final rightText = parts.sublist(mid).join(' ');

    var rows = [
      for (final r in _grid.cells) [...r],
    ];
    if (cell.column == _grid.columnCount - 1) {
      for (final r in rows) {
        r.add(const OcrCell(risks: {OcrRisk.blank}));
      }
    }
    rows[cell.row][cell.column] = OcrCell(
      recognizedText: leftText,
      confidence: source.confidence,
      box: source.box,
      tokenCount: 1,
    );
    final rightOriginal = rows[cell.row][cell.column + 1];
    final combinedRight = rightOriginal.detected
        ? '$rightText ${rightOriginal.recognizedText}'
        : rightText;
    rows[cell.row][cell.column + 1] = OcrCell(
      recognizedText: combinedRight,
      confidence: source.confidence ?? rightOriginal.confidence,
      box: rightOriginal.box ?? source.box,
      tokenCount: 1 + rightOriginal.tokenCount,
    );
    _grid = OcrTableReconstructor.recomputeRisks(
      OcrGrid(rows, hasHeader: _grid.hasHeader),
    );
    _bumpGridRevision();
  }

  /// Confirms the row/column grid layout (OCR-RULE-005). Only after this step
  /// can individual cell receipts be issued.
  void confirmGridStructure() {
    if (_grid.rowCount == 0 || _grid.columnCount == 0) {
      _error = 'Bảng chưa có hàng hoặc cột để xác nhận.';
      notifyListeners();
      return;
    }
    if (_grid.hasHeader && _grid.rowCount < 2) {
      _error = 'Bảng có dòng tiêu đề cần ít nhất 1 dòng dữ liệu bên dưới.';
      notifyListeners();
      return;
    }
    _error = null;
    _gridConfirmed = true;
    _stage = OcrPipelineStage.cellReview;
    notifyListeners();
  }

  /// Re-opens grid editing and invalidates cell review receipts.
  void unlockGridStructure() {
    _gridConfirmed = false;
    _receipts.clear();
    _stage = OcrPipelineStage.gridStructure;
    notifyListeners();
  }

  // ===========================================================================
  // Step 5b: Cell Inspection, Vietnamese NFC & Receipt Issuance
  // ===========================================================================

  /// Returns the current NFC-normalized text for [ref]. Raw `recognizedText` on
  /// the underlying `OcrCell` is never mutated.
  String currentText(OcrCellRef ref) {
    final edited = _editedTexts[ref];
    if (edited != null) return VietnameseText.nfc(edited);
    if (ref.row < 0 ||
        ref.row >= _grid.rowCount ||
        ref.column < 0 ||
        ref.column >= _grid.columnCount) {
      return '';
    }
    return VietnameseText.nfc(_grid.cells[ref.row][ref.column].recognizedText ?? '');
  }

  /// Edits the reviewed text for [ref] and invalidates any existing receipt for
  /// that cell until the user confirms the new value.
  void editCellText(OcrCellRef ref, String value) {
    final normalized = VietnameseText.nfc(value);
    _editedTexts[ref] = normalized;
    _receipts.remove(ref);
    notifyListeners();
  }

  bool isCellConfirmed(OcrCellRef ref) {
    final receipt = _receipts[ref];
    if (receipt == null) return false;
    return receipt.artifactSha256 == artifactSha256 &&
        receipt.extractionRevision == _extractionRevision &&
        receipt.gridRevision == _gridRevision &&
        receipt.reviewedTextDigest == _digestText(currentText(ref));
  }

  /// Issues a review receipt for a single cell. Requires the grid structure to
  /// be confirmed first (OCR-RULE-005).
  void confirmCell(OcrCellRef ref) {
    if (!_gridConfirmed) return;
    if (ref.row < 0 ||
        ref.row >= _grid.rowCount ||
        ref.column < 0 ||
        ref.column >= _grid.columnCount) {
      return;
    }
    final text = currentText(ref);
    if (_grid.hasHeader && ref.row == 0 && text.trim().isEmpty) {
      _error = 'Ô tiêu đề cột (${ref.toString()}) không được để trống.';
      notifyListeners();
      return;
    }
    _error = null;
    _receipts[ref] = OcrReviewReceipt(
      cell: ref,
      artifactSha256: artifactSha256,
      extractionRevision: _extractionRevision,
      gridRevision: _gridRevision,
      reviewedTextDigest: _digestText(text),
      reviewedAt: DateTime.now().toUtc(),
    );
    notifyListeners();
  }

  void unconfirmCell(OcrCellRef ref) {
    if (_receipts.remove(ref) != null) {
      notifyListeners();
    }
  }

  /// Confirms all cells that carry no structural or recognition risk warnings.
  /// Flagged cells still require individual confirmation.
  int confirmUnflaggedCells() {
    if (!_gridConfirmed) return 0;
    var count = 0;
    for (var r = 0; r < _grid.rowCount; r++) {
      for (var c = 0; c < _grid.columnCount; c++) {
        final ref = OcrCellRef(r, c);
        final cell = _grid.cells[r][c];
        if (cell.risks.isEmpty && !isCellConfirmed(ref)) {
          final text = currentText(ref);
          if (_grid.hasHeader && r == 0 && text.trim().isEmpty) continue;
          _receipts[ref] = OcrReviewReceipt(
            cell: ref,
            artifactSha256: artifactSha256,
            extractionRevision: _extractionRevision,
            gridRevision: _gridRevision,
            reviewedTextDigest: _digestText(text),
            reviewedAt: DateTime.now().toUtc(),
          );
          count++;
        }
      }
    }
    if (count > 0) notifyListeners();
    return count;
  }

  int get confirmedCellCount {
    var count = 0;
    for (var r = 0; r < _grid.rowCount; r++) {
      for (var c = 0; c < _grid.columnCount; c++) {
        if (isCellConfirmed(OcrCellRef(r, c))) count++;
      }
    }
    return count;
  }

  int get totalCellCount => _grid.cellCount;

  int get flaggedCellCount {
    var count = 0;
    for (final row in _grid.cells) {
      for (final cell in row) {
        if (cell.risks.isNotEmpty) count++;
      }
    }
    return count;
  }

  bool get readyToNormalize =>
      _gridConfirmed &&
      totalCellCount > 0 &&
      confirmedCellCount == totalCellCount &&
      (!_grid.hasHeader || _grid.rowCount >= 2);

  // ===========================================================================
  // Step 6: Normalize → Validated Table for Comparison Engine
  // ===========================================================================

  OcrReviewedTable finalizeTable() {
    if (!readyToNormalize) {
      throw StateError(
        'Cannot finalize OCR table before grid and all cells are confirmed.',
      );
    }
    final geometry = _processed!.geometry;
    final colCount = _grid.columnCount;

    final rawHeaders = _grid.hasHeader
        ? [
            for (var c = 0; c < colCount; c++)
              currentText(OcrCellRef(0, c)).trim(),
          ]
        : [for (var c = 0; c < colCount; c++) 'Cột ${c + 1}'];

    final usedHeaders = <String>{};
    final headers = <String>[];
    for (var c = 0; c < colCount; c++) {
      final base = rawHeaders[c].isEmpty ? 'Cột ${c + 1}' : rawHeaders[c];
      var candidate = base;
      var suffix = 1;
      while (usedHeaders.contains(candidate)) {
        candidate = '$base (${++suffix})';
      }
      usedHeaders.add(candidate);
      headers.add(candidate);
    }

    final startRow = _grid.hasHeader ? 1 : 0;
    final rows = <List<OcrReviewedValue>>[];
    for (var r = startRow; r < _grid.rowCount; r++) {
      final rowValues = <OcrReviewedValue>[];
      for (var c = 0; c < colCount; c++) {
        final ref = OcrCellRef(r, c);
        final cell = _grid.cells[r][c];
        final reviewed = currentText(ref);
        final rawRecognized = cell.recognizedText;
        final origin = !cell.detected
            ? OcrCorrectionOrigin.userEntered
            : (VietnameseText.nfc(rawRecognized!) == reviewed
                  ? OcrCorrectionOrigin.recognized
                  : OcrCorrectionOrigin.userEdited);
        final polygon = cell.box == null
            ? const <OcrPoint>[]
            : geometry.polygonToOriented(cell.box!.corners);
        rowValues.add(
          OcrReviewedValue(
            reviewedText: reviewed,
            recognizedText: rawRecognized,
            origin: origin,
            polygon: polygon,
            gridRow: r,
            gridColumn: c,
          ),
        );
      }
      rows.add(rowValues);
    }

    return OcrReviewedTable(
      label: label,
      artifactSha256: artifactSha256,
      engine: port.engineId,
      extractionRevision: _extractionRevision,
      gridRevision: _gridRevision,
      headers: headers,
      rows: rows,
      orientedWidth: geometry.orientedWidth,
      orientedHeight: geometry.orientedHeight,
    );
  }

  void _invalidateExtraction() {
    _processed = null;
    _tokens = const [];
    _grid = OcrGrid(const []);
    _gridConfirmed = false;
    _editedTexts.clear();
    _receipts.clear();
  }

  void _bumpGridRevision() {
    _gridRevision++;
    _gridConfirmed = false;
    _editedTexts.clear();
    _receipts.clear();
    notifyListeners();
  }

  static String _digestText(String text) =>
      sha256.convert(utf8.encode(text)).toString();
}
