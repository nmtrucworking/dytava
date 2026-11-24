import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dytava/app/workflow_composition.dart';
import 'package:dytava/l10n/app_localizations.dart';
import 'package:dytava/main.dart';

void main() {
  testWidgets('Dynamic bilingual language toggle switches between EN and VI via More popover', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final flow = createDemoWorkflow();
    addTearDown(flow.dispose);

    await tester.pumpWidget(ExcelCompareApp(controller: flow));
    await tester.pumpAndSettle();

    // Default locale is English
    expect(flow.locale.languageCode, equals('en'));
    expect(find.text('Tap to compare'), findsOneWidget);

    // Navigate to Import files screen where More popover is available
    await tester.tap(find.byTooltip('Compare files'));
    await tester.pumpAndSettle();
    expect(find.text('Import files'), findsOneWidget);
    expect(find.byKey(const ValueKey('more-popover-trigger')), findsOneWidget);

    // Open More popover
    await tester.tap(find.byKey(const ValueKey('more-popover-trigger')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('popover-plus')), findsOneWidget);
    expect(find.byKey(const ValueKey('popover-close-session')), findsOneWidget);
    expect(find.byKey(const ValueKey('app-language-toggle')), findsOneWidget);
    expect(find.byKey(const ValueKey('popover-home')), findsOneWidget);
    expect(find.text('EN'), findsOneWidget);

    // Tap language toggle inside popover to switch to Vietnamese
    await tester.tap(find.byKey(const ValueKey('app-language-toggle')));
    await tester.pumpAndSettle();

    // Should now be in Vietnamese (showing VN badge in popover)
    expect(flow.locale.languageCode, equals('vi'));
    expect(find.text('VN'), findsOneWidget);
    expect(find.text('Nhập tệp'), findsOneWidget);

    // Tap again to switch back to English
    await tester.tap(find.byKey(const ValueKey('app-language-toggle')));
    await tester.pumpAndSettle();

    expect(flow.locale.languageCode, equals('en'));
    expect(find.text('EN'), findsOneWidget);
    expect(find.text('Import files'), findsOneWidget);

    // Close popover via + button
    await tester.tap(find.byKey(const ValueKey('popover-plus')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('popover-plus')), findsNothing);
  });

  testWidgets('More popover animates + icon first, then 3 icons sequentially along circular arc, and App Settings matches new design', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final flow = createDemoWorkflow();
    addTearDown(flow.dispose);

    await tester.pumpWidget(ExcelCompareApp(controller: flow));
    await tester.pumpAndSettle();

    // Verify App Settings new UI
    await tester.tap(find.byTooltip('Comparison settings'));
    await tester.pumpAndSettle();

    expect(find.text('Dytava'), findsWidgets);
    expect(find.text('Excel Compare · v0.1.0'), findsOneWidget);
    expect(find.text('Help & support'), findsOneWidget);
    expect(find.text('Quick'), findsOneWidget);
    expect(find.text('12.4 MB'), findsOneWidget);
    expect(find.byKey(const ValueKey('settings-language-en')), findsOneWidget);
    expect(find.byKey(const ValueKey('settings-language-vi')), findsOneWidget);

    // Switch language in App Settings
    await tester.tap(find.byKey(const ValueKey('settings-language-vi')));
    await tester.pumpAndSettle();
    expect(flow.locale.languageCode, equals('vi'));
    expect(find.text('NGÔN NGỮ'), findsOneWidget);
    expect(find.text('ĐỐI SOÁT'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('settings-language-en')));
    await tester.pumpAndSettle();
    expect(flow.locale.languageCode, equals('en'));
  });

  test('AppLocalizations dictionary completeness and fallback resolution', () {
    final vi = AppLocalizations(const Locale('vi'));
    final en = AppLocalizations(const Locale('en'));

    expect(vi.isVietnamese, isTrue);
    expect(en.isVietnamese, isFalse);

    // App & Branding
    expect(vi.appSubtitle, equals('So sánh Excel'));
    expect(en.appSubtitle, equals('Excel Compare'));
    expect(vi.spotTheDifferenceInline, equals('Nhận diện sai khác.'));
    expect(en.spotTheDifferenceInline, equals('Spot the difference.'));

    // Common Actions
    expect(vi.confirm, equals('Xác nhận'));
    expect(en.confirm, equals('Confirm'));
    expect(vi.close, equals('Đóng'));
    expect(en.close, equals('Close'));
    expect(vi.clearAll, equals('Xóa tất cả'));
    expect(en.clearAll, equals('Clear all'));

    // Navigation & Stages
    expect(vi.titleHome, equals('Dytava'));
    expect(en.titleHome, equals('Dytava'));
    expect(vi.titleImport, equals('Nhập tệp'));
    expect(en.titleImport, equals('Import files'));
    expect(vi.titleMapping, equals('Ánh xạ cột'));
    expect(en.titleMapping, equals('Column mapping'));

    // Results & Differences
    expect(vi.resultsReadyUpper, equals('KẾT QUẢ ĐÃ SẴN SÀNG'));
    expect(en.resultsReadyUpper, equals('RESULTS READY'));
    expect(vi.differenceFingerprint, equals('BẢN ĐỒ SAI KHÁC (FINGERPRINT)'));
    expect(en.differenceFingerprint, equals('DIFFERENCE FINGERPRINT'));

    // Diagnostics
    expect(vi.semanticComparisonTitle, equals('So sánh dữ liệu'));
    expect(en.semanticComparisonTitle, equals('Data comparison'));
    expect(vi.compareAction, equals('So sánh'));
    expect(en.compareAction, equals('Compare'));
  });
}
