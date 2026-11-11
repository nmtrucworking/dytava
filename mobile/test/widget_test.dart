import 'package:flutter/material.dart';
import 'package:dytava/design_system/design_system.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dytava/main.dart';

void main() {
  testWidgets('Dytava displays Semantic Comparison UI', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ExcelCompareApp());
    expect(find.text('So sánh dữ liệu'), findsOneWidget);
    expect(find.text('So sánh'), findsOneWidget);
  });

  testWidgets('8.5 and 8,5 are equivalent', (WidgetTester tester) async {
    await tester.pumpWidget(const ExcelCompareApp());
    await tester.ensureVisible(find.text('So sánh'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('So sánh'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.textContaining('Trạng thái:'));
    await tester.pump();
    expect(find.textContaining('Trạng thái: EQUIVALENT'), findsOneWidget);
  });

  for (final sample in [
    ('8', '8', 'EXACT', DytavaIllustrations.statusExact),
    ('8.5', '8,5', 'EQUIVALENT', DytavaIllustrations.statusEquivalent),
    ('8.5', '9,5', 'DIFFERENT', DytavaIllustrations.statusDifferent),
    ('abc', '8,5', 'UNRESOLVED', DytavaIllustrations.statusUnresolved),
  ]) {
    testWidgets(
      'Narrow mobile renders ${sample.$3} with its brand illustration',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(const ExcelCompareApp());
        await tester.enterText(find.byType(TextField).at(0), sample.$1);
        await tester.enterText(find.byType(TextField).at(1), sample.$2);
        await tester.ensureVisible(find.text('So sánh'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('So sánh'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Trạng thái: ${sample.$3}'));
        await tester.pumpAndSettle();
        expect(find.text('Trạng thái: ${sample.$3}'), findsOneWidget);
        expect(
          find.byWidgetPredicate(
            (widget) => widget is DytavaAsset && widget.asset == sample.$4,
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.byType(TextField).first);
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).first, 'changed');
        await tester.pumpAndSettle();
        expect(find.text('Trạng thái: ${sample.$3}'), findsNothing);
      },
    );
  }
}
