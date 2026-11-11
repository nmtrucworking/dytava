import 'package:excelcompare_core/excelcompare_core.dart';
import 'package:flutter/material.dart';

import 'design_system/design_system.dart';

void main() => runApp(const ExcelCompareApp());

class ExcelCompareApp extends StatelessWidget {
  const ExcelCompareApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Dytava — So sánh dữ liệu',
    theme: DytavaTheme.lightTheme,
    home: const CompareDemoPage(),
  );
}

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
                const Text(
                  'Hiểu rõ từng sai khác.',
                  style: DytavaTypography.displayMedium,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Thử so sánh hai giá trị theo quy tắc ngữ nghĩa. '
                  'Bản mobile hiện chưa đọc Excel/CSV hoặc xuất báo cáo.',
                  style: DytavaTypography.bodyMedium,
                ),
                const SizedBox(height: 20),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Row(
                          children: [
                            DytavaAsset(DytavaIcons.compare, size: 32),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'So sánh dữ liệu',
                                style: DytavaTypography.titleLarge,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        sourceField(
                          'Giá trị nguồn A',
                          left,
                          DytavaIcons.importData,
                        ),
                        const SizedBox(height: 16),
                        sourceField(
                          'Giá trị nguồn B',
                          right,
                          DytavaIcons.compare,
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<SemanticType>(
                          initialValue: type,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Kiểu dữ liệu ngữ nghĩa',
                          ),
                          items: SemanticType.values
                              .map(
                                (item) => DropdownMenuItem(
                                  value: item,
                                  child: Text(switch (item) {
                                    SemanticType.identifier => 'Mã định danh',
                                    SemanticType.freeText => 'Văn bản',
                                    SemanticType.decimal => 'Số thập phân',
                                    SemanticType.boolean => 'Đúng / Sai',
                                    SemanticType.percentage => 'Phần trăm',
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
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: compare,
                          icon: const DytavaAsset(DytavaIcons.compare),
                          label: const Text('So sánh'),
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
                            'Trạng thái: $status',
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
                              'Cấu hình không hợp lệ: $error',
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
                const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DytavaAsset(
                      'assets/dytava/icons/svg/color/privacy.svg',
                      size: 24,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Giá trị được xử lý tại thiết bị.',
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
