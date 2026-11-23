import 'package:dytava/app/workflow_composition.dart';
import 'package:dytava/application/workflow_controller.dart';
import 'package:dytava/domain/workflow.dart';
import 'package:dytava/features/workflow/widgets/workflow_common_widgets.dart';
import 'package:dytava/infrastructure/database/comparison_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart' hide ComparisonResult;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

FrozenPlan _dummyPlan() {
  final snapA = InputSnapshot(
    id: 'snap-a',
    binding: const ImportBinding('art-a', 1, 1, 1),
    fields: [const TableField('id', 'ID')],
    records: const [],
    fullValidation: true,
    ocrReviewed: false,
  );
  final snapB = InputSnapshot(
    id: 'snap-b',
    binding: const ImportBinding('art-b', 1, 1, 1),
    fields: [const TableField('id', 'ID')],
    records: const [],
    fullValidation: true,
    ocrReviewed: false,
  );
  return FrozenPlan(
    'plan-01',
    1,
    snapA,
    snapB,
    ComparisonConfiguration(
      mappings: [const FieldMapping('id', 'id')],
    ),
  );
}

Future<void> _saveDummySession({
  required String id,
  required String labelA,
  required String labelB,
}) async {
  final plan = _dummyPlan();
  final result = ComparisonResult(
    id: id,
    plan: plan,
    cells: const [],
    structural: const [],
    unresolvedRecords: const [],
    matchedRecords: 10,
    alignedRows: const [],
    durationMs: 50,
  );

  await ComparisonDatabase.instance.saveSession(
    result: result,
    labelA: labelA,
    labelB: labelB,
    formatA: SourceFormat.xlsx,
    formatB: SourceFormat.xlsx,
    config: plan.config,
    autoPrune: false,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
  });

  late WorkflowController flow;

  setUp(() async {
    flow = createMobileWorkflow();
    await ComparisonDatabase.instance.init(
      customPath: inMemoryDatabasePath,
      customFactory: databaseFactoryFfi,
    );
    await ComparisonDatabase.instance.clearAll();
  });

  tearDown(() async {
    await ComparisonDatabase.instance.clearAll();
  });

  testWidgets('WorkflowSessionHistoryView displays empty state with illustration and CTA', (tester) async {
    int? count;
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WorkflowSessionHistoryView(
              flow: flow,
              onOpenResults: () {},
              onCountChanged: (c) => count = c,
            ),
          ),
        ),
      );
      while (count == null) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    await tester.pump();

    expect(count, equals(0));
    expect(find.text('No comparisons yet'), findsOneWidget);
    expect(
      find.text(
        'Compare two spreadsheets to find changes,\nreview differences, and save your results here.',
      ),
      findsOneWidget,
    );
    expect(find.text('+ New Comparison'), findsOneWidget);
  });

  testWidgets('WorkflowSessionHistoryView displays saved comparisons and paginates items', (tester) async {
    await tester.runAsync(() async {
      for (int i = 1; i <= 7; i++) {
        await _saveDummySession(
          id: 'session-$i',
          labelA: 'Report $i',
          labelB: 'Updated $i',
        );
      }
    });

    int? reportedCount;
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WorkflowSessionHistoryView(
              flow: flow,
              onOpenResults: () {},
              onCountChanged: (c) => reportedCount = c,
            ),
          ),
        ),
      );
      while (reportedCount == null) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    await tester.pump();

    expect(reportedCount, equals(7));
    expect(find.text('7 saved comparisons'), findsOneWidget);
    expect(find.text('Clear all'), findsOneWidget);

    // Page 1 should show 5 items
    expect(find.text('2 workbooks'), findsNWidgets(5));

    // Pagination bar should show page 1 and page 2
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);

    // Tap page 2
    await tester.runAsync(() async {
      await tester.tap(find.text('2'));
      await Future<void>.delayed(const Duration(milliseconds: 60));
    });
    await tester.pump();

    // Now page 2 should show the remaining 2 items
    expect(find.text('2 workbooks'), findsNWidgets(2));
  });

  testWidgets('Deleting a single session via trash button removes it with confirmation', (tester) async {
    await tester.runAsync(() async {
      await _saveDummySession(
        id: 'session-single',
        labelA: 'Sales Q3',
        labelB: 'Sales Q3 Updated',
      );
    });

    int? count;
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WorkflowSessionHistoryView(
              flow: flow,
              onOpenResults: () {},
              onCountChanged: (c) => count = c,
            ),
          ),
        ),
      );
      while (count == null) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    await tester.pump();

    expect(find.text('Sales Q3'), findsOneWidget);

    // Tap trash icon to open confirmation dialog
    await tester.tap(find.byIcon(Icons.delete_outline_rounded).first);
    await tester.pumpAndSettle();

    // Confirmation dialog appears
    expect(find.text('Delete comparison?'), findsOneWidget);

    // Confirm deletion
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('confirm-delete-item')));
      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    });

    // Now empty state is displayed
    expect(find.text('No comparisons yet'), findsOneWidget);
  });

  testWidgets('Clear all wipes all sessions after confirmation', (tester) async {
    await tester.runAsync(() async {
      for (int i = 1; i <= 3; i++) {
        await _saveDummySession(
          id: 'session-clear-$i',
          labelA: 'Inventory $i',
          labelB: 'Inventory Updated $i',
        );
      }
    });

    int? count;
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WorkflowSessionHistoryView(
              flow: flow,
              onOpenResults: () {},
              onCountChanged: (c) => count = c,
            ),
          ),
        ),
      );
      while (count == null) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    await tester.pump();

    expect(find.text('3 saved comparisons'), findsOneWidget);

    // Tap "Clear all" button in header
    await tester.tap(find.byKey(const Key('history-clear-all-button')));
    await tester.pumpAndSettle();

    // Confirmation dialog appears
    expect(find.text('Clear all history?'), findsOneWidget);

    // Confirm via dialog's Clear all button
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('confirm-clear-all')));
      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    });

    // Empty state should be visible immediately
    expect(find.text('No comparisons yet'), findsOneWidget);
    expect(find.text('+ New Comparison'), findsOneWidget);
  });
}
