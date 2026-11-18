import 'package:dytava/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DYTAVA — Precision Workspace Branding Tests', () {
    test('Official Precision Workspace color tokens match brand specifications', () {
      expect(DytavaColors.limePrimary, const Color(0xFFC8FF4A));
      expect(DytavaColors.lime600, const Color(0xFF86E63A));
      expect(DytavaColors.offWhite, const Color(0xFFF7F6F2));
      expect(DytavaColors.warmSurface, const Color(0xFFEDEBE4));
      expect(DytavaColors.graphite, const Color(0xFF0F1A1C));
      expect(DytavaColors.graphite800, const Color(0xFF1B2426));
      expect(DytavaColors.differenceCoral, const Color(0xFFE97965));
      expect(DytavaColors.precisionNeutral, const Color(0xFF607276));
      expect(DytavaColors.signalLime, const Color(0xFFC8FF4A));
    });

    testWidgets('ComparisonRail renders dual-stream connected structure and handles actions', (
      tester,
    ) async {
      bool primaryActionTriggered = false;
      bool streamATapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: DytavaTheme.lightTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: ComparisonRail(
                sessionTitle: 'ACTIVE COMPARISON',
                statusLabel: 'Đang chuẩn bị',
                sourceA: RailStreamData(
                  sideTag: 'A',
                  title: 'sample-image.png',
                  subtitle: 'Cần xác minh dữ liệu',
                  format: 'png',
                  status: RailNodeStatus.needsReview,
                  onTap: () => streamATapped = true,
                ),
                sourceB: const RailStreamData(
                  sideTag: 'B',
                  title: 'Chọn nguồn B',
                  subtitle: 'Chưa có dữ liệu',
                  status: RailNodeStatus.unselected,
                ),
                onPrimaryAction: () => primaryActionTriggered = true,
                primaryActionLabel: 'Tiếp tục thiết lập',
              ),
            ),
          ),
        ),
      );

      expect(find.text('ACTIVE COMPARISON'), findsOneWidget);
      expect(find.text('Đang chuẩn bị'), findsOneWidget);
      expect(find.text('sample-image.png'), findsOneWidget);
      expect(find.text('Cần xác minh dữ liệu'), findsOneWidget);
      expect(find.text('Chọn nguồn B'), findsOneWidget);
      expect(find.text('Chưa có dữ liệu'), findsOneWidget);
      expect(find.text('Tiếp tục thiết lập'), findsOneWidget);

      await tester.tap(find.text('sample-image.png'));
      expect(streamATapped, isTrue);

      await tester.tap(find.text('Tiếp tục thiết lập'));
      expect(primaryActionTriggered, isTrue);
    });

    testWidgets('DifferenceFingerprint renders segments and density metrics', (
      tester,
    ) async {
      int? tappedSegment;

      await tester.pumpWidget(
        MaterialApp(
          theme: DytavaTheme.lightTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: DifferenceFingerprint.fromCounts(
                exactCount: 80,
                equivalentCount: 10,
                differentCount: 8,
                unresolvedCount: 2,
                onSegmentTap: (index) => tappedSegment = index,
              ),
            ),
          ),
        ),
      );

      expect(find.text('BẢN ĐỒ SAI KHÁC (FINGERPRINT)'), findsOneWidget);
      expect(find.text('Trùng khớp'), findsOneWidget);
      expect(find.text('(90)'), findsOneWidget);
      expect(find.text('Sai khác'), findsOneWidget);
      expect(find.text('(8)'), findsOneWidget);
      expect(find.text('Cần xem xét'), findsOneWidget);
      expect(find.text('(2)'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText().contains('8.0%'),
        ),
        findsOneWidget,
      );

      // Verify that tap interaction functions without error
      final gestureFinders = find.byType(GestureDetector);
      expect(gestureFinders, findsWidgets);
      await tester.tap(gestureFinders.first);
      expect(tappedSegment, isNotNull);
    });

    testWidgets('FocusDiffCard renders single-record focused A/B pair with haptic navigation', (
      tester,
    ) async {
      bool prevTapped = false;
      bool nextTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: DytavaTheme.lightTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: FocusDiffCard(
                fieldName: 'Doanh thu Q3',
                rowIdentifier: 'Hàng 42 · ID: KH0092',
                statusText: 'DIFFERENT',
                statusColor: DytavaColors.differenceCoral,
                rawA: '1,450,000,000 VND',
                rawB: '1,540,000,000 VND',
                sourceRefA: 'Sheet1!D42',
                sourceRefB: 'Báo cáo Q3!D42',
                ruleReason: 'Quy tắc: semantic/DECIMAL/absolute_tolerance',
                currentIndex: 3,
                totalDiffs: 12,
                onPrevious: () => prevTapped = true,
                onNext: () => nextTapped = true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Doanh thu Q3'), findsOneWidget);
      expect(find.text('Hàng 42 · ID: KH0092'), findsOneWidget);
      expect(find.text('DIFFERENT'), findsOneWidget);
      expect(find.text('1,450,000,000 VND'), findsOneWidget);
      expect(find.text('1,540,000,000 VND'), findsOneWidget);
      expect(find.text('Sheet1!D42'), findsOneWidget);
      expect(find.text('Báo cáo Q3!D42'), findsOneWidget);
      expect(find.textContaining('semantic/DECIMAL/absolute_tolerance'), findsOneWidget);
      expect(find.text('Sai khác 3 / 12'), findsOneWidget);

      await tester.tap(find.byTooltip('Sai khác trước'));
      expect(prevTapped, isTrue);

      await tester.tap(find.byTooltip('Sai khác tiếp theo'));
      expect(nextTapped, isTrue);
    });
  });
}
