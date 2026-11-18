import 'package:dytava/design_system/design_system.dart';
import 'package:dytava/features/workflow/workflow_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final width in <double>[320, 390]) {
    testWidgets('Mobile home is usable at ${width.toInt()}dp', (tester) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: DytavaTheme.lightTheme,
          home: const WorkflowPage(),
        ),
      );

      expect(find.text('Nhìn rõ từng sai khác.'), findsOneWidget);
      expect(find.text('Bản demo'), findsOneWidget);
      expect(find.text('Bắt đầu so sánh'), findsOneWidget);
      expect(find.byTooltip('Thêm tùy chọn'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.ensureVisible(find.text('Bắt đầu so sánh'));
      await tester.tap(find.text('Bắt đầu so sánh'));
      await tester.pumpAndSettle();

      expect(find.text('Chọn nguồn A/B'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Auxiliary actions are grouped under one overflow menu', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: DytavaTheme.lightTheme,
        home: const WorkflowPage(),
      ),
    );

    await tester.tap(find.byTooltip('Thêm tùy chọn'));
    await tester.pumpAndSettle();

    expect(find.text('Mẫu quy tắc'), findsOneWidget);
    expect(find.text('Cài đặt & bảo mật'), findsOneWidget);
    await tester.tap(find.text('Cài đặt & bảo mật'));
    await tester.pumpAndSettle();

    expect(find.text('Cài đặt & bảo mật'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
