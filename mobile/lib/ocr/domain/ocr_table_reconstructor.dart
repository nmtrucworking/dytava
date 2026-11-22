import 'dart:math' as math;

import 'ocr_models.dart';
import 'vietnamese_text.dart';

/// Reconstructs a tabular grid from OCR tokens and computes structural risks
/// (OCR-RULE-004 to OCR-RULE-007).
///
/// Text recognition and table structure reconstruction are kept separate:
/// character confidence never implies structural correctness, and empty cells
/// are never backfilled by interpolation or neighbouring values.
abstract final class OcrTableReconstructor {
  static const lowConfidenceThreshold = 0.85;

  /// Reconstructs a grid from [tokens].
  ///
  /// When [targetColumns] is provided (>= 1), tokens are clustered/binned into
  /// that number of columns.
  static OcrGrid reconstruct(
    List<OcrToken> tokens, {
    int? targetColumns,
    bool? hasHeader,
  }) {
    final cleaned = tokens
        .where((t) => t.text.trim().isNotEmpty && t.polygon.isNotEmpty)
        .toList();
    if (cleaned.isEmpty) {
      return OcrGrid(const [], hasHeader: hasHeader ?? false);
    }

    final rowGroups = _groupIntoRows(cleaned);
    if (rowGroups.isEmpty) {
      return OcrGrid(const [], hasHeader: hasHeader ?? false);
    }

    final rawSegmentsPerRow = [
      for (final row in rowGroups) _mergeRowSegments(row),
    ];

    final prunedRows = _pruneBannerAndSuperHeaderRows(rawSegmentsPerRow);
    final segmentsPerRow = prunedRows.isEmpty ? rawSegmentsPerRow : prunedRows;

    final columns = _inferColumns(
      segmentsPerRow,
      targetColumns: targetColumns,
    );
    final colCount = columns.length;

    final rawRows = <List<_CellDraft>>[];
    for (final segments in segmentsPerRow) {
      final rowDrafts = List.generate(colCount, (_) => _CellDraft());
      for (final seg in segments) {
        final colIndex = _assignColumn(seg, columns);
        final crossesBoundary = _crossesColumnBoundary(seg, columns, colIndex);
        rowDrafts[colIndex].add(seg, crossesBoundary: crossesBoundary);
      }
      rawRows.add(rowDrafts);
    }

    final detectedCounts = [
      for (final r in rawRows) r.where((d) => d.tokens.isNotEmpty).length,
    ];
    final modalRowOccupancy = _modePositive(detectedCounts, fallback: colCount);

    final colNumericRatio = List<double>.filled(colCount, 0.0);
    for (var c = 0; c < colCount; c++) {
      var nonHeaderTotal = 0;
      var numericCount = 0;
      for (var r = 1; r < rawRows.length; r++) {
        final text = rawRows[r][c].text;
        if (text != null && text.isNotEmpty) {
          nonHeaderTotal++;
          if (_looksNumeric(text)) numericCount++;
        }
      }
      colNumericRatio[c] =
          nonHeaderTotal >= 2 ? numericCount / nonHeaderTotal : 0.0;
    }

    final inferredHeader =
        hasHeader ?? _inferHasHeader(rawRows, colNumericRatio);

    final cells = <List<OcrCell>>[];
    for (var r = 0; r < rawRows.length; r++) {
      final row = rawRows[r];
      final rowHasGap =
          colCount > 1 &&
          detectedCounts[r] > 0 &&
          detectedCounts[r] < modalRowOccupancy;
      final builtRow = <OcrCell>[];
      for (var c = 0; c < colCount; c++) {
        final draft = row[c];
        final text = draft.text;
        final conf = draft.confidence;
        final risks = <OcrRisk>{};

        if (text == null || text.isEmpty) {
          risks.add(OcrRisk.blank);
          if (rowHasGap) risks.add(OcrRisk.rowShape);
        } else {
          if (conf != null && conf < lowConfidenceThreshold) {
            risks.add(OcrRisk.lowConfidence);
          }
          if (VietnameseText.hasDiacriticAnomaly(text) ||
              (VietnameseText.hasVietnameseMarks(text) &&
                  (conf == null || conf < 0.92))) {
            risks.add(OcrRisk.diacritics);
          }
          if (draft.crossesBoundary) {
            risks.add(OcrRisk.spansColumns);
          }
          if (draft.segmentCount > 1) {
            risks.add(OcrRisk.multipleSegments);
          }
          if (rowHasGap) {
            risks.add(OcrRisk.rowShape);
          }
          final isHeaderRow = inferredHeader && r == 0;
          if (!isHeaderRow &&
              colNumericRatio[c] >= 0.65 &&
              !_looksNumeric(text)) {
            risks.add(OcrRisk.typeOutlier);
          }
        }

        builtRow.add(
          OcrCell(
            recognizedText: text,
            confidence: conf,
            box: draft.box,
            tokenCount: draft.tokens.length,
            risks: Set.unmodifiable(risks),
          ),
        );
      }
      cells.add(builtRow);
    }

    return OcrGrid(cells, hasHeader: inferredHeader);
  }

