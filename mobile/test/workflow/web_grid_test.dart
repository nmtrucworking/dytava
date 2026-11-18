import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dytava/design_system/design_system.dart';
import 'package:dytava/features/workflow/widgets/mobile_aligned_grid.dart';
import 'package:dytava/infrastructure/mobile_comparison_port.dart';

import 'web_parity_test.dart' show plan, table;

void main() {
  for (final width in [320.0, 800.0]) {
    testWidgets(
      'aligned grid preserves inserted gap, filters and inspection at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final result = compareMobileTables(
          plan(
            table(
              'A',
              ['Title'],
              [
                ['Alpha'],
                ['Beta'],
              ],
            ),
            table(
              'B',
              ['Title'],
              [
                ['Alpha'],
                ['New'],
                ['Beta'],
              ],
            ),
          ),
          (_, _, _) {},
        );
        String? selected;
        await tester.pumpWidget(
          MaterialApp(
            theme: DytavaTheme.lightTheme,
            home: Scaffold(
              body: ListView(
                children: [
                  MobileAlignedGrid(
                    result: result,
                    onOpenCell: (id) => selected = id,
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byKey(const ValueKey('aligned-b-B-1')), findsOneWidget);
        await tester.tap(find.text('Alpha').first);
        expect(selected, isNotNull);
        await tester.tap(find.text('ADDED (1)'));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('aligned-b-B-1')), findsOneWidget);
        expect(find.text('Alpha'), findsNothing);
        await tester.tap(find.byKey(const ValueKey('aligned-b-B-1')));
        await tester.pumpAndSettle();
        expect(find.text('Dòng thêm ở nguồn B'), findsOneWidget);
      },
    );
  }
}
