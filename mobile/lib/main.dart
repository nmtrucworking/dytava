import 'package:excelcompare_core/excelcompare_core.dart';
import 'package:flutter/material.dart';

void main() => runApp(const ExcelCompareApp());

class ExcelCompareApp extends StatelessWidget {
  const ExcelCompareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ExcelCompare • PoC',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
      home: const CompareDemoPage(),
    );
  }
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
        field: 'demo_field', type: type, trim: true,
        sourceA: const DecimalInputPolicy(decimalSeparator: '.'),
        sourceB: const DecimalInputPolicy(decimalSeparator: ','),
        percentSignIsScale: true,
        aliases: const {'true': true, 'false': false, 'Có': true, 'Không': false},
      );
      final next = const SemanticPolicyEngine().compare(
        SourceCell(CellKind.text, rawLexeme: left.text),
        SourceCell(CellKind.text, rawLexeme: right.text),
        fieldPolicy,
      );
      setState(() { decision = next; error = null; });
    } catch (e) {
      setState(() { error = e.toString(); decision = null; });
    }
  }

  @override
  void dispose() {
    left.dispose(); right.dispose(); super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ExcelCompare — Semantic PoC')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Thử nghiệm so sánh 2 giá trị; chưa đọc Excel/CSV hoặc xuất report.'),
          const SizedBox(height: 16),
          TextField(controller: left, decoration: const InputDecoration(
            labelText: 'Giá trị nguồn A', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: right, decoration: const InputDecoration(
            labelText: 'Giá trị nguồn B', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          DropdownButtonFormField<SemanticType>(
            initialValue: type, decoration: const InputDecoration(
              labelText: 'Semantic dtype', border: OutlineInputBorder()),
            items: SemanticType.values.map((item) => DropdownMenuItem(
              value: item, child: Text(item.name))).toList(),
            onChanged: (v) => setState(() { if (v != null) type = v; }),
          ),
          const SizedBox(height: 18),
          FilledButton(onPressed: compare, child: const Text('So sánh')),
          const SizedBox(height: 20),
          if (decision != null) ...[
            Text('Trạng thái: ${decision!.status.name.toUpperCase()}',
              style: Theme.of(context).textTheme.titleLarge),
            Text('Rule: ${decision!.ruleId}'),
            Text('A canonical: ${decision!.left?.label ?? '—'}'),
            Text('B canonical: ${decision!.right?.label ?? '—'}'),
            if (decision!.reason != null) Text('Reason: ${decision!.reason!.name}'),
          ],
          if (error != null) Text('Cấu hình không hợp lệ: $error'),
        ],
      ),
    );
  }
}