  /// Recomputes structural risks after the user edits grid structure (split,
  /// merge, insert/remove row or column, toggle header).
  static OcrGrid recomputeRisks(OcrGrid grid) {
    if (grid.rowCount == 0 || grid.columnCount == 0) return grid;
    final colCount = grid.columnCount;
    final rowCount = grid.rowCount;

    final detectedCounts = [
      for (final r in grid.cells) r.where((c) => c.detected).length,
    ];
    final modalRowOccupancy = _modePositive(detectedCounts, fallback: colCount);

    final colNumericRatio = List<double>.filled(colCount, 0.0);
    for (var c = 0; c < colCount; c++) {
      var total = 0;
      var numeric = 0;
      for (var r = grid.hasHeader ? 1 : 0; r < rowCount; r++) {
        final text = grid.cells[r][c].recognizedText;
        if (text != null && text.isNotEmpty) {
          total++;
          if (_looksNumeric(text)) numeric++;
        }
      }
      colNumericRatio[c] = total >= 2 ? numeric / total : 0.0;
    }

    final updated = <List<OcrCell>>[];
    for (var r = 0; r < rowCount; r++) {
      final rowHasGap =
          colCount > 1 &&
          detectedCounts[r] > 0 &&
          detectedCounts[r] < modalRowOccupancy;
      final row = <OcrCell>[];
      for (var c = 0; c < colCount; c++) {
        final cell = grid.cells[r][c];
        final text = cell.recognizedText;
        final conf = cell.confidence;
        final risks = <OcrRisk>{
          if (cell.risks.contains(OcrRisk.spansColumns)) OcrRisk.spansColumns,
          if (cell.risks.contains(OcrRisk.multipleSegments))
            OcrRisk.multipleSegments,
        };
        if (text == null || text.isEmpty) {
          risks.add(OcrRisk.blank);
          if (rowHasGap) risks.add(OcrRisk.rowShape);
        } else {
          if (conf != null && conf < lowConfidenceThreshold) {
            risks.add(OcrRisk.lowConfidence);
          }
          if (VietnameseText.hasDiacriticAnomaly(text) ||
              (VietnameseText.hasVietnameseMarks(text) &&
                  (conf == null || conf < 0.92))) {
            risks.add(OcrRisk.diacritics);
          }
          if (rowHasGap) risks.add(OcrRisk.rowShape);
          final isHeaderRow = grid.hasHeader && r == 0;
          if (!isHeaderRow &&
              colNumericRatio[c] >= 0.65 &&
              !_looksNumeric(text)) {
            risks.add(OcrRisk.typeOutlier);
          }
        }
        row.add(
          OcrCell(
            recognizedText: cell.recognizedText,
            confidence: cell.confidence,
            box: cell.box,
            tokenCount: cell.tokenCount,
            risks: Set.unmodifiable(risks),
          ),
        );
      }
      updated.add(row);
    }
    return OcrGrid(updated, hasHeader: grid.hasHeader);
  }

