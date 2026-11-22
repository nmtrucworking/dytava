import 'package:dytava/design_system/design_system.dart';
import 'package:dytava/features/workflow/screens/launch_screen.dart';
import 'package:dytava/features/workflow/workflow_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Launch identity opens Home after one timeline', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: DytavaTheme.lightTheme,
        home: const DytavaLaunchScreen(child: Text('Workspace ready')),
      ),
    );
    expect(find.text('Opening your workspace'), findsOneWidget);
    final pumps = await tester.pumpAndSettle();
    expect(pumps, lessThan(35));
    expect(find.text('Workspace ready'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 390.0]) {
    testWidgets('Dytava home opens import at ${width}dp', (tester) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(theme: DytavaTheme.lightTheme, home: const WorkflowPage()),
      );
      await tester.pumpAndSettle();
      expect(find.text('Spot the\ndifference.'), findsOneWidget);
      expect(find.text('WORKSPACE / 01'), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Compare files'));
      await tester.pumpAndSettle();
      expect(find.text('Import files'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('Home opens settings and comparison rules', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: DytavaTheme.lightTheme, home: const WorkflowPage()),
    );
    await tester.tap(find.byTooltip('Comparison settings'));
    await tester.pumpAndSettle();
    expect(find.text('App settings'), findsOneWidget);
    await tester.tap(find.text('Comparison rules'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    await tester.tap(find.text('Save settings'));
    await tester.pumpAndSettle();
    expect(find.text('App settings'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
