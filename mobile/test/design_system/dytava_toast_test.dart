import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dytava/design_system/dytava_toast.dart';

void main() {
  testWidgets('DytavaToast renders top push notification correctly', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                DytavaToast.success(
                  context,
                  'Tệp đối soát đã sẵn sàng',
                  title: 'Thành công',
                );
              },
              child: const Text('Show Toast'),
            ),
          ),
        ),
      ),
    );

    // Tap to show toast
    await tester.tap(find.text('Show Toast'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350)); // animation finished

    // Check that title and message are visible in the top notification
    expect(find.text('Thành công'), findsOneWidget);
    expect(find.text('Tệp đối soát đã sẵn sàng'), findsOneWidget);

    // Verify it is positioned near top of screen
    final toastFinder = find.byKey(const ValueKey('dytava_top_toast'));
    expect(toastFinder, findsOneWidget);
    final topOffset = tester.getTopLeft(toastFinder).dy;
    expect(topOffset, lessThan(100)); // Anchored near top of screen

    // Dismiss manually
    DytavaToast.dismiss();
    await tester.pump();
    expect(find.text('Thành công'), findsNothing);
  });

  testWidgets('DytavaToast error and dismiss via close button works', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                DytavaToast.error(
                  context,
                  'Định dạng không được hỗ trợ',
                  title: 'Lỗi',
                );
              },
              child: const Text('Show Error'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show Error'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Lỗi'), findsOneWidget);
    expect(find.text('Định dạng không được hỗ trợ'), findsOneWidget);

    // Tap close button
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Lỗi'), findsNothing);
  });
}