  static List<List<OcrToken>> _groupIntoRows(List<OcrToken> tokens) {
    final heights = tokens
        .map((t) => t.box.height)
        .where((h) => h > 0)
        .toList()
      ..sort();
    final medianHeight =
        heights.isEmpty ? 16.0 : heights[heights.length ~/ 2];
    final rowTolerance = math.max(6.0, medianHeight * 0.55);

    final sorted = [...tokens]
      ..sort((a, b) => a.box.centerY.compareTo(b.box.centerY));

    final rows = <List<OcrToken>>[];
    final rowCenters = <double>[];

    for (final token in sorted) {
      final cy = token.box.centerY;
      var bestRow = -1;
      var bestDist = double.infinity;
      for (var i = 0; i < rows.length; i++) {
        final dist = (cy - rowCenters[i]).abs();
        if (dist <= rowTolerance && dist < bestDist) {
          bestDist = dist;
          bestRow = i;
        }
      }
      if (bestRow >= 0) {
        rows[bestRow].add(token);
        final sumY = rows[bestRow].fold<double>(
          0,
          (acc, t) => acc + t.box.centerY,
        );
        rowCenters[bestRow] = sumY / rows[bestRow].length;
      } else {
        rows.add([token]);
        rowCenters.add(cy);
      }
    }

    final indexed = [
      for (var i = 0; i < rows.length; i++) (rowCenters[i], rows[i]),
    ]..sort((a, b) => a.$1.compareTo(b.$1));

    return [
      for (final entry in indexed)
        entry.$2..sort((a, b) => a.box.left.compareTo(b.box.left)),
    ];
  }

  /// Merges adjacent word tokens on the same line into cell segments when their
  /// horizontal gap is within a single space width.
  static List<_RowSegment> _mergeRowSegments(List<OcrToken> rowTokens) {
    if (rowTokens.isEmpty) return const [];
    final heights = rowTokens.map((t) => t.box.height).toList()..sort();
    final medianHeight =
        heights.isEmpty ? 16.0 : heights[heights.length ~/ 2];
    final mergeGap = math.max(8.0, medianHeight * 0.85);

    final segments = <_RowSegment>[];
    var current = <OcrToken>[rowTokens.first];
    var currentBox = rowTokens.first.box;

    for (var i = 1; i < rowTokens.length; i++) {
      final next = rowTokens[i];
      final nextBox = next.box;
      final gap = nextBox.left - currentBox.right;
      final sameLine =
          next.lineIndex != null &&
          current.last.lineIndex != null &&
          next.lineIndex == current.last.lineIndex;
      final threshold = sameLine ? mergeGap * 1.15 : mergeGap * 0.75;
      if (gap <= threshold) {
        current.add(next);
        currentBox = currentBox.union(nextBox);
      } else {
        segments.add(_RowSegment(current, currentBox));
        current = <OcrToken>[next];
        currentBox = nextBox;
      }
    }
    segments.add(_RowSegment(current, currentBox));
    return segments;
  }

  static List<_ColumnBand> _inferColumns(
    List<List<_RowSegment>> rows, {
    int? targetColumns,
  }) {
    final allSegments = rows.expand((r) => r).toList();
    if (allSegments.isEmpty) {
      return [_ColumnBand(0, 100)];
    }

    if (targetColumns != null && targetColumns >= 1) {
      return _buildFixedColumns(rows, targetColumns);
    }

    // Prefer a bottom-MOST data/leaf-header row with the highest segment count
    // where segments are narrow leaf cells (not spanning multi-column banners).
    var maxSegCount = 0;
    for (final r in rows) {
      if (r.length > maxSegCount) maxSegCount = r.length;
    }
    final candidateAnchors = rows
        .where((r) => r.length >= math.max(1, maxSegCount - 1))
        .toList();
    candidateAnchors.sort((a, b) {
      final lenCmp = b.length.compareTo(a.length);
      if (lenCmp != 0) return lenCmp;
      // Tie-break: prefer row with smaller maximum segment width (leaf columns)
      final maxWa = a.fold<double>(0, (m, s) => math.max(m, s.box.width));
      final maxWb = b.fold<double>(0, (m, s) => math.max(m, s.box.width));
      return maxWa.compareTo(maxWb);
    });
    final seedRow = candidateAnchors.first;
    final bands = <_ColumnBand>[
      for (final seg in seedRow) _ColumnBand(seg.box.left, seg.box.right),
    ];
    final medianBandW = _medianWidth(bands);

    for (final row in rows) {
      for (final seg in row) {
        // Ignore wide multi-column banner segments when expanding column bands
        if (bands.length >= 3 && seg.box.width > medianBandW * 2.1) {
          continue;
        }
        var best = -1;
        var bestOverlap = 0.0;
        for (var i = 0; i < bands.length; i++) {
          final overlap = _horizontalOverlap(seg.box, bands[i]);
          if (overlap > bestOverlap) {
            bestOverlap = overlap;
            best = i;
          }
        }
        if (best >= 0 &&
            bestOverlap >=
                math.min(seg.box.width, bands[best].width) * 0.25) {
          bands[best] = bands[best].expand(seg.box.left, seg.box.right);
        } else {
          var nearest = -1;
          var nearestDist = double.infinity;
          final cx = (seg.box.left + seg.box.right) / 2;
          for (var i = 0; i < bands.length; i++) {
            final dist = (cx - bands[i].center).abs();
            if (dist < nearestDist) {
              nearestDist = dist;
              nearest = i;
            }
          }
          if (nearest >= 0 &&
              nearestDist <= math.max(20.0, bands[nearest].width * 0.55)) {
            bands[nearest] = bands[nearest].expand(seg.box.left, seg.box.right);
          } else {
            bands.add(_ColumnBand(seg.box.left, seg.box.right));
          }
        }
      }
    }

    bands.sort((a, b) => a.center.compareTo(b.center));
    final merged = <_ColumnBand>[bands.first];
    for (var i = 1; i < bands.length; i++) {
      final prev = merged.last;
      final next = bands[i];
      final overlap =
          math.min(prev.right, next.right) - math.max(prev.left, next.left);
      final minW = math.max(1.0, math.min(prev.width, next.width));
      if (overlap / minW > 0.45) {
        merged[merged.length - 1] = prev.expand(next.left, next.right);
      } else {
        merged.add(next);
      }
    }
    return merged;
  }

