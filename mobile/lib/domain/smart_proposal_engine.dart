import 'package:excelcompare_core/excelcompare_core.dart';
import 'workflow.dart';

/// Bộ phân tích cấu trúc bảng thông minh (Smart Proposal Engine)
/// Tự động phát hiện cột khóa (ID), ánh xạ cột tương đồng, suy luận kiểu dữ liệu
/// và tối ưu hóa phương pháp ghép bảng cho người dùng di động với số thao tác tối thiểu.
abstract final class SmartProposalEngine {
  static const _keyKeywords = {
    'id',
    'mã',
    'ma',
    'code',
    'stt',
    'key',
    'sku',
    'uuid',
    'identifier',
    'so_hieu',
    'ma_sp',
    'ma_nv',
    'makh',
    'masp',
    'manv',
    'order_id',
    'item_id',
  };

  /// Phân tích 2 bảng dữ liệu và trả về bản đề xuất cấu hình hoàn chỉnh.
  static SmartProposal analyze(
    InputSnapshot a,
    InputSnapshot b, {
    ComparisonTaskMode taskMode = ComparisonTaskMode.compareFiles,
    String? preferredKey,
    String? columnA,
    String? columnB,
    String? reconcileValueColumn,
  }) {
    final fieldsA = a.fields;
    final fieldsB = b.fields;

    // 1. Tìm các cặp cột khớp giữa A và B
    final candidateMappings = <FieldMapping>[];
    for (final fa in fieldsA) {
      final normA = _normalize(fa.id);
      final normLabelA = _normalize(fa.label);

      TableField? match;
      for (final fb in fieldsB) {
        if (fb.id == fa.id ||
            _normalize(fb.id) == normA ||
            _normalize(fb.label) == normLabelA ||
            _normalize(fb.id) == normLabelA ||
            _normalize(fb.label) == normA) {
          match = fb;
          break;
        }
      }
      if (match != null) {
        candidateMappings.add(FieldMapping(fa.id, match.id));
      }
    }

    // 2. Tìm cột khóa tiềm năng (Candidate Key)
    String? detectedKey = preferredKey;
    var keyUniquenessA = true;
    var keyUniquenessB = true;

    if (detectedKey == null) {
      // Ưu tiên các cột có tên trong _keyKeywords
      for (final m in candidateMappings) {
        final norm = _normalize(m.fieldA);
        if (_keyKeywords.any((k) => norm == k || norm.startsWith('${k}_') || norm.endsWith('_$k'))) {
          detectedKey = m.fieldA;
          break;
        }
      }
      // Nếu chưa có, kiểm tra cột đầu tiên nếu có vẻ là định danh
      if (detectedKey == null && candidateMappings.isNotEmpty) {
        final firstMapped = candidateMappings.first.fieldA;
        if (fieldsA.isNotEmpty && fieldsA.first.id == firstMapped) {
          detectedKey = firstMapped;
        }
      }
    }

    // Kiểm tra tính duy nhất của candidate key trong A và B
    if (detectedKey != null) {
      final keyName = detectedKey;
      final valuesA = <String>{};
      for (final r in a.records) {
        final val = r.cells[keyName]?.rawLexeme?.trim() ?? '';
        if (val.isEmpty || valuesA.contains(val)) {
          keyUniquenessA = false;
          break;
        }
        valuesA.add(val);
      }

      final mappedB = candidateMappings.firstWhere(
        (m) => m.fieldA == keyName,
        orElse: () => FieldMapping(keyName, keyName),
      ).fieldB;

      final valuesB = <String>{};
      for (final r in b.records) {
        final val = r.cells[mappedB]?.rawLexeme?.trim() ?? '';
        if (val.isEmpty || valuesB.contains(val)) {
          keyUniquenessB = false;
          break;
        }
        valuesB.add(val);
      }
    }

    final hasSolidUniqueKey = detectedKey != null && keyUniquenessA && keyUniquenessB;

    // 3. Suy luận quy tắc SemanticType cho các cột
    final inferredRules = <String, FieldRule>{};
    for (final m in candidateMappings) {
      if (m.fieldA == detectedKey) {
        inferredRules[m.fieldA] = const FieldRule(
          type: SemanticType.identifier,
          trim: false,
          tolerance: '0',
        );
      } else {
        inferredRules[m.fieldA] = _inferRuleForColumn(m.fieldA, a);
      }
    }

    // 4. Xây dựng đề xuất theo từng chế độ tác vụ
    switch (taskMode) {
      case ComparisonTaskMode.compareFiles:
        final allFieldsMatched = candidateMappings.length == fieldsA.length &&
            candidateMappings.length == fieldsB.length;

        final chosenMode = hasSolidUniqueKey ? MatchingMode.key : MatchingMode.positional;
        final chosenKeys = hasSolidUniqueKey ? [detectedKey] : const <String>[];

        double score = 1.0;
        String reason = 'Đề xuất tối ưu: cấu trúc hai bảng tương đồng, tự động nhận diện ánh xạ.';
        bool needsConfirm = false;

        if (!allFieldsMatched) {
          score = 0.75;
          final unmappedA = fieldsA.length - candidateMappings.length;
          final unmappedB = fieldsB.length - candidateMappings.length;
          reason = 'Có $unmappedA cột ở Bảng A và $unmappedB cột ở Bảng B không có cột đối ứng.';
          needsConfirm = true;
        } else if (detectedKey != null && (!keyUniquenessA || !keyUniquenessB)) {
          score = 0.8;
          reason = 'Cột "$detectedKey" có giá trị trùng lặp hoặc trống, Dytava đề xuất ghép theo thứ tự hàng (Positional).';
          needsConfirm = false;
        }

        return SmartProposal(
          taskMode: taskMode,
          mode: chosenMode,
          keys: chosenKeys,
          mappings: candidateMappings,
          rules: inferredRules,
          confidenceScore: score,
          confidenceReason: reason,
          requiresExplicitConfirmation: needsConfirm,
          suggestedKey: detectedKey,
        );

      case ComparisonTaskMode.compareColumns:
        // Chọn 1 cột từ A và 1 cột từ B để so sánh giá trị
        String colA = columnA ?? '';
        String colB = columnB ?? '';

        if (colA.isEmpty || colB.isEmpty) {
          // Ưu tiên cột không phải key, hoặc cột có tên tương đồng
          FieldMapping? targetMapping;
          for (final m in candidateMappings) {
            if (m.fieldA != detectedKey) {
              targetMapping = m;
              break;
            }
          }
          targetMapping ??= candidateMappings.isNotEmpty ? candidateMappings.first : null;

          colA = targetMapping?.fieldA ?? (fieldsA.isNotEmpty ? fieldsA.first.id : '');
          colB = targetMapping?.fieldB ?? (fieldsB.isNotEmpty ? fieldsB.first.id : '');
        }

        final singleMapping = colA.isNotEmpty && colB.isNotEmpty
            ? [FieldMapping(colA, colB)]
            : const <FieldMapping>[];

        final singleRule = {
          if (colA.isNotEmpty)
            colA: inferredRules[colA] ?? const FieldRule(type: SemanticType.freeText, trim: true),
        };

        return SmartProposal(
          taskMode: taskMode,
          mode: MatchingMode.positional,
          keys: const [],
          mappings: singleMapping,
          rules: singleRule,
          confidenceScore: singleMapping.isNotEmpty ? 1.0 : 0.5,
          confidenceReason: singleMapping.isNotEmpty
              ? 'So sánh giá trị trực tiếp giữa Cột "$colA" (Bảng A) và Cột "$colB" (Bảng B).'
              : 'Chưa xác định được cặp cột để so sánh.',
          requiresExplicitConfirmation: singleMapping.isEmpty,
          columnA: colA,
          columnB: colB,
        );

      case ComparisonTaskMode.reconcile:
        // Khớp bản ghi theo ID và so sánh 1 cột giá trị (No VLOOKUP)
        final keyCol = detectedKey ?? (fieldsA.isNotEmpty ? fieldsA.first.id : '');
        final mappedKeyB = candidateMappings.firstWhere(
          (m) => m.fieldA == keyCol,
          orElse: () => FieldMapping(keyCol, fieldsB.isNotEmpty ? fieldsB.first.id : ''),
        ).fieldB;

        // Tìm cột giá trị cần đối soát (reconcile value)
        String valColA = reconcileValueColumn ?? '';
        String valColB = '';

        if (valColA.isEmpty) {
          for (final m in candidateMappings) {
            if (m.fieldA != keyCol) {
              valColA = m.fieldA;
              valColB = m.fieldB;
              break;
            }
          }
          if (valColA.isEmpty && fieldsA.length > 1) {
            valColA = fieldsA[1].id;
            valColB = fieldsB.length > 1 ? fieldsB[1].id : valColA;
          }
        } else {
          valColB = candidateMappings.firstWhere(
            (m) => m.fieldA == valColA,
            orElse: () => FieldMapping(valColA, valColA),
          ).fieldB;
        }

        final mappings = <FieldMapping>[
          if (keyCol.isNotEmpty && mappedKeyB.isNotEmpty) FieldMapping(keyCol, mappedKeyB),
          if (valColA.isNotEmpty && valColB.isNotEmpty && valColA != keyCol)
            FieldMapping(valColA, valColB),
        ];

        final rules = <String, FieldRule>{
          if (keyCol.isNotEmpty)
            keyCol: const FieldRule(type: SemanticType.identifier, trim: false, tolerance: '0'),
          if (valColA.isNotEmpty && valColA != keyCol)
            valColA: inferredRules[valColA] ?? const FieldRule(type: SemanticType.decimal, trim: true),
        };

        final isKeyUnique = keyUniquenessA && keyUniquenessB;
        final score = isKeyUnique ? 1.0 : 0.6;
        final reason = isKeyUnique
            ? 'Đối soát theo mã định danh "$keyCol", so khớp giá trị cột "$valColA".'
            : 'Cột mã định danh "$keyCol" có bản ghi trùng lặp, cần xác nhận trước khi đối soát.';

        return SmartProposal(
          taskMode: taskMode,
          mode: MatchingMode.key,
          keys: [keyCol],
          mappings: mappings,
          rules: rules,
          confidenceScore: score,
          confidenceReason: reason,
          requiresExplicitConfirmation: !isKeyUnique,
          suggestedKey: keyCol,
          reconcileKeyColumn: keyCol,
          reconcileValueColumn: valColA,
        );
    }
  }

