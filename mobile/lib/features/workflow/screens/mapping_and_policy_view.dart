import 'package:excelcompare_core/excelcompare_core.dart';
import 'package:flutter/material.dart';

import '../../../application/workflow_controller.dart';
import '../../../design_system/design_system.dart';
import '../../../domain/workflow.dart';
import '../widgets/sheet_mapping_review.dart';
import '../widgets/workflow_common_widgets.dart';

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
    return WorkflowScreenLayout(
      contentPadding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 4),
          const Text('Match your columns', style: DytavaTypography.titleLarge),
          const SizedBox(height: 2),
          Text(
            '${a.sheetName ?? 'Original'} → ${b.sheetName ?? 'Updated'}',
            style: DytavaTypography.titleSmall.copyWith(
              color: DytavaColors.primary,
            ),
          ),
          const SizedBox(height: 8),
          SheetMappingReview(flow: flow),
          for (final field in a.fields)
            WorkflowSectionCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              margin: const EdgeInsets.only(bottom: 6),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        field.label,
                        style: DytavaTypography.titleSmall,
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward,
                      size: 16,
                      color: DytavaColors.textSecondary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                                key: ValueKey(
                                  'mapping-${field.id}-${chosen[field.id]}',
                                ),
                                isExpanded: true,
                                value: chosen[field.id] ?? '',
                                style: DytavaTypography.titleSmall.copyWith(
                                  color: DytavaColors.primary,
                                ),
                                items: [
                                  const DropdownMenuItem(
                                    value: '',
                                    child: Text('Unpaired'),
                                  ),
                                  for (final target in b.fields)
                                    DropdownMenuItem(
                                      value: target.id,
                                      enabled: !chosen.entries.any(
                                        (m) =>
                                            m.key != field.id && m.value == target.id,
                                      ),
                                      child: Text(
                                        target.label,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                ],
                                onChanged: flow.busy
                                    ? null
                                    : (value) {
                                        final mappings = config.mappings
                                            .where((m) => m.fieldA != field.id)
                                            .toList();
                                        if (value != null && value.isNotEmpty) {
                                          mappings.add(FieldMapping(field.id, value));
                                        }
                                        final rules = Map<String, FieldRule>.of(
                                          config.rules,
                                        );
                                        rules.putIfAbsent(
                                          field.id,
                                          () => FieldRule(
                                            type: field.id == 'id'
                                                ? SemanticType.identifier
                                                : SemanticType.freeText,
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
                          ),
                        ],
                      ),
                      Text(
                        chosen[field.id] == field.id
                            ? 'Exact name'
                            : 'Confirm the corresponding column',
                        style: DytavaTypography.bodySmall,
                      ),
                    ],
                  ),
                TextButton(
                  onPressed: flow.busy ? null : onAutoMap,
                  child: const Text('Auto match columns →'),
                ),
                WorkflowSectionCard(
                  children: [
                    Text(
                      '${config.mappings.length} pairs · ${a.fields.length - config.mappings.length} unpaired in A · ${b.fields.length - config.mappings.length} unpaired in B',
                      style: DytavaTypography.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Unpaired columns are tracked as structural changes.',
                      style: DytavaTypography.bodySmall,
                    ),
                  ],
                ),
                WorkflowCheckTile(
                  label: 'Confirm current column mapping',
                  checked: config.mappingConfirmed,
                  onChanged: config.mappings.isNotEmpty || flow.structuralWorkbookOnly
                      ? (v) => flow.configure(config.copyWith(mappingConfirmed: v))
                      : null,
                ),
                const SizedBox(height: 16),
              ],
            ),
            bottomBar: StickyBottomBar(
              child: WorkflowPrimaryButton(
                label: 'Continue to comparison setup',
                onPressed:
                    config.mappingConfirmed && flow.sheetMapping?.complete != false
                    ? onContinuePolicy
                    : null,
              ),
            ),
          );
  }
}

class PolicyScreenView extends StatelessWidget {
  final WorkflowController flow;
  final VoidCallback onQuickConfirmAndRun;
  const PolicyScreenView({
    super.key,
    required this.flow,
    required this.onQuickConfirmAndRun,
  });

