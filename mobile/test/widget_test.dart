import 'package:flutter_test/flutter_test.dart';
import 'package:dytava/main.dart';

void main() {
  testWidgets(
    'Dytava displays Semantic Comparison UI',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const ExcelCompareApp(),
      );
      expect(
        find.text('ExcelCompare — Semantic PoC'),
        findsOneWidget,
      );
      expect(
        find.text('So sánh'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    '8.5 and 8,5 are equivalent',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const ExcelCompareApp(),
      );
      await tester.tap(find.text('So sánh'));
      await tester.pump();
      expect(
        find.textContaining(
          'Trạng thái: EQUIVALENT',
        ),
        findsOneWidget,
      );
    },
  );
}
