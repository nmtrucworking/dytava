import 'package:dytava/app/workflow_composition.dart';
import 'package:dytava/application/workflow_controller.dart';
import 'package:dytava/design_system/design_system.dart';
import 'package:dytava/domain/workflow.dart';
import 'package:dytava/features/workflow/workflow_page.dart';
import 'package:dytava/infrastructure/demo/demo_workflow_ports.dart';
import 'package:dytava/main.dart';
import 'package:excelcompare_core/excelcompare_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart' hide ComparisonResult;

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
      await tester.pumpWidget(
        ExcelCompareApp(controller: createDemoWorkflow()),
      );
      await tap(tester, 'Bắt đầu so sánh');
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
      await tap(tester, 'Chạy so sánh');
      expect(find.text('COMPLETED · Kết quả so sánh'), findsOneWidget);
      expect(find.text('EXACT: 5'), findsOneWidget);
      await tap(tester, 'amount: EQUIVALENT');
      expect(find.text('Raw: 8.5'), findsOneWidget);
      expect(find.text('Raw: 8,5'), findsOneWidget);
      await tap(tester, 'Trở về kết quả');
      await tap(tester, 'Xuất / xem trước báo cáo');
      await tap(tester, 'Xác nhận định dạng và phạm vi preview');
      await tap(tester, 'Tạo bản xem trước');
      expect(find.text('Bản xem trước đã sẵn sàng.'), findsOneWidget);
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

      await tester.pumpWidget(
        ExcelCompareApp(controller: createDemoWorkflow()),
      );
      // 1-Tap Fast Run right from Home
      await tap(tester, 'Thử nhanh với dữ liệu mẫu');
      expect(find.text('COMPLETED · Kết quả so sánh'), findsOneWidget);
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
      await tap(tester, 'Tạo bản xem trước');
      expect(find.text('Bản xem trước đã sẵn sàng.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Guided Mobile Workflow navigation, auxiliary views, session resume card and 2-sheet diff view work seamlessly',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ExcelCompareApp(controller: createDemoWorkflow()),
      );

      // Open auxiliary Policy Presets & Learn view from Home overflow menu
      await tester.tap(find.byTooltip('Thêm tùy chọn'));
      await tester.pumpAndSettle();
      await tap(tester, 'Mẫu quy tắc');
      expect(find.text('academic-records-v1'), findsOneWidget);
      expect(find.byType(DytavaPolicyCard), findsWidgets);

      // Return to Home via Back button
      await tester.tap(find.byTooltip('Quay lại'));
      await tester.pumpAndSettle();

      // Open Settings & Privacy auxiliary view from Home overflow menu
      await tester.tap(find.byTooltip('Thêm tùy chọn'));
      await tester.pumpAndSettle();
      await tap(tester, 'Cài đặt & bảo mật');
      expect(
        find.text('Sheet Diff 2 Sheets (Hợp nhất & Song song)'),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Quay lại'));
      await tester.pumpAndSettle();

      // Run 1-tap Sheet Diff 2 Sheets (ExcelCompare.org Dual Grid Table Diff)
      await tap(tester, 'Thử nhanh với dữ liệu mẫu');
      await tester.scrollUntilVisible(
        find.byType(DytavaSheetDiffView),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byType(DytavaSheetDiffView), findsOneWidget);
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Added'), findsOneWidget);
      expect(find.text('Deleted'), findsOneWidget);
      expect(find.text('Unchanged'), findsOneWidget);
      expect(find.text('Modified'), findsOneWidget);
      expect(find.textContaining('Sheet A ·'), findsOneWidget);
      expect(find.textContaining('Sheet B ·'), findsOneWidget);

      // Filter by Added, Modified, Unchanged and return to All on the ExcelCompare.org ribbon
      await tap(tester, 'Added');
      expect(find.text('005'), findsOneWidget);
      await tap(tester, 'Modified');
      expect(find.text('8.5'), findsOneWidget);
      expect(find.text('8,5'), findsOneWidget);
      await tap(tester, 'All');
      expect(find.text('id (Mã)'), findsWidgets);
      expect(find.text('amount (Giá trị)'), findsWidgets);

      // Return to Home via AppBar Home action and verify Session Resume Card ("Tiếp tục phiên của bạn")
      await tester.tap(find.byTooltip('Về trang chủ'));
      await tester.pumpAndSettle();
      expect(find.byType(DytavaSessionResumeCard), findsOneWidget);
      expect(find.text('Tiếp tục phiên của bạn'), findsOneWidget);
      expect(find.byType(DytavaResultCard), findsOneWidget);

      // Open current session history view from AppBar
      await tester.tap(find.byTooltip('Phiên trong bộ nhớ'));
      await tester.pumpAndSettle();
      expect(find.byType(DytavaHistoryCard), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'P0: configuration confirmation sheet prevents silent policy approval until user explicitly confirms',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final f = WorkflowController(
        input: DemoInputPort(),
        comparator: DemoComparisonPort(),
        exporter: DemoExportPort(),
      );
      addTearDown(f.dispose);

      await tester.runAsync(() async {
        for (final side in SourceSide.values) {
          await f.selectSource(
            side,
            SourceFormat.csv,
            side == SourceSide.a ? 'fixture:a' : 'fixture:b',
            'sample.csv',
          );
          await f.importSource(side);
          await f.confirmImport(side, expectedBinding: f.slot(side).binding);
        }
        f.configure(
          ComparisonConfiguration(
            mappings: const [
              FieldMapping('id', 'id'),
              FieldMapping('amount', 'amount'),
            ],
            rules: const {
              'id': FieldRule(type: SemanticType.identifier),
              'amount': FieldRule(type: SemanticType.decimal),
            },
            mappingConfirmed: true,
            modeConfirmed: false,
            policyConfirmed: false,
            directionConfirmed: false,
          ),
        );
        f.navigate(WorkflowScreen.policy);
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: DytavaTheme.lightTheme,
          home: WorkflowPage(controller: f),
        ),
      );
      await tester.pumpAndSettle();

      // Tapping fast confirm on unapproved config opens the confirmation summary sheet instead of silently running
      await tap(tester, 'Xem tóm tắt & Xác nhận cấu hình');
      expect(find.text('Xác nhận cấu hình đối chiếu tổng hợp'), findsOneWidget);
      expect(
        find.textContaining('1. Chế độ ghép hàng & Khóa định danh'),
        findsOneWidget,
      );
      expect(find.textContaining('2. Chính sách chuẩn hóa'), findsOneWidget);
      expect(find.textContaining('3. Chiều so sánh'), findsOneWidget);

      // Dismissing via "Chỉnh sửa lại" does not run comparison
      await tester.tap(find.text('Chỉnh sửa lại'));
      await tester.pumpAndSettle();
      expect(f.screen, WorkflowScreen.policy);
      expect(f.config.policyConfirmed, isFalse);

      // Opening again and confirming runs comparison
      await tap(tester, 'Xem tóm tắt & Xác nhận cấu hình');
      await tester.tap(find.text('Xác nhận lần này & Chạy'));
      await tester.pumpAndSettle();
      expect(f.screen, WorkflowScreen.results);
      expect(f.config.modeConfirmed, isTrue);
      expect(f.config.policyConfirmed, isTrue);
      expect(f.config.directionConfirmed, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'P0: wide 8-column table scrolls horizontally with pinned row identifier and opens cell detail bottom sheet',
    (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final fields = [
        for (var i = 1; i <= 8; i++)
          TableField('col_$i', 'Trường dữ liệu mở rộng số $i'),
      ];
      final records = [
        for (var r = 0; r < 3; r++)
          TableRecord(
            'r_${r + 1}',
            r,
            {
              for (var i = 1; i <= 8; i++)
                'col_$i': SourceCell(
                  CellKind.text,
                  rawLexeme: 'Giá trị hàng ${r + 1} cột $i',
                ),
            },
            {for (var i = 1; i <= 8; i++) 'col_$i': 'R${r + 1}C$i'},
          ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: DytavaTheme.lightTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: DytavaSheetPreviewTable(
                sheetTitle: 'Bảng rộng 8 cột',
                fields: fields,
                records: records,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('3 hàng × 8 cột · ↔ Cuộn ngang'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'P0 & P1: priority diff cards, bottom sheet detail, 200% text scale and responsive device matrix render without overflow',
    (tester) async {
      for (final viewport in const [
        Size(320, 640),
        Size(360, 780),
        Size(390, 844),
        Size(768, 1024),
      ]) {
        tester.view.physicalSize = viewport;
        tester.view.devicePixelRatio = 1;

        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(
              size: viewport,
              textScaler: const TextScaler.linear(2.0),
            ),
            child: ExcelCompareApp(controller: createDemoWorkflow()),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        MaterialApp(
          theme: DytavaTheme.lightTheme,
          home: WorkflowPage(controller: createDemoWorkflow()),
        ),
      );
      await tap(tester, 'Thử nhanh với dữ liệu mẫu');

      // Priority diff section is shown above the spreadsheet grid
      await tester.scrollUntilVisible(
        find.textContaining('Các khác biệt cần kiểm tra'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('Các khác biệt cần kiểm tra'), findsOneWidget);
      expect(find.byType(DytavaPriorityDiffCard), findsWidgets);

      // Open quick inspection Bottom Sheet from Priority Diff Card
      final quickSheetBtn = find.text('Xem nhanh (Sheet)').first;
      await tester.ensureVisible(quickSheetBtn);
      await tester.pumpAndSettle();
      await tester.tap(quickSheetBtn);
      await tester.pumpAndSettle();
      expect(
        find.text('1. Phân biệt Giá trị gốc (Raw) & Sau chuẩn hóa (Canonical)'),
        findsOneWidget,
      );
      expect(
        find.text('2. Nguyên nhân & Căn cứ quyết định (Rationale)'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Đóng'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Đóng'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Automated Brand Asset QA: all 47 DytavaIllustrations and core DytavaIcons render and transition by business state',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // 1. Verify state-driven BrandIllustration transitions across workflow
      await tester.pumpWidget(
        ExcelCompareApp(controller: createDemoWorkflow()),
      );

      // Go to Source Selection: unselected slots show emptyFiles illustration
      await tap(tester, 'Bắt đầu so sánh');
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is BrandIllustration &&
              w.asset == DytavaIllustrations.emptyFiles,
        ),
        findsNWidgets(2),
      );

      // Selecting Source A replaces its emptyFiles illustration with fileCsv format BrandIcon
      await tap(tester, 'Chọn bảng mẫu A');
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is BrandIllustration &&
              w.asset == DytavaIllustrations.emptyFiles,
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is BrandIcon && w.asset == DytavaIcons.fileCsv,
        ),
        findsWidgets,
      );

      // 2. Render gallery of all 47 DytavaIllustrations and all core DytavaIcons to verify SVG asset integrity
      expect(DytavaIllustrations.allAssets.length, 47);
      expect(DytavaIcons.allCoreAssets.length, greaterThanOrEqualTo(75));

      await tester.pumpWidget(
        MaterialApp(
          theme: DytavaTheme.lightTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  for (final ill in DytavaIllustrations.allAssets)
                    BrandIllustration(ill, size: 48),
                  for (final ic in DytavaIcons.allCoreAssets)
                    BrandIcon(ic, size: 20),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'ExcelCompare.org dual-grid Table Diff virtualizes large tables, syncs scrolling/selection and opens fullscreen view',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const fields = [
        TableField('id', 'ID'),
        TableField('name', 'Name'),
        TableField('dept', 'Dept'),
        TableField('salary', 'Salary'),
      ];
      final recordsA = [
        for (var r = 0; r < 80; r++)
          TableRecord('a-$r', r, {
            'id': SourceCell(CellKind.text, rawLexeme: '${r + 1}'),
            'name': SourceCell(CellKind.text, rawLexeme: 'User_${r + 1}'),
            'dept': SourceCell(
              CellKind.text,
              rawLexeme: r == 2 ? 'Sales' : 'Eng',
            ),
            'salary': SourceCell(
              CellKind.text,
              rawLexeme: '${50000 + r * 100}',
            ),
          }, {}),
      ];
      final recordsB = [
        for (var r = 0; r < 80; r++)
          if (r != 4) // Row 5 is deleted on B
            TableRecord('b-$r', r, {
              'id': SourceCell(CellKind.text, rawLexeme: '${r + 1}'),
              'name': SourceCell(CellKind.text, rawLexeme: 'User_${r + 1}'),
              'dept': SourceCell(
                CellKind.text,
                rawLexeme: r == 2 ? 'Marketing' : 'Eng',
              ),
              'salary': SourceCell(
                CellKind.text,
                rawLexeme: r == 2 ? '55400' : '${50000 + r * 100}',
              ),
            }, {}),
        TableRecord('b-80', 80, {
          'id': const SourceCell(CellKind.text, rawLexeme: '81'),
          'name': const SourceCell(CellKind.text, rawLexeme: 'Added_User_81'),
          'dept': const SourceCell(CellKind.text, rawLexeme: 'Ops'),
          'salary': const SourceCell(CellKind.text, rawLexeme: '62000'),
        }, {}),
      ];

      final snapA = InputSnapshot(
        id: 'snap-a',
        binding: const ImportBinding('a', 1, 1, 1),
        fields: fields,
        records: recordsA,
        fullValidation: true,
        ocrReviewed: false,
      );
      final snapB = InputSnapshot(
        id: 'snap-b',
        binding: const ImportBinding('b', 1, 1, 1),
        fields: fields,
        records: recordsB,
        fullValidation: true,
        ocrReviewed: false,
      );
      final config = ComparisonConfiguration(
        mappings: const [
          FieldMapping('id', 'id'),
          FieldMapping('name', 'name'),
          FieldMapping('dept', 'dept'),
          FieldMapping('salary', 'salary'),
        ],
        rules: const {
          'id': FieldRule(type: SemanticType.identifier),
          'name': FieldRule(type: SemanticType.identifier),
          'dept': FieldRule(type: SemanticType.identifier),
          'salary': FieldRule(type: SemanticType.decimal),
        },
        mode: MatchingMode.key,
        keys: const ['id'],
        mappingConfirmed: true,
        modeConfirmed: true,
        policyConfirmed: true,
        directionConfirmed: true,
      );
      late final ComparisonResult result;
      await tester.runAsync(() async {
        result = await DemoComparisonPort().compare(
          FrozenPlan('perf-plan', 1, snapA, snapB, config),
          Cancellation(),
          (_, _, _) {},
        );
      });

      String? selectedCellId;
      await tester.pumpWidget(
        MaterialApp(
          theme: DytavaTheme.lightTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: DytavaSheetDiffView(
                result: result,
                visibleCells: result.cells.take(12).toList(),
                onSelectCell: (id) => selectedCellId = id,
                sourceALabel: 'left_large.csv',
                sourceBLabel: 'right_samecols.csv',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify virtualization: row 1 (User_1) is mounted, while offscreen row 75 (User_75) is not mounted in DOM/tree
      expect(find.text('User_1'), findsNWidgets(2));
      expect(find.text('User_75'), findsNothing);

      // Verify Modified cell values ('Sales' on Left, 'Marketing' on Right) are rendered side-by-side
      expect(find.text('Sales'), findsOneWidget);
      expect(find.text('Marketing'), findsOneWidget);

      // Filter by Deleted rows -> shows row 5 (User_5) on Left with hatched placeholder on Right
      await tester.tap(find.text('Deleted'));
      await tester.pumpAndSettle();
      expect(find.text('User_5'), findsOneWidget);

      // Filter by Added rows -> shows row 81 (Added_User_81) on Right with hatched placeholder on Left
      await tester.tap(find.text('Added'));
      await tester.pumpAndSettle();
      expect(find.text('Added_User_81'), findsOneWidget);

      // Return to All and open Fullscreen Table Diff modal
      await tester.tap(find.text('All'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Fullscreen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fullscreen'));
      await tester.pumpAndSettle();
      expect(
        find.text('Table Diff · left_large.csv ↔ right_samecols.csv'),
        findsOneWidget,
      );
      await tester.tap(find.text('Thu nhỏ'));
      await tester.pumpAndSettle();

      // Tap 'Chi tiết ô' on the active cell inspector bar
      await tester.tap(find.text('Chi tiết ô'));
      await tester.pumpAndSettle();
      expect(selectedCellId, isNotNull);
      expect(tester.takeException(), isNull);
    },
  );
}
