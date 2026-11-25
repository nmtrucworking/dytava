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
  final target = find.text(text).first;
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> prepare(WorkflowController flow) async {
  for (final side in SourceSide.values) {
    await flow.selectSource(
      side,
      SourceFormat.csv,
      'fixture:${side.name}',
      'sample-${side.name}.csv',
    );
    await flow.importSource(side);
    final slot = flow.slot(side);
    if (slot.state == InputState.needsReview) {
      await flow.confirmImport(side, expectedBinding: slot.binding);
    }
  }
}

void main() {
  testWidgets('Import, auto compare, filter, inspect and export a report', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final flow = createDemoWorkflow();
    addTearDown(flow.dispose);
    await tester.pumpWidget(ExcelCompareApp(controller: flow));
    await tester.tap(find.byTooltip('Compare files'));
    await tester.pumpAndSettle();
    expect(find.text('Import files'), findsOneWidget);
    final compare = find.widgetWithText(FilledButton, 'Compare files');
    expect(tester.widget<FilledButton>(compare).onPressed, isNull);
    await tester.runAsync(() => prepare(flow));
    await tester.pumpAndSettle();
    expect(flow.inputsReady, isTrue);
    await tap(tester, 'Compare files');
    expect(flow.resultCurrent, isTrue);
    expect(find.text('RESULTS READY'), findsOneWidget);
    expect(find.text('Modified 1'), findsOneWidget);
    await tap(tester, 'Modified 1');
    final modified = flow.result!.cells.firstWhere(
      (c) => c.decision.status == DecisionStatus.different,
    );
    final change = find.byKey(ValueKey('change-${modified.id}'));
    await tester.ensureVisible(change);
    await tester.tap(change);
    await tester.pumpAndSettle();
    expect(find.text('Change details'), findsOneWidget);
    expect(find.text(modified.a.rawLexeme!), findsWidgets);
    expect(find.text(modified.b.rawLexeme!), findsWidgets);
    await tap(tester, 'Back to differences');
    await tap(tester, 'Export report');
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Prepare report'),
          )
          .onPressed,
      isNull,
    );
    await tap(tester, 'Confirm format and report scope');
    await tap(tester, 'Prepare report');
    expect(flow.receipt, isNotNull);
    expect(find.text('Report ready'), findsOneWidget);

    // Switch to PDF format inside the kept-open Export modal and prepare PDF report
    await tap(tester, 'PDF');
    await tap(tester, 'Confirm format and report scope');
    await tap(tester, 'Prepare report');
    expect(flow.receipt, isNotNull);
    expect(flow.receipt!.fileName, equals('dytava-report.pdf'));
    expect(flow.receipt!.fileBytes, isNotNull);
    expect(find.text('Report ready'), findsOneWidget);

    await tap(tester, 'Cancel');
    expect(find.text('Comparison results'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Manual setup preserves confirmation until Start comparison is tapped',
    (tester) async {
      final flow = createDemoWorkflow();
      addTearDown(flow.dispose);
      await tester.runAsync(() => prepare(flow));
      flow.analyzeAndPropose();
      flow.applyProposal();
      flow.configure(
        flow.config.copyWith(
          modeConfirmed: false,
          policyConfirmed: false,
          directionConfirmed: false,
        ),
      );
      flow.navigate(WorkflowScreen.policy);
      await tester.pumpWidget(ExcelCompareApp(controller: flow));
      await tester.pumpAndSettle();
      expect(flow.result, isNull);
      expect(flow.config.policyConfirmed, isFalse);
      expect(find.text('Ready for a clear view.'), findsOneWidget);
      await tap(tester, 'Start comparison');
      expect(flow.resultCurrent, isTrue);
      expect(flow.config.policyConfirmed, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Explicit rule edits override auto detection and invalid tolerance blocks running',
    (tester) async {
      final flow = createDemoWorkflow();
      addTearDown(flow.dispose);
      await tester.runAsync(() => prepare(flow));
      flow.analyzeAndPropose();
      flow.applyProposal();
      flow.navigate(WorkflowScreen.policy);
      await tester.pumpWidget(ExcelCompareApp(controller: flow));
      await tap(tester, 'Rules');
      final type = find.byType(DropdownButtonFormField<SemanticType>).last;
      await tester.ensureVisible(type);
      await tester.pumpAndSettle();
      await tester.tap(type);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Text').last);
      await tester.pumpAndSettle();
      expect(flow.config.rules['amount']!.type, SemanticType.freeText);
      expect(flow.config.rules['amount']!.webAuto, isFalse);
      final tolerance = find.byType(TextFormField).last;
      await tester.ensureVisible(tolerance);
      await tester.enterText(tolerance, '-1');
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Start comparison'),
            )
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('OCR import requires confirmation of every uncertain value', (
    tester,
  ) async {
    final flow = WorkflowController(
      input: DemoInputPort(),
      comparator: DemoComparisonPort(),
      exporter: DemoExportPort(),
    );
    addTearDown(flow.dispose);
    await tester.runAsync(() async {
      await flow.selectSource(
        SourceSide.a,
        SourceFormat.png,
        'fixture:image-a',
        'image.png',
      );
      await flow.importSource(SourceSide.a);
      flow.navigate(WorkflowScreen.ocrReview, side: SourceSide.a);
    });
    await tester.pumpWidget(ExcelCompareApp(controller: flow));
    expect(flow.slot(SourceSide.a).ready, isFalse);
    final confirm = find.byWidgetPredicate(
      (w) => w is FilledButton && w.onPressed == null,
    );
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
    for (var i = 0; i < flow.slot(SourceSide.a).review!.cells.length; i++) {
      final checkbox = find.byType(CheckboxListTile).at(i);
      await tester.ensureVisible(checkbox);
      await tester.tap(checkbox);
      await tester.pumpAndSettle();
    }
    await tap(tester, 'Import reviewed values');
    expect(flow.slot(SourceSide.a).ready, isTrue);
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 390.0, 412.0, 600.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('Home, sources, results fit ${width}dp at ${scale}x text', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final flow = createDemoWorkflow();
        addTearDown(flow.dispose);
        await tester.pumpWidget(
          MaterialApp(
            theme: DytavaTheme.lightTheme,
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(width, 844),
                textScaler: TextScaler.linear(scale),
                disableAnimations: true,
              ),
              child: WorkflowPage(controller: flow),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.byTooltip('Compare files'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.runAsync(() async {
          await prepare(flow);
          flow.analyzeAndPropose();
          flow.applyProposal();
          await flow.runComparison();
        });
        await tester.pumpAndSettle();
        expect(find.text('RESULTS READY'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('Brand assets render without SVG errors', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: DytavaTheme.lightTheme,
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                for (final asset in DytavaIllustrations.allAssets)
                  BrandIllustration(asset, size: 48),
                for (final asset in DytavaIcons.allCoreAssets)
                  BrandIcon(asset, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

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
