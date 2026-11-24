import 'package:excelcompare_core/excelcompare_core.dart';
import 'package:flutter/material.dart';

import '../../design_system/design_system.dart';
import '../shared/text_difference_evidence.dart';
import '../../l10n/app_localizations.dart';

class CompareDemoPage extends StatefulWidget {
  const CompareDemoPage({super.key});
  @override
  State<CompareDemoPage> createState() => _CompareDemoPageState();
}

class _CompareDemoPageState extends State<CompareDemoPage> {
  final left = TextEditingController(text: '8.5');
  final right = TextEditingController(text: '8,5');
  SemanticType type = SemanticType.decimal;
  ComparisonDecision? decision;
  String? error;

  void compare() {
    try {
      final fieldPolicy = FieldPolicy(
        field: 'demo_field',
        type: type,
        trim: true,
        sourceA: const DecimalInputPolicy(decimalSeparator: '.'),
        sourceB: const DecimalInputPolicy(decimalSeparator: ','),
        percentSignIsScale: true,
        aliases: const {
          'true': true,
          'false': false,
          'Có': true,
          'Không': false,
        },
      );
      final next = const SemanticPolicyEngine().compare(
        SourceCell(CellKind.text, rawLexeme: left.text),
        SourceCell(CellKind.text, rawLexeme: right.text),
        fieldPolicy,
      );
      setState(() {
        decision = next;
        error = null;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        decision = null;
      });
    }
  }

  void clearResult() {
    if (decision != null || error != null) {
      setState(() {
        decision = null;
        error = null;
      });
    }
  }

  @override
  void dispose() {
    left.dispose();
    right.dispose();
    super.dispose();
  }

  Widget sourceField(
    String label,
    TextEditingController controller,
    String icon,
  ) => TextField(
    controller: controller,
    onChanged: (_) => clearResult(),
    style: DytavaTypography.dataMedium,
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: Padding(
        padding: const EdgeInsets.all(12),
        child: DytavaAsset(icon),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final a = decision?.left;
    final b = decision?.right;
    final status = decision?.status.name.toUpperCase();
    final statusArt = switch (status) {
      'EXACT' => DytavaIllustrations.statusExact,
      'EQUIVALENT' => DytavaIllustrations.statusEquivalent,
      'DIFFERENT' => DytavaIllustrations.statusDifferent,
      _ => DytavaIllustrations.statusUnresolved,
    };
    final badge = switch (status) {
      'EXACT' => DytavaStatusBadge.exact(),
      'EQUIVALENT' => DytavaStatusBadge.equivalent(),
      'DIFFERENT' => DytavaStatusBadge.different(),
      _ => DytavaStatusBadge.unresolved(),
    };
    return Scaffold(
      appBar: AppBar(
        title: Semantics(
          label: 'Dytava',
          image: true,
          child: SizedBox(
            width: 140,
            height: 40,
            child: const DytavaAsset(DytavaIcons.horizontal, size: 140),
          ),
        ),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const DytavaAsset(
                  DytavaIllustrations.onboardingCompare,
                  size: 180,
                ),
                Text(
                  context.l10n.understandEveryDifference,
                  style: DytavaTypography.displayMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  context.l10n.understandDifferenceDesc,
                  style: DytavaTypography.bodyMedium,
                ),
                const SizedBox(height: 20),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const DytavaAsset(DytavaIcons.compare, size: 32),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                context.l10n.semanticComparisonTitle,
                                style: DytavaTypography.titleLarge,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        sourceField(
                          context.l10n.sourceAValue,
                          left,
                          DytavaIcons.importData,
                        ),
                        const SizedBox(height: 16),
                        sourceField(
                          context.l10n.sourceBValue,
                          right,
                          DytavaIcons.compare,
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<SemanticType>(
                          initialValue: type,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: context.l10n.semanticDataType,
                          ),
                          items: SemanticType.values
                              .map(
                                (item) => DropdownMenuItem(
                                  value: item,
                                  child: Text(switch (item) {
                                    SemanticType.identifier => context.l10n.typeIdentifier,
                                    SemanticType.freeText => context.l10n.typeFreeText,
                                    SemanticType.decimal => context.l10n.typeDecimal,
                                    SemanticType.boolean => context.l10n.typeBoolean,
                                    SemanticType.percentage => context.l10n.typePercentage,
                                  }),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                type = value;
                                decision = null;
                                error = null;
                              });
                            }
                          },
                        ),
                        if (type == SemanticType.freeText ||
                            type == SemanticType.identifier) ...[
                          const SizedBox(height: 12),
                          Text(
                            context.l10n.stringRuleExplanation,
                          ),
                        ],
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: compare,
                          icon: const DytavaAsset(DytavaIcons.compare),
                          label: Text(context.l10n.compareAction),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                if (decision != null)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(child: DytavaAsset(statusArt, size: 144)),
                          Center(child: badge),
                          const SizedBox(height: 16),
                          Text(
                            '${context.l10n.statusPrefix} $status',
                            style: DytavaTypography.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Rule: ${decision!.ruleId}',
                            style: DytavaTypography.dataMedium,
                          ),
                          Text(
                            'A canonical: ${decision!.left?.label ?? '—'}',
                            style: DytavaTypography.dataMedium,
                          ),
                          Text(
                            'B canonical: ${decision!.right?.label ?? '—'}',
                            style: DytavaTypography.dataMedium,
                          ),
                          if (decision?.status == DecisionStatus.different &&
                              a is TextValue &&
                              b is TextValue)
                            TextDifferenceEvidence(a: a.value, b: b.value),
                          if (decision!.reason != null)
                            Text('Reason: ${decision!.reason!.name}'),
                        ],
                      ),
                    ),
                  )
                else if (error != null)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          const DytavaAsset(
                            DytavaIllustrations.statusError,
                            size: 144,
                          ),
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              '${context.l10n.invalidConfig} $error',
                              style: const TextStyle(color: DytavaColors.red),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  const DytavaEmptyState(),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const DytavaAsset(
                      DytavaIcons.privacy,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        context.l10n.onThisDeviceValue,
                        style: DytavaTypography.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
