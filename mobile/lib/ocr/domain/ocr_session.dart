import 'dart:convert';
import 'dart:ui' show Rect;

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
  const OcrProcessedImage({required this.pngBytes, required this.geometry});
  final Uint8List pngBytes;
  final OcrGeometry geometry;
}

enum OcrPipelineStage { preprocess, recognizing, gridStructure, cellReview }

/// Manages the 6-step OCR workflow for a single captured/selected image:
///
/// 1. Image artifact capture/selection + SHA-256 provenance
/// 2. Image preprocessing (rotate, crop/perspective, contrast)
/// 3. Character recognition (OCR)
/// 4. Table row/column/cell reconstruction
/// 5. User inspection & correction (grid confirmation FIRST, then per-cell receipts)
/// 6. Normalization → `OcrReviewedTable` ready for the Comparison Engine
///
/// Supports four explicit detection states:
/// - [OcrDetectionState.noTextDetected]
/// - [OcrDetectionState.textWithoutTable]
/// - [OcrDetectionState.tableDetected]
/// - [OcrDetectionState.processingFailed]
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

  OcrDetectionState _detectionState = OcrDetectionState.noTextDetected;
  OcrDetectionState get detectionState => _detectionState;

  bool _tableRegionConfirmed = false;
  bool get tableRegionConfirmed => _tableRegionConfirmed;

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
      _detectionState = OcrDetectionState.processingFailed;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Confirms the selected table bounding box (normalized `[0, 1]` left, top,
  /// right, bottom on the currently rotated/flipped image) and immediately runs
  /// preprocessing + OCR recognition on that cropped region.
  Future<void> confirmTableBboxAndRecognize({
    Rect? normalizedBbox,
    int? quarterTurns,
    bool? flipHorizontal,
    bool? flipVertical,
  }) async {
    _clearRecognizedTable();
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      _processed = await port.preprocess(
        rawBytes,
        _settings.copyWith(
          quarterTurns: (quarterTurns ?? _settings.quarterTurns) % 4,
          flipHorizontal: flipHorizontal ?? _settings.flipHorizontal,
          flipVertical: flipVertical ?? _settings.flipVertical,
          clearCorners: true,
        ),
      );
      _settings = _settings.copyWith(
        quarterTurns: (quarterTurns ?? _settings.quarterTurns) % 4,
        flipHorizontal: flipHorizontal ?? _settings.flipHorizontal,
        flipVertical: flipVertical ?? _settings.flipVertical,
        clearCorners: true,
      );
      if (normalizedBbox != null) {
        final geom = _processed!.geometry;
        final rw = (geom.rotatedWidth - 1).clamp(1, 100000).toDouble();
        final rh = (geom.rotatedHeight - 1).clamp(1, 100000).toDouble();
        final l = (normalizedBbox.left.clamp(0.0, 0.95) * rw);
        final t = (normalizedBbox.top.clamp(0.0, 0.95) * rh);
        final r = (normalizedBbox.right.clamp(0.05, 1.0) * rw);
        final b = (normalizedBbox.bottom.clamp(0.05, 1.0) * rh);
        _settings = _settings.copyWith(
          corners: [
            OcrPoint(l, t),
            OcrPoint(r, t),
            OcrPoint(r, b),
            OcrPoint(l, b),
          ],
        );
        _processed = await port.preprocess(rawBytes, _settings);
      }
      _tableRegionConfirmed = true;
    } catch (e) {
      _error = e.toString();
      _detectionState = OcrDetectionState.processingFailed;
      _busy = false;
      notifyListeners();
      return;
    }
    await runRecognition();
  }

  /// Runs Step 2 (if needed), Step 3 (OCR) and Step 4 (table reconstruction),
  /// evaluates the [OcrDetectionState] (`noTextDetected`, `textWithoutTable`,
  /// `tableDetected`, `processingFailed`), and advances to the unified table
  /// review stage (`gridStructure`).
  Future<void> runRecognition({int? targetColumns}) async {
    _clearRecognizedTable();
    _busy = true;
    _error = null;
    _tableRegionConfirmed = true;
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
      _detectionState = _evaluateDetectionState(_tokens, _grid);
      _stage = OcrPipelineStage.gridStructure;
    } catch (e) {
      _error = e.toString();
      _detectionState = OcrDetectionState.processingFailed;
      _stage = OcrPipelineStage.gridStructure;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// One-tap approval from the unified table review view: confirms the grid
  /// structure and issues review receipts for all cells in the table so the
  /// user is not forced to click through 78+ individual cells.
  void approveTableForImport() {
    confirmGridStructure(autoConfirmCleanCells: true);
    if (_gridConfirmed) {
      confirmAllCells();
    }
  }

  static OcrDetectionState _evaluateDetectionState(
    List<OcrToken> tokens,
    OcrGrid grid,
  ) {
    final nonBlankTokens = tokens
        .where((t) => t.text.trim().isNotEmpty)
        .toList();
    if (nonBlankTokens.isEmpty || grid.cellCount == 0) {
      return OcrDetectionState.noTextDetected;
    }
    // Check whether the tokens actually form a tabular structure (at least
    // 2 columns OR at least 2 rows). A single isolated line/block with 1x1 is
    // free text without table structure.
    final isStructuredTable =
        (grid.rowCount >= 2 && grid.columnCount >= 1) &&
        (grid.columnCount >= 2 || grid.rowCount >= 3);
    if (!isStructuredTable) {
      return OcrDetectionState.textWithoutTable;
    }
    return OcrDetectionState.tableDetected;
  }

  void returnToPreprocess() {
    _tableRegionConfirmed = false;
    _settings = _settings.copyWith(clearCorners: true);
    _processed = null;
    _stage = OcrPipelineStage.preprocess;
    notifyListeners();
    runPreprocessPreview();
  }

  // ===========================================================================
  // Step 4 & 5a: Table Structure Inspection, Manual Table Creation & Adjustment
  // ===========================================================================

  /// Creates a manual table skeleton when automatic detection produced
  /// `noTextDetected` or `textWithoutTable` ("Tạo bảng thủ công").
  ///
  /// Any recognized tokens are placed sequentially into the first rows/columns
  /// so the user does not lose recognized text.
  void createManualTable({
    int rows = 3,
    int columns = 2,
    bool hasHeader = true,
  }) {
    final rCount = rows.clamp(2, 50);
    final cCount = columns.clamp(1, 16);
    final nonEmptyTokens = _tokens
        .where((t) => t.text.trim().isNotEmpty)
        .toList();

    final builtRows = <List<OcrCell>>[];
    var tokenCursor = 0;
    for (var r = 0; r < rCount; r++) {
      final row = <OcrCell>[];
      for (var c = 0; c < cCount; c++) {
        if (r == 0 && hasHeader && nonEmptyTokens.isEmpty) {
          row.add(
            OcrCell(
              recognizedText: c == 0
                  ? 'Mã'
                  : (c == 1 ? 'Giá trị' : 'Cột ${c + 1}'),
              confidence: 1.0,
            ),
          );
        } else if (tokenCursor < nonEmptyTokens.length) {
          final tok = nonEmptyTokens[tokenCursor++];
          row.add(
            OcrCell(
              recognizedText: tok.text.trim(),
              confidence: tok.confidence,
              box: tok.box,
              tokenCount: 1,
            ),
          );
        } else {
          row.add(const OcrCell(risks: {OcrRisk.blank}));
        }
      }
      builtRows.add(row);
    }

    _grid = OcrTableReconstructor.recomputeRisks(
      OcrGrid(builtRows, hasHeader: hasHeader),
    );
    _detectionState = OcrDetectionState.tableDetected;
    _error = null;
    _bumpGridRevision();
    _stage = OcrPipelineStage.gridStructure;
  }

  /// Re-clusters tokens with an explicit column count and invalidates all
  /// previous cell receipts.
  void reclusterColumns(int columnCount) {
    if (columnCount < 1 || columnCount > 32) return;
    if (_tokens.isEmpty) {
      createManualTable(
        rows: _grid.rowCount >= 2 ? _grid.rowCount : 3,
        columns: columnCount,
        hasHeader: _grid.hasHeader,
      );
      return;
    }
    _grid = OcrTableReconstructor.reconstruct(
      _tokens,
      targetColumns: columnCount,
      hasHeader: _grid.hasHeader,
    );
    _detectionState = OcrDetectionState.tableDetected;
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
    if (_grid.columnCount == 0) {
      createManualTable(rows: 3, columns: 2);
      return;
    }
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
    _detectionState = OcrDetectionState.tableDetected;
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
    if (_grid.rowCount == 0) {
      createManualTable(rows: 3, columns: 2);
      return;
    }
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
    _detectionState = OcrDetectionState.tableDetected;
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

  /// Confirms the row/column grid layout (OCR-RULE-005), moves to Step 3/3
  /// (`cellReview`) and automatically pre-confirms clean (unflagged) cells so
  /// the user only has to inspect flagged cells or review exceptions.
  void confirmGridStructure({bool autoConfirmCleanCells = false}) {
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
    if (autoConfirmCleanCells) {
      confirmUnflaggedCells();
    }
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
    return VietnameseText.nfc(
      _grid.cells[ref.row][ref.column].recognizedText ?? '',
    );
  }

  /// Edits the reviewed text for [ref] and invalidates any existing receipt for
  /// that cell until the user confirms the new value.
  void editCellText(OcrCellRef ref, String value) {
    final normalized = VietnameseText.nfc(value);
    _editedTexts[ref] = normalized;
    _receipts.remove(ref);
    notifyListeners();
  }

  /// Convenience for bottom-sheet editing: updates cell text and immediately
  /// issues a review receipt in one tap.
  void saveAndConfirmCell(OcrCellRef ref, String value) {
    final normalized = VietnameseText.nfc(value);
    _editedTexts[ref] = normalized;
    confirmCell(ref);
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
      _error = 'Ô tiêu đề cột ($ref) không được để trống.';
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

  /// Confirms all remaining cells in the table when the user explicitly chooses
  /// to approve the whole reviewed grid.
  int confirmAllCells() {
    if (!_gridConfirmed) return 0;
    var count = 0;
    for (var r = 0; r < _grid.rowCount; r++) {
      for (var c = 0; c < _grid.columnCount; c++) {
        final ref = OcrCellRef(r, c);
        if (!isCellConfirmed(ref)) {
          final text = currentText(ref);
          if (_grid.hasHeader && r == 0 && text.trim().isEmpty) {
            _editedTexts[ref] = 'Cột ${c + 1}';
          }
          final finalText = currentText(ref);
          _receipts[ref] = OcrReviewReceipt(
            cell: ref,
            artifactSha256: artifactSha256,
            extractionRevision: _extractionRevision,
            gridRevision: _gridRevision,
            reviewedTextDigest: _digestText(finalText),
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

  int get unconfirmedFlaggedCount {
    var count = 0;
    for (var r = 0; r < _grid.rowCount; r++) {
      for (var c = 0; c < _grid.columnCount; c++) {
        final ref = OcrCellRef(r, c);
        if (_grid.cells[r][c].risks.isNotEmpty && !isCellConfirmed(ref)) {
          count++;
        }
      }
    }
    return count;
  }

  bool get readyToNormalize =>
      !_busy &&
      _detectionState == OcrDetectionState.tableDetected &&
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
    _clearRecognizedTable();
    _tableRegionConfirmed = false;
  }

  void _clearRecognizedTable() {
    _tokens = const [];
    _grid = OcrGrid(const []);
    _gridRevision++;
    _gridConfirmed = false;
    _editedTexts.clear();
    _receipts.clear();
    _detectionState = OcrDetectionState.noTextDetected;
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