  /// Biên dịch đề xuất thành [ComparisonConfiguration] chuẩn sàng lọc của Dytava.
  static ComparisonConfiguration toConfiguration(
    SmartProposal proposal, {
    ComparisonDirection direction = ComparisonDirection.aToB,
  }) {
    return ComparisonConfiguration(
      mappings: proposal.mappings,
      rules: proposal.rules,
      mode: proposal.mode,
      keys: proposal.keys,
      direction: direction,
      mappingConfirmed: proposal.mappings.isNotEmpty,
      modeConfirmed: true,
      policyConfirmed: true,
      directionConfirmed: true,
    );
  }

  static FieldRule _inferRuleForColumn(String fieldId, InputSnapshot snapshot) {
    var numericCount = 0;
    var percentCount = 0;
    var totalNonEmpty = 0;

    for (final r in snapshot.records) {
      final cell = r.cells[fieldId];
      if (cell == null) continue;
      final raw = cell.rawLexeme?.trim() ?? '';
      if (raw.isEmpty) continue;
      totalNonEmpty++;

      if (raw.endsWith('%')) {
        percentCount++;
      } else {
        final clean = raw.replaceAll(',', '.');
        if (double.tryParse(clean) != null) {
          numericCount++;
        }
      }
    }

    if (totalNonEmpty > 0 && percentCount / totalNonEmpty >= 0.6) {
      return const FieldRule(type: SemanticType.percentage, trim: true, tolerance: '0');
    }
    if (totalNonEmpty > 0 && (numericCount + percentCount) / totalNonEmpty >= 0.6) {
      return const FieldRule(type: SemanticType.decimal, trim: true, tolerance: '0');
    }
    return const FieldRule(type: SemanticType.freeText, trim: true);
  }

  static String _normalize(String input) {
    return input
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[\s\-_]+'), '_')
        .replaceAll(RegExp(r'[^a-z0-9_áàảãạăắằẳẵặâấầẩẫậéèẻẽẹêếềểễệíìỉĩịóòỏõọôốồổỗộơớờởỡợúùủũụưứừửữựýỳỷỹỵđ]'), '');
  }
}
