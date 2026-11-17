import 'package:dytava/application/workflow_controller.dart';
import 'package:dytava/design_system/design_system.dart';
import 'package:dytava/domain/workflow.dart';
import 'package:dytava/features/workflow/workflow_page.dart';
import 'package:dytava/infrastructure/demo/demo_workflow_ports.dart';
import 'package:dytava/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> tap(WidgetTester tester, String text) async {
  final target = find.text(text);
  await tester.scrollUntilVisible(
    target,
    250,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'mobile user can complete source/configuration/result/detail/export activities',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const ExcelCompareApp());
      await tap(tester, 'So sánh mới (dữ liệu mẫu)');
      final continueButton = find.widgetWithText(
        FilledButton,
        'Tiếp tục ánh xạ cột',
      );
      await tester.scrollUntilVisible(
        continueButton,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.widget<FilledButton>(continueButton).onPressed, isNull);
      // Start each independent source, inspect scope and explicitly confirm it.
      for (final side in ['A', 'B']) {
        await tester.drag(find.byType(ListView), const Offset(0, 1000));
        await tester.pumpAndSettle();
        await tap(tester, 'Chọn bảng mẫu $side');
        await tap(tester, 'Kiểm tra $side');
        await tap(tester, 'Kiểm tra nguồn mẫu');
        await tap(tester, 'Xác nhận phạm vi và header mẫu');
        await tap(tester, 'Trở về nguồn A/B');
      }
      await tap(tester, 'Tiếp tục ánh xạ cột');
      for (final field in [('id', 'Mã (id)'), ('amount', 'Giá trị (amount)')]) {
        final dropdown = find.byKey(ValueKey('mapping-${field.$1}-null'));
        await tester.ensureVisible(dropdown);
        await tester.tap(dropdown);
        await tester.pumpAndSettle();
        await tester.tap(find.text(field.$2).last);
        await tester.pumpAndSettle();
      }
      await tap(tester, 'Xác nhận ánh xạ hiện hành');
      await tap(tester, 'Tiếp tục cấu hình so sánh');
      await tap(tester, 'Xác nhận chế độ và khóa');
      await tap(tester, 'Xác nhận toàn bộ policy');
      await tap(tester, 'Xác nhận chiều so sánh');
      await tap(tester, 'Chạy so sánh mẫu');
      expect(find.text('COMPLETED · Kết quả bộ dữ liệu mẫu'), findsOneWidget);
      expect(find.text('EXACT: 5'), findsOneWidget);
      await tap(tester, 'amount: EQUIVALENT');
      expect(find.text('Raw: 8.5'), findsOneWidget);
      expect(find.text('Raw: 8,5'), findsOneWidget);
      await tap(tester, 'Trở về kết quả');
      await tap(tester, 'Xuất / xem trước báo cáo');
      await tap(tester, 'Xác nhận định dạng và phạm vi preview');
      await tap(tester, 'Tạo preview JSON mẫu');
      expect(
        find.text('Preview hoàn tất · Không có tệp được xuất.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'OCR flow requires each selected cell review and rejects stale screen data',
    (tester) async {
      final f = WorkflowController(
        input: DemoInputPort(),
        comparator: DemoComparisonPort(),
        exporter: DemoExportPort(),
      );
      addTearDown(f.dispose);
      await tester.runAsync(() async {
        await f.selectSource(
          SourceSide.a,
          SourceFormat.png,
          'fixture:image-a',
          'image.png',
        );
        await f.importSource(SourceSide.a);
        f.navigate(WorkflowScreen.ocrReview, side: SourceSide.a);
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: DytavaTheme.lightTheme,
          home: WorkflowPage(controller: f),
        ),
      );
      final confirm = find.widgetWithText(
        FilledButton,
        'Xác nhận các ô đã review',
      );
      await tester.scrollUntilVisible(
        confirm,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
      await tester.drag(find.byType(ListView), const Offset(0, 1500));
      await tester.pumpAndSettle();
      final cells = f.slot(SourceSide.a).review!.cells;
      for (final cell in cells) {
        await tap(tester, '${cell.id}: ${cell.recognizedText}');
      }
      await tap(tester, 'Xác nhận các ô đã review');
      expect(f.slot(SourceSide.a).ready, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'mobile user can use fast-track 1-tap flow to quickly reach comparison results and navigate diffs',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const ExcelCompareApp());
      // 1-Tap Fast Run right from Home
      await tap(tester, 'Trải nghiệm nhanh (1 chạm)');
      expect(find.text('COMPLETED · Kết quả bộ dữ liệu mẫu'), findsOneWidget);
      expect(find.text('EXACT: 5'), findsOneWidget);

      // Filter chips quick selection
      await tap(tester, 'Khác biệt (1)');
      expect(find.text('amount: DIFFERENT'), findsOneWidget);

      // Open detail
      await tap(tester, 'amount: DIFFERENT');
      expect(find.text('Raw: 10'), findsOneWidget);

      // Next / Previous diff navigation inside detail
      expect(find.text('Khác biệt 1/1'), findsOneWidget);
      await tap(tester, 'Trở về kết quả');

      // Export preview
      await tap(tester, 'Xuất / xem trước báo cáo');
      await tap(tester, 'Xác nhận định dạng và phạm vi preview');
      await tap(tester, 'Tạo preview JSON mẫu');
      expect(find.text('Preview hoàn tất · Không có tệp được xuất.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'mobile bottom tabbar, UI components and 2-sheet diff view work seamlessly',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const ExcelCompareApp());
      expect(find.byType(DytavaBottomNavBar), findsOneWidget);

      // Navigate across bottom tabs: Học tập & Quy tắc -> Cài đặt -> Trang chủ
      await tester.tap(find.text('Học tập'));
      await tester.pumpAndSettle();
      expect(find.text('academic-records-v1'), findsOneWidget);
      expect(find.byType(DytavaPolicyCard), findsWidgets);

      await tester.tap(find.text('Cài đặt'));
      await tester.pumpAndSettle();
      expect(find.text('Sheet Diff 2 Sheets (Hợp nhất & Song song)'), findsOneWidget);

      await tester.tap(find.text('Trang chủ'));
      await tester.pumpAndSettle();

      // Run 1-tap Sheet Diff 2 Sheets
      await tap(tester, 'Trải nghiệm nhanh (1 chạm)');
      await tester.scrollUntilVisible(
        find.text('Sheet Diff: Sheet A (4 hàng) ↔ Sheet B (5 hàng)'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byType(DytavaSheetDiffView), findsOneWidget);
      expect(
        find.text('Sheet Diff: Sheet A (4 hàng) ↔ Sheet B (5 hàng)'),
        findsOneWidget,
      );

      // Switch Sheet Diff layout to Side-by-Side 2 Sheets (A | B)
      await tap(tester, 'Song song 2 Sheets (A | B)');
      expect(find.text('SHEET A ( gốc )'), findsOneWidget);
      expect(find.text('SHEET B ( đối chiếu )'), findsOneWidget);

      // Switch back to Unified 2-Sheet Diff
      await tap(tester, 'Bảng hợp nhất (A ↔ B)');
      expect(find.text('Cột id ↔ id'), findsOneWidget);
      expect(find.text('Cột amount ↔ amount'), findsOneWidget);

      // Check History tab shows the completed 2-sheet session
      await tester.tap(find.text('Lịch sử'));
      await tester.pumpAndSettle();
      expect(find.byType(DytavaHistoryCard), findsOneWidget);
      expect(find.byType(DytavaResultCard), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