  void _rule(String field, FieldRule value) => flow.configure(
    flow.config.copyWith(
      rules: {...flow.config.rules, field: value},
      policyConfirmed: false,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final config = flow.config;
    final invalidTolerance = config.rules.values.any((r) {
      final v = double.tryParse(r.tolerance);
      return v == null || !v.isFinite || v < 0;
    });
    final a = flow.slot(SourceSide.a).snapshot!;
    final b = flow.slot(SourceSide.b).snapshot!;
    return WorkflowScreenLayout(
      contentPadding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 4),
          const Text(
            'Ready for a clear view.',
            style: DytavaTypography.titleLarge,
          ),
          const SizedBox(height: 2),
          const Text(
            'Review the proposed matches and comparison rules.',
            style: DytavaTypography.bodySmall,
          ),
          const SizedBox(height: 8),
          WorkflowSectionCard(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 6),
            children: [
              Text(
                'A  ${flow.slot(SourceSide.a).artifact!.label}',
                style: DytavaTypography.titleSmall,
              ),
              const SizedBox(height: 4),
              Text(
                'B  ${flow.slot(SourceSide.b).artifact!.label}',
                style: DytavaTypography.titleSmall,
              ),
              const SizedBox(height: 4),
              Text(
                '${a.records.length} → ${b.records.length} rows',
                style: DytavaTypography.bodySmall,
              ),
            ],
          ),
          SheetMappingReview(flow: flow),
        _expand('Columns', '${config.mappings.length} pairs · Edit', [
          for (final m in config.mappings)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '${m.fieldA} → ${m.fieldB}',
                style: DytavaTypography.bodyMedium,
              ),
            ),
          TextButton(
            onPressed: () => flow.navigate(WorkflowScreen.mapping),
            child: const Text('Edit column mapping →'),
          ),
        ]),
        _expand('Comparison task', flow.taskMode.label, [
          DropdownButtonFormField<ComparisonTaskMode>(
            initialValue: flow.taskMode,
            isExpanded: true,
            items: const [
              DropdownMenuItem(
                value: ComparisonTaskMode.compareFiles,
                child: Text('Compare files'),
              ),
              DropdownMenuItem(
                value: ComparisonTaskMode.compareColumns,
                child: Text('Compare columns'),
              ),
              DropdownMenuItem(
                value: ComparisonTaskMode.reconcile,
                child: Text('Reconcile by ID'),
              ),
            ],
            onChanged: (value) {
              if (value == null) return;
              final policy = flow.config.webPolicy;
              flow.setTaskMode(value);
              flow.analyzeAndPropose();
              flow.applyProposal();
              flow.configure(flow.config.copyWith(webPolicy: policy));
            },
          ),
        ]),
        _expand(
          'Row matching',
          switch (config.mode) {
            MatchingMode.key => 'By key column',
            MatchingMode.positional => 'By position',
            MatchingMode.orderedSequence => 'Sequence alignment',
          },
          [
            DropdownButtonFormField<MatchingMode>(
              initialValue: config.mode,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Match rows'),
              items: const [
                DropdownMenuItem(
                  value: MatchingMode.positional,
                  child: Text('By position'),
                ),
                DropdownMenuItem(
                  value: MatchingMode.key,
                  child: Text('By key column'),
                ),
                DropdownMenuItem(
                  value: MatchingMode.orderedSequence,
                  child: Text('Sequence alignment'),
                ),
              ],
              onChanged: (v) {
                if (v != null) {
                  flow.configure(
                    config.copyWith(mode: v, modeConfirmed: false),
                  );
                }
              },
            ),
            if (config.mode == MatchingMode.key) ...[
              const SizedBox(height: 12),
              const Text(
                'Choose one or more key columns.',
                style: DytavaTypography.bodySmall,
              ),
              for (final m in config.mappings)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(m.fieldA, style: DytavaTypography.bodyMedium),
                  value: config.keys.contains(m.fieldA),
                  onChanged: (v) {
                    final keys = [...config.keys];
                    if (v == true) {
                      keys.add(m.fieldA);
                    } else {
                      keys.remove(m.fieldA);
                    }
                    final rules = {...config.rules};
                    if (v == true) {
                      rules[m.fieldA] = const FieldRule(
                        type: SemanticType.identifier,
                      );
                    }
                    flow.configure(
                      config.copyWith(
                        keys: keys,
                        rules: rules,
                        modeConfirmed: false,
                      ),
                    );
                  },
                ),
            ],
            const SizedBox(height: 10),
            const Text(
              'Missing or duplicate keys remain unresolved; no match is guessed.',
              style: DytavaTypography.bodySmall,
            ),
          ],
        ),
        _expand('Rules', 'Custom rules · Edit', [
          for (final m in config.mappings) ...[
            Text(m.fieldA, style: DytavaTypography.titleSmall),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Detect type automatically',
                style: DytavaTypography.bodyMedium,
              ),
              value: config.rules[m.fieldA]?.webAuto ?? false,
              onChanged: (value) {
                final r =
                    config.rules[m.fieldA] ??
                    const FieldRule(type: SemanticType.freeText);
                _rule(
                  m.fieldA,
                  FieldRule(
                    type: r.type,
                    trim: r.trim,
                    tolerance: r.tolerance,
                    separatorA: r.separatorA,
                    separatorB: r.separatorB,
                    webAuto: value,
                  ),
                );
              },
            ),
            DropdownButtonFormField<SemanticType>(
              key: ValueKey('type-${m.fieldA}-${config.rules[m.fieldA]?.type}'),
              initialValue:
                  config.rules[m.fieldA]?.type ?? SemanticType.freeText,
              decoration: const InputDecoration(labelText: 'Data type'),
              items: [
                for (final type in SemanticType.values)
                  DropdownMenuItem(
                    value: type,
                    child: Text(switch (type) {
                      SemanticType.identifier => 'Identifier',
                      SemanticType.freeText => 'Text',
                      SemanticType.decimal => 'Number',
                      SemanticType.boolean => 'Boolean',
                      SemanticType.percentage => 'Percentage',
                    }),
                  ),
              ],
              onChanged: (v) {
                if (v != null) {
                  final r =
                      config.rules[m.fieldA] ??
                      const FieldRule(type: SemanticType.freeText);
                  _rule(
                    m.fieldA,
                    FieldRule(
                      type: v,
                      trim: r.trim,
                      tolerance: r.tolerance,
                      separatorA: r.separatorA,
                      separatorB: r.separatorB,
                      webAuto: false,
                    ),
                  );
                }
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Trim spaces',
                style: DytavaTypography.bodyMedium,
              ),
              value: config.rules[m.fieldA]?.trim ?? false,
              onChanged: (v) {
                final r =
                    config.rules[m.fieldA] ??
                    const FieldRule(type: SemanticType.freeText);
                _rule(
                  m.fieldA,
                  FieldRule(
                    type: r.type,
                    trim: v,
                    tolerance: r.tolerance,
                    separatorA: r.separatorA,
                    separatorB: r.separatorB,
                    webAuto: false,
                  ),
                );
              },
            ),
            if (config.rules[m.fieldA]?.type == SemanticType.decimal ||
                config.rules[m.fieldA]?.type == SemanticType.percentage) ...[
              for (final side in SourceSide.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: DropdownButtonFormField<String>(
                    initialValue: side == SourceSide.a
                        ? config.rules[m.fieldA]?.separatorA ?? '.'
                        : config.rules[m.fieldA]?.separatorB ?? ',',
                    decoration: InputDecoration(
                      labelText:
                          'Decimal separator · ${side.name.toUpperCase()}',
                    ),
                    items: const [
                      DropdownMenuItem(value: '.', child: Text('Dot (1.25)')),
                      DropdownMenuItem(value: ',', child: Text('Comma (1,25)')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      final r = config.rules[m.fieldA]!;
                      _rule(
                        m.fieldA,
                        FieldRule(
                          type: r.type,
                          trim: r.trim,
                          tolerance: r.tolerance,
                          separatorA: side == SourceSide.a
                              ? value
                              : r.separatorA,
                          separatorB: side == SourceSide.b
                              ? value
                              : r.separatorB,
                        ),
                      );
                    },
                  ),
                ),
            ],
            TextFormField(
              initialValue: config.rules[m.fieldA]?.tolerance ?? '0',
              decoration: const InputDecoration(
                labelText: 'Absolute tolerance',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (v) {
                final r =
                    config.rules[m.fieldA] ??
                    const FieldRule(type: SemanticType.freeText);
                _rule(
                  m.fieldA,
                  FieldRule(
                    type: r.type,
                    trim: r.trim,
                    tolerance: v,
                    separatorA: r.separatorA,
                    separatorB: r.separatorB,
                    webAuto: r.webAuto,
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
          ],
        ]),
        _expand(
          'File order',
          config.direction == ComparisonDirection.aToB
              ? 'Original A → Updated B'
              : 'Original B → Updated A',
          [
            DropdownButtonFormField<ComparisonDirection>(
              initialValue: config.direction,
              isExpanded: true,
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
              onChanged: (v) {
                if (v != null) {
                  flow.configure(
                    config.copyWith(direction: v, directionConfirmed: false),
                  );
                }
              },
            ),
          ],
        ),
        if (flow.proposal?.isHighConfidence == false)
          WorkflowSectionCard(
            color: DytavaColors.modifiedBg,
            children: const [
              Text(
                'Review the proposed matches',
                style: DytavaTypography.titleSmall,
              ),
              SizedBox(height: 8),
              Text(
                'Some matches need your confirmation. Unmatched records will stay unresolved.',
                style: DytavaTypography.bodySmall,
              ),
            ],
          ),
                const SizedBox(height: 16),
              ],
            ),
            bottomBar: StickyBottomBar(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Confirm these settings to start your comparison.',
                    style: DytavaTypography.bodySmall,
                  ),
                  if (invalidTolerance) ...[
                    const SizedBox(height: 4),
                    const Text(
                      'Enter a valid non-negative tolerance.',
                      style: DytavaTypography.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 8),
                  WorkflowPrimaryButton(
                    label: 'Start comparison',
                    onPressed:
                        flow.busy ||
                                flow.sheetMapping?.complete == false ||
                                invalidTolerance ||
                                (config.mode == MatchingMode.key &&
                                    config.keys.isEmpty)
                            ? null
                            : onQuickConfirmAndRun,
                  ),
                ],
              ),
            ),
          );
  }

  Widget _expand(String title, String summary, List<Widget> children) =>
      Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: Theme(
            data: DytavaTheme.lightTheme.copyWith(
              dividerColor: Colors.transparent,
            ),
            child: ExpansionTile(
              title: Text(title, style: DytavaTypography.titleSmall),
              subtitle: Text(
                summary,
                style: DytavaTypography.bodySmall.copyWith(
                  color: DytavaColors.primary,
                ),
              ),
              childrenPadding: const EdgeInsets.all(16),
              children: children,
            ),
          ),
        ),
      );
}
