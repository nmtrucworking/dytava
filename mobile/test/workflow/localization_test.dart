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

    // Before opening popover, more icon rotation is 0 degrees (turns == 0.0)
    final rotationBefore = tester.widget<AnimatedRotation>(
      find.descendant(
        of: find.byKey(const ValueKey('more-popover-trigger')),
        matching: find.byType(AnimatedRotation),
      ),
    );
    expect(rotationBefore.turns, equals(0.0));

    // Open More popover
    await tester.tap(find.byKey(const ValueKey('more-popover-trigger')));
    await tester.pumpAndSettle();

    // While popover is open, more icon rotation is 45 degrees (turns == 0.125)
    final rotationOpen = tester.widget<AnimatedRotation>(
      find.descendant(
        of: find.byKey(const ValueKey('more-popover-trigger')),
        matching: find.byType(AnimatedRotation),
      ),
    );
    expect(rotationOpen.turns, equals(0.125));

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

    // After closing popover, more icon rotation returns to 0 degrees
    final rotationAfter = tester.widget<AnimatedRotation>(
      find.descendant(
        of: find.byKey(const ValueKey('more-popover-trigger')),
        matching: find.byType(AnimatedRotation),
      ),
    );
    expect(rotationAfter.turns, equals(0.0));
  });

  testWidgets('App Settings loads dynamic local storage and all tiles are interactive', (
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

    // Open App Settings
    await tester.tap(find.byTooltip('Comparison settings'));
    await tester.pumpAndSettle();

    expect(find.text('Dytava'), findsWidgets);
    expect(find.text('Excel Compare · v0.1.0'), findsOneWidget);
    expect(find.text('Help & support'), findsOneWidget);
    expect(find.text('Quick'), findsOneWidget);
    expect(find.byKey(const ValueKey('settings-local-storage-value')), findsOneWidget);
    expect(find.byKey(const ValueKey('settings-language-en')), findsOneWidget);
    expect(find.byKey(const ValueKey('settings-language-vi')), findsOneWidget);

    // 1. Tap Help & support -> opens interactive guide sheet
    await tester.tap(find.byKey(const ValueKey('settings-help-support-button')));
    await tester.pumpAndSettle();
    expect(find.text('Done'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    // 2. Tap Compare mode tile -> opens mode selector sheet
    await tester.tap(find.byKey(const ValueKey('settings-compare-mode-tile')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('By key column'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save settings'));
    await tester.pumpAndSettle();
    expect(find.text('By Key'), findsOneWidget);

    // 3. Tap Local storage tile -> opens storage details & clear sheet
    final localStorageTile = find.byKey(const ValueKey('settings-local-storage-tile'));
    await tester.ensureVisible(localStorageTile);
    await tester.pumpAndSettle();
    await tester.tap(localStorageTile);
    await tester.pumpAndSettle();
    expect(find.text('Used storage'), findsOneWidget);
    expect(find.text('Saved comparisons'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    // 4. Tap Privacy tile -> opens privacy details sheet
    final privacyTile = find.byKey(const ValueKey('settings-privacy-tile'));
    await tester.ensureVisible(privacyTile);
    await tester.pumpAndSettle();
    await tester.tap(privacyTile);
    await tester.pumpAndSettle();
    expect(find.text('Done'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    // 5. Switch language in App Settings
    final viLangBtn = find.byKey(const ValueKey('settings-language-vi'));
    await tester.ensureVisible(viLangBtn);
    await tester.pumpAndSettle();
    await tester.tap(viLangBtn);
    await tester.pumpAndSettle();
    expect(flow.locale.languageCode, equals('vi'));
    expect(find.text('NGÔN NGỮ'), findsOneWidget);
    expect(find.text('ĐỐI SOÁT'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('settings-language-en')));
    await tester.pumpAndSettle();
    expect(flow.locale.languageCode, equals('en'));

    // 6. Open Rule Presets page and verify mobile-first cards & selection
    final presetsTile = find.byKey(const ValueKey('settings-rule-presets-tile'));
    await tester.ensureVisible(presetsTile);
    await tester.pumpAndSettle();
    await tester.tap(presetsTile);
    await tester.pumpAndSettle();
    expect(find.text('COMPARISON RULE PRESETS'), findsOneWidget);
    expect(find.text('AVAILABLE PRESETS'), findsOneWidget);
    expect(find.byKey(const ValueKey('preset-card-financial-reconcile-v1')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('preset-card-financial-reconcile-v1')));
    await tester.pumpAndSettle();
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