  static double _medianWidth(List<_ColumnBand> bands) {
    if (bands.isEmpty) return 40.0;
    final widths = bands.map((b) => b.width).toList()..sort();
    return widths[widths.length ~/ 2];
  }

  /// Strips standalone title banners, multi-column super-header rows above the
  /// leaf column header row, and trailing footnotes (e.g. `Coefficients^a`,
  /// `Unstandardized Coefficients`, `a. Dependent Variable: HL` in academic /
  /// SPSS tables) when the table body clearly has >= 3 columns.
  static List<List<_RowSegment>> _pruneBannerAndSuperHeaderRows(
    List<List<_RowSegment>> rows,
  ) {
    if (rows.length < 3) return rows;
    final counts = [for (final r in rows) r.length];
    final maxCols = counts.reduce(math.max);
    final modalCols = _modePositive(counts, fallback: maxCols);
    final bodyCols = math.max(modalCols, maxCols - 1);
    if (bodyCols < 3) return rows;

    // 1. Identify where the actual leaf-header or data rows begin
    var start = 0;
    while (start < rows.length - 2) {
      final row = rows[start];
      final nextRow = rows[start + 1];
      final isSparseHeaderOrTitle = row.length <= math.max(2, bodyCols ~/ 2);
      final nextIsMuchWider = nextRow.length >= bodyCols - 1 ||
          (start + 2 < rows.length && rows[start + 2].length >= bodyCols - 1);
      final isAllText = row.every((s) => !_looksNumeric(s.joinedText));
      if (isSparseHeaderOrTitle && isAllText && nextIsMuchWider) {
        start++;
      } else {
        break;
      }
    }

    // 2. Strip trailing 1-segment footnote lines at the bottom (e.g. "a. Dependent Variable: HL")
    var end = rows.length;
    while (end - start > 2) {
      final last = rows[end - 1];
      final isSingleFootnote =
          last.length == 1 && !_looksNumeric(last.first.joinedText);
      if (isSingleFootnote) {
        end--;
      } else {
        break;
      }
    }

    return rows.sublist(start, end);
  }

  static List<_ColumnBand> _buildFixedColumns(
    List<List<_RowSegment>> rows,
    int count,
  ) {
    final all = rows.expand((r) => r).toList();
    var minX = double.infinity;
    var maxX = -double.infinity;
    for (final s in all) {
      minX = math.min(minX, s.box.left);
      maxX = math.max(maxX, s.box.right);
    }
    if (count == 1 || maxX <= minX) {
      return [_ColumnBand(minX.isFinite ? minX : 0, maxX.isFinite ? maxX : 100)];
    }

    // Seed from the leaf/data row that already has `count` narrow segments
    final exactCandidates = rows.where((r) => r.length == count).toList();
    if (exactCandidates.isNotEmpty) {
      exactCandidates.sort((a, b) {
        final maxWa = a.fold<double>(0, (m, s) => math.max(m, s.box.width));
        final maxWb = b.fold<double>(0, (m, s) => math.max(m, s.box.width));
        return maxWa.compareTo(maxWb);
      });
      final exactRow = exactCandidates.first;
      return [
        for (final s in exactRow) _ColumnBand(s.box.left, s.box.right),
      ];
    }

    final step = (maxX - minX) / count;
    return [
      for (var i = 0; i < count; i++)
        _ColumnBand(minX + i * step, minX + (i + 1) * step),
    ];
  }

