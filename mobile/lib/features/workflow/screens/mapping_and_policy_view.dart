import 'package:excelcompare_core/excelcompare_core.dart';
import 'package:flutter/material.dart';

import '../../../application/workflow_controller.dart';
import '../../../design_system/design_system.dart';
import '../../../domain/workflow.dart';
import '../widgets/workflow_common_widgets.dart';

/// Màn hình Ánh xạ cột (`SCR-05`):
/// - Sử dụng `BrandIllustration.onboarding(DytavaIllustrations.onboardingMapping)` ở đầu trang.
/// - Hiển thị `BrandIllustration.emptyMapping()` khi chưa có cột nào được ghép.
/// - Sử dụng `BrandIcon(DytavaIcons.mapping)` và `BrandIcon(DytavaIcons.link)` cho từng cặp cột 1:1.
class MappingScreenView extends StatelessWidget {
  final WorkflowController flow;
  final VoidCallback onAutoMap;
  final VoidCallback onContinuePolicy;

  const MappingScreenView({
    super.key,
    required this.flow,
    required this.onAutoMap,
    required this.onContinuePolicy,
  });

  @override
  Widget build(BuildContext context) {
    final a = flow.slot(SourceSide.a).snapshot!;
    final b = flow.slot(SourceSide.b).snapshot!;
    final config = flow.config;
    final chosen = {for (final m in config.mappings) m.fieldA: m.fieldB};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WorkflowSectionCard(
          padding: const EdgeInsets.all(14),
          color: DytavaColors.softBlue,
          border: Border.all(
            color: DytavaColors.primary.withValues(alpha: 0.3),
          ),
          children: [
            Row(
              children: [
                BrandIllustration.onboarding(
                  DytavaIllustrations.onboardingMapping,
                  maxHeight: 54,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Ghép cột 1:1 bằng Field ID giữa Sheet A và Sheet B. Cột không ghép được ghi nhận như thay đổi cấu trúc.',
                    style: DytavaTypography.bodyMedium.copyWith(
                      color: DytavaColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: OutlinedButton.icon(
            icon: const BrandIcon(DytavaIcons.mapping, size: 18),
            label: const Text(
              'Tự động ghép cột cùng tên',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: DytavaColors.primary,
              ),
            ),
            style: OutlinedButton.styleFrom(
              backgroundColor: DytavaColors.softBlue,
              side: const BorderSide(color: DytavaColors.primary),
              minimumSize: const Size(48, 48),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: onAutoMap,
          ),
        ),
        WorkflowSectionCard(
          children: [
            Row(
              children: [
                const BrandIcon(DytavaIcons.columns, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Ánh xạ các cột (Sheet A ↔ Sheet B)',
                    style: DytavaTypography.titleLarge.copyWith(
                      color: DytavaColors.textPrimary,
                    ),
                  ),
                ),
                WorkflowStatusPill(
                  label: '${config.mappings.length}/${a.fields.length} cột',
                  color: config.mappings.isNotEmpty
                      ? DytavaColors.exact
                      : DytavaColors.textSecondary,
                  bg: config.mappings.isNotEmpty
                      ? DytavaColors.softGreen
                      : DytavaColors.background,
                  iconAsset: config.mappings.isNotEmpty
                      ? DytavaIcons.check
                      : DytavaIcons.empty,
                ),
              ],
            ),
            if (config.mappings.isEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: DytavaColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: DytavaColors.border),
                ),
                child: Row(
                  children: [
                    BrandIllustration.emptyMapping(size: 56),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Chưa có cặp cột nào được ghép. Hãy chọn cột tương ứng ở Sheet B hoặc bấm Tự động ghép cột cùng tên.',
                        style: DytavaTypography.bodySmall.copyWith(
                          color: DytavaColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            for (final f in a.fields)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: DropdownButtonFormField<String>(
                  key: ValueKey('mapping-${f.id}-${chosen[f.id]}'),
                  initialValue: chosen[f.id] ?? '',
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'A: ${f.label} (${f.id}) → B',
                    prefixIcon: const Padding(
                      padding: EdgeInsets.all(12),
                      child: BrandIcon(DytavaIcons.link, size: 18),
                    ),
                  ),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('Không ghép')),
                    for (final target in b.fields)
                      DropdownMenuItem(
                        value: target.id,
                        enabled: !chosen.entries.any(
                          (m) => m.key != f.id && m.value == target.id,
                        ),
                        child: Text('${target.label} (${target.id})'),
                      ),
                  ],
                  onChanged: (value) {
                    final mappings = config.mappings
                        .where((m) => m.fieldA != f.id)
                        .toList();
                    if (value != null && value.isNotEmpty) {
                      mappings.add(FieldMapping(f.id, value));
                    }
                    final rules = Map<String, FieldRule>.of(config.rules);
                    rules.putIfAbsent(
                      f.id,
                      () => FieldRule(
                        type: f.id == 'id'
                            ? SemanticType.identifier
                            : SemanticType.decimal,
                      ),
                    );
                    flow.configure(
                      config.copyWith(
                        mappings: mappings,
                        rules: rules,
                        mappingConfirmed: false,
                        policyConfirmed: false,
                        modeConfirmed: false,
                        keys: [],
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 12),
            WorkflowCheckTile(
              label: 'Xác nhận ánh xạ hiện hành',
              checked: config.mappingConfirmed,
              onChanged: config.mappings.isEmpty
                  ? null
                  : (checked) => flow.configure(
                      config.copyWith(mappingConfirmed: checked),
                    ),
            ),
            const SizedBox(height: 12),
            WorkflowPrimaryButton(
              label: 'Tiếp tục cấu hình so sánh',
              iconAsset: DytavaIcons.policy,
              onPressed: config.mappingConfirmed ? onContinuePolicy : null,
            ),
          ],
        ),
      ],
    );
  }
}

/// Màn hình Cấu hình & Quy tắc chuẩn hóa (`SCR-06`):
/// - Chia cấu hình thành 3 nhóm rõ ràng (Khóa ghép hàng, Quy tắc từng cột, Chiều đối chiếu).
/// - Tích hợp `BrandIllustration.onboarding(DytavaIllustrations.onboardingPolicy)` và `BrandIcon.semanticType(...)`.
/// - Bắt buộc xác nhận tường minh theo nghiệp vụ trước khi chạy.
class PolicyScreenView extends StatelessWidget {
  final WorkflowController flow;
  final VoidCallback onQuickConfirmAndRun;

  const PolicyScreenView({
    super.key,
    required this.flow,
    required this.onQuickConfirmAndRun,
  });

  void _updateRule(String field, FieldRule value) => flow.configure(
    flow.config.copyWith(
      rules: {...flow.config.rules, field: value},
      policyConfirmed: false,
      modeConfirmed: false,
    ),
  );

  String _semanticTypeDescription(SemanticType type) => switch (type) {
    SemanticType.identifier =>
      'Định danh (IDENTIFIER) · Giữ nguyên chữ số 0 ở đầu (ví dụ 00123)',
    SemanticType.decimal =>
      'Số thập phân (DECIMAL) · Chuẩn hóa dấu chấm/phẩy và sai số tuyệt đối',
    SemanticType.freeText =>
      'Văn bản tự do (FREE_TEXT) · Đối chiếu chuỗi ký tự và khoảng trắng',
    SemanticType.boolean =>
      'Giá trị logic (BOOLEAN) · Chuẩn hóa trạng thái đúng/sai',
    SemanticType.percentage =>
      'Phần trăm (PERCENTAGE) · Chuẩn hóa tỷ lệ phần trăm',
  };

  @override
  Widget build(BuildContext context) {
    final config = flow.config;
    final allConfirmed =
        config.mappingConfirmed &&
        config.modeConfirmed &&
        config.policyConfirmed &&
        config.directionConfirmed;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Thẻ tóm tắt cấu hình & xác nhận nhanh
        WorkflowSectionCard(
          color: DytavaColors.softBlue,
          border: Border.all(
            color: DytavaColors.primary.withValues(alpha: 0.35),
          ),
          children: [
            Row(
              children: [
                BrandIllustration.onboarding(
                  DytavaIllustrations.onboardingPolicy,
                  maxHeight: 48,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Tóm tắt cấu hình đối chiếu',
                    style: DytavaTypography.titleMedium.copyWith(
                      color: DytavaColors.primary,
                    ),
                  ),
                ),
                WorkflowStatusPill(
                  label: allConfirmed ? 'Đã phê duyệt' : 'Cần xác nhận',
                  color: allConfirmed
                      ? DytavaColors.exact
                      : DytavaColors.unresolved,
                  bg: allConfirmed
                      ? DytavaColors.softGreen
                      : DytavaColors.softAmber,
                  iconAsset: allConfirmed
                      ? DytavaIcons.check
                      : DytavaIcons.warning,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '• Khóa ghép: ${WorkflowUiHelpers.formatEnumName(config.mode)}${config.mode == MatchingMode.key ? ' (${config.keys.isEmpty ? 'chưa chọn' : config.keys.join(' → ')})' : ''}\n'
              '• Chính sách chuẩn hóa: ${config.mappings.length} cột ánh xạ (${config.policyConfirmed ? 'đã xác nhận' : 'chưa xác nhận'})\n'
              '• Chiều so sánh: ${config.direction == ComparisonDirection.aToB ? 'A → B' : 'B → A'} (${config.directionConfirmed ? 'đã xác nhận' : 'chưa xác nhận'})',
              style: DytavaTypography.bodyMedium,
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: BrandIcon(
                  allConfirmed ? DytavaIcons.play : DytavaIcons.policy,
                  size: 18,
                ),
                label: Text(
                  allConfirmed
                      ? 'Chạy nhanh với cấu hình đã duyệt'
                      : 'Xem tóm tắt & Xác nhận cấu hình',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: DytavaColors.primary,
                  minimumSize: const Size(48, 48),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: onQuickConfirmAndRun,
              ),
            ),
          ],
        ),

        // Nhóm 1: Chế độ ghép hàng & Khóa định danh
        WorkflowSectionCard(
          children: [
            Row(
              children: [
                const BrandIcon(DytavaIcons.key, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Ghép hàng giữa 2 Sheets',
                    style: DytavaTypography.titleLarge.copyWith(
                      color: DytavaColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<MatchingMode>(
              key: ValueKey(config.mode),
              initialValue: config.mode,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Chế độ'),
              items: [
                for (final mode in MatchingMode.values)
                  DropdownMenuItem(
                    value: mode,
                    child: Text(WorkflowUiHelpers.formatEnumName(mode)),
                  ),
              ],
              onChanged: (mode) {
                if (mode != null) {
                  flow.configure(
                    config.copyWith(mode: mode, modeConfirmed: false, keys: []),
                  );
                }
              },
            ),
            if (config.mode == MatchingMode.key) ...[
              const SizedBox(height: 10),
              const WorkflowInfoBanner(
                text:
                    'Chọn khóa theo thứ tự. Khóa phải là IDENTIFIER, không trim hoặc tolerance. Null/trùng được giữ unresolved, không tự ghép.',
                iconAsset: DytavaIcons.key,
              ),
              for (final m in config.mappings)
                WorkflowCheckTile(
                  label: 'Khóa: ${m.fieldA}',
                  checked: config.keys.contains(m.fieldA),
                  onChanged: (checked) {
                    final keys = config.keys
                        .where((k) => k != m.fieldA)
                        .toList();
                    if (checked) keys.add(m.fieldA);
                    flow.configure(
                      config.copyWith(keys: keys, modeConfirmed: false),
                    );
                  },
                ),
              Container(
                margin: const EdgeInsets.symmetric(vertical: 6),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: DytavaColors.softBlue,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Tuple khóa: ${config.keys.join(' → ')}',
                  style: DytavaTypography.dataMedium.copyWith(
                    color: DytavaColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            WorkflowCheckTile(
              label: 'Xác nhận chế độ và khóa',
              checked: config.modeConfirmed,
              onChanged: (checked) =>
                  flow.configure(config.copyWith(modeConfirmed: checked)),
            ),
          ],
        ),

        // Nhóm 2: Policy từng cột với `BrandIcon.semanticType(...)`
        WorkflowSectionCard(
          children: [
            Row(
              children: [
                const BrandIcon(DytavaIcons.normalize, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Policy từng cột',
                    style: DytavaTypography.titleLarge.copyWith(
                      color: DytavaColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Kiểu dữ liệu và quy tắc chuẩn hóa cho từng cặp cột đã ánh xạ.',
              style: DytavaTypography.bodySmall,
            ),
            for (final m in config.mappings) ...[
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: DytavaColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: DytavaColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (config.rules[m.fieldA] case final FieldRule r) ...[
                          BrandIcon.semanticType(r.type, size: 22),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: Text(
                            'Cột ${m.fieldA} ↔ ${m.fieldB} · kiểu ban đầu là gợi ý',
                            style: DytavaTypography.titleMedium,
                          ),
                        ),
                      ],
                    ),
                    if (config.rules[m.fieldA] case final FieldRule r) ...[
                      const SizedBox(height: 4),
                      Text(
                        _semanticTypeDescription(r.type),
                        style: DytavaTypography.bodySmall.copyWith(
                          color: DytavaColors.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    DropdownButtonFormField<SemanticType>(
                      key: ValueKey(
                        'type-${m.fieldA}-${config.rules[m.fieldA]?.type}',
                      ),
                      initialValue: config.rules[m.fieldA]?.type,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Kiểu ${m.fieldA}',
                      ),
                      items: [
                        for (final type in SemanticType.values)
                          DropdownMenuItem(value: type, child: Text(type.name)),
                      ],
                      onChanged: (type) {
                        if (type != null) {
                          _updateRule(m.fieldA, FieldRule(type: type));
                        }
                      },
                    ),
                    if (config.rules[m.fieldA] case final FieldRule rule) ...[
                      WorkflowCheckTile(
                        label: 'Trim ${m.fieldA}',
                        checked: rule.trim,
                        onChanged: (checked) => _updateRule(
                          m.fieldA,
                          FieldRule(
                            type: rule.type,
                            trim: checked,
                            separatorA: rule.separatorA,
                            separatorB: rule.separatorB,
                            tolerance: rule.tolerance,
                          ),
                        ),
                      ),
                      if (rule.type == SemanticType.decimal ||
                          rule.type == SemanticType.percentage) ...[
                        for (final side in SourceSide.values)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: DropdownButtonFormField<String>(
                              key: ValueKey(
                                'separator-${m.fieldA}-${side.name}-${side == SourceSide.a ? rule.separatorA : rule.separatorB}',
                              ),
                              initialValue: side == SourceSide.a
                                  ? rule.separatorA
                                  : rule.separatorB,
                              decoration: InputDecoration(
                                labelText:
                                    'Dấu thập phân ${m.fieldA} / ${side.name.toUpperCase()}',
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: '.',
                                  child: Text('Chấm (.)'),
                                ),
                                DropdownMenuItem(
                                  value: ',',
                                  child: Text('Phẩy (,)'),
                                ),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  _updateRule(
                                    m.fieldA,
                                    FieldRule(
                                      type: rule.type,
                                      trim: rule.trim,
                                      tolerance: rule.tolerance,
                                      separatorA: side == SourceSide.a
                                          ? value
                                          : rule.separatorA,
                                      separatorB: side == SourceSide.b
                                          ? value
                                          : rule.separatorB,
                                    ),
                                  );
                                }
                              },
                            ),
                          ),
                        TextFormField(
                          key: ValueKey('tolerance-${m.fieldA}'),
                          initialValue: rule.tolerance,
                          decoration: InputDecoration(
                            labelText: 'Sai số tuyệt đối ${m.fieldA}',
                          ),
                          onChanged: (value) => _updateRule(
                            m.fieldA,
                            FieldRule(
                              type: rule.type,
                              trim: rule.trim,
                              separatorA: rule.separatorA,
                              separatorB: rule.separatorB,
                              tolerance: value,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            WorkflowCheckTile(
              label: 'Xác nhận toàn bộ policy',
              checked: config.policyConfirmed,
              onChanged: (checked) =>
                  flow.configure(config.copyWith(policyConfirmed: checked)),
            ),
          ],
        ),

        // Nhóm 3: Chiều so sánh
        WorkflowSectionCard(
          children: [
            Row(
              children: [
                const BrandIcon(DytavaIcons.compareFiles, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Chiều so sánh',
                    style: DytavaTypography.titleLarge.copyWith(
                      color: DytavaColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<ComparisonDirection>(
              key: ValueKey(config.direction),
              initialValue: config.direction,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Chiều'),
              items: const [
                DropdownMenuItem(
                  value: ComparisonDirection.aToB,
                  child: Text('A → B'),
                ),
                DropdownMenuItem(
                  value: ComparisonDirection.bToA,
                  child: Text('B → A'),
                ),
              ],
              onChanged: (direction) {
                if (direction != null) {
                  flow.configure(
                    config.copyWith(
                      direction: direction,
                      directionConfirmed: false,
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 6),
            Text(
              config.direction == ComparisonDirection.aToB
                  ? 'Chỉ ở B: thêm. Chỉ ở A: thiếu.'
                  : 'Chỉ ở A: thêm. Chỉ ở B: thiếu.',
              style: DytavaTypography.bodyMedium,
            ),
            const SizedBox(height: 6),
            WorkflowCheckTile(
              label: 'Xác nhận chiều so sánh',
              checked: config.directionConfirmed,
              onChanged: (checked) =>
                  flow.configure(config.copyWith(directionConfirmed: checked)),
            ),
          ],
        ),

        if (flow.startBlockers.isNotEmpty)
          WorkflowSectionCard(
            color: DytavaColors.softRed,
            children: [WorkflowIssueList(issues: flow.startBlockers)],
          ),
        const SizedBox(height: 8),
        WorkflowPrimaryButton(
          label: 'Chạy so sánh mẫu',
          iconAsset: DytavaIcons.play,
          onPressed: flow.startBlockers.isEmpty && !flow.busy
              ? flow.runComparison
              : null,
        ),
      ],
    );
  }
}
