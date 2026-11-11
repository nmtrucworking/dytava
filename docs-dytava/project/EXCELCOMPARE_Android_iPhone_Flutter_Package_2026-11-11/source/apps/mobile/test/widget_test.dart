import 'package:excelcompare_mobile/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Compare demo page shows initial inputs', (tester) async {
    await tester.pumpWidget(const ExcelCompareApp());
    expect(find.text('ExcelCompare — Semantic PoC'), findsOneWidget);
    expect(find.text('So sánh'), findsOneWidget);
  });
}