  static int _assignColumn(_RowSegment seg, List<_ColumnBand> columns) {
    final cx = (seg.box.left + seg.box.right) / 2;
    var best = 0;
    var bestScore = double.infinity;
    for (var i = 0; i < columns.length; i++) {
      final col = columns[i];
      final dist = (cx - col.center).abs();
      if (dist < bestScore) {
        bestScore = dist;
        best = i;
      }
    }
    return best;
  }

  static bool _crossesColumnBoundary(
    _RowSegment seg,
    List<_ColumnBand> columns,
    int assignedIndex,
  ) {
    if (columns.length <= 1) return false;
    for (var i = 0; i < columns.length; i++) {
      if (i == assignedIndex) continue;
      final overlap = _horizontalOverlap(seg.box, columns[i]);
      if (overlap > 6.0 && overlap / math.max(1.0, seg.box.width) > 0.22) {
        return true;
      }
    }
    return false;
  }

  static double _horizontalOverlap(OcrBox box, _ColumnBand band) =>
      math.max(0.0, math.min(box.right, band.right) - math.max(box.left, band.left));

  static bool _inferHasHeader(
    List<List<_CellDraft>> rows,
    List<double> colNumericRatio,
  ) {
    if (rows.length < 2) return false;
    final first = rows.first;
    var firstHasLabel = false;
    var bodyHasNumber = false;
    for (var c = 0; c < first.length; c++) {
      final head = first[c].text;
      if (head != null && head.isNotEmpty && !_looksNumeric(head)) {
        firstHasLabel = true;
      }
      if (colNumericRatio[c] >= 0.5) {
        bodyHasNumber = true;
      }
    }
    return firstHasLabel && (bodyHasNumber || rows.length >= 2);
  }

  static final _numericPattern = RegExp(
    r'^[+-]?\s*(?:[$€£¥₫]|VND|USD)?\s*(?:\d[\d.,\s]*|[.,]\d+)%?$',
    caseSensitive: false,
  );

  static bool _looksNumeric(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return false;
    return _numericPattern.hasMatch(trimmed) &&
        !VietnameseText.hasLetter(
          trimmed.replaceAll(RegExp(r'(VND|USD)', caseSensitive: false), ''),
        );
  }

  static int _modePositive(List<int> counts, {required int fallback}) {
    final freq = <int, int>{};
    for (final c in counts) {
      if (c > 0) freq[c] = (freq[c] ?? 0) + 1;
    }
    if (freq.isEmpty) return fallback;
    var bestValue = fallback;
    var bestCount = -1;
    for (final e in freq.entries) {
      if (e.value > bestCount || (e.value == bestCount && e.key > bestValue)) {
        bestCount = e.value;
        bestValue = e.key;
      }
    }
    return bestValue;
  }
}

final class _RowSegment {
  const _RowSegment(this.tokens, this.box);
  final List<OcrToken> tokens;
  final OcrBox box;
  String get joinedText =>
      tokens.map((t) => t.text.trim()).where((s) => s.isNotEmpty).join(' ');
}

final class _ColumnBand {
  const _ColumnBand(this.left, this.right);
  final double left, right;
  double get width => math.max(1.0, right - left);
  double get center => (left + right) / 2;
  _ColumnBand expand(double l, double r) =>
      _ColumnBand(math.min(left, l), math.max(right, r));
}

final class _CellDraft {
  final List<OcrToken> tokens = [];
  OcrBox? box;
  int segmentCount = 0;
  bool crossesBoundary = false;

  void add(_RowSegment segment, {required bool crossesBoundary}) {
    tokens.addAll(segment.tokens);
    box = box == null ? segment.box : box!.union(segment.box);
    segmentCount++;
    if (crossesBoundary) this.crossesBoundary = true;
  }

  String? get text {
    if (tokens.isEmpty) return null;
    final joined = tokens.map((t) => t.text.trim()).where((s) => s.isNotEmpty).join(' ');
    return joined.isEmpty ? null : joined;
  }

  double? get confidence {
    final values = tokens.map((t) => t.confidence).whereType<double>().toList();
    if (values.isEmpty) return null;
    return values.reduce(math.min);
  }
}
