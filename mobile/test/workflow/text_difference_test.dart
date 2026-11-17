import 'package:dytava/domain/text_difference.dart';
import 'package:dytava/features/shared/text_difference_evidence.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reported name pair identifies missing internal space at Unicode position 11', () {
    final delta = TextDifference.between('nguyen van a', 'nguyen vana')!;
    expect(delta.position, 11);
    expect(delta.prefix, 'nguyen van');
    expect(delta.partA, ' ');
    expect(delta.partB, '');
    expect(delta.suffix, 'a');
    expect(delta.description, contains('dấu cách (U+0020)'));
    expect(delta.description, contains('không có ký tự (∅)'));
    expect('${delta.prefix}${delta.partA}${delta.suffix}', 'nguyen van a');
    expect('${delta.prefix}${delta.partB}${delta.suffix}', 'nguyen vana');
  });
  test('prefix insertions, suffix deletions, replacements and equality', () {
    expect(TextDifference.between('abc', 'abc'), isNull);
    final beginning = TextDifference.between('abc', 'xabc')!;
    expect(beginning.position, 1);
    expect(beginning.partA, '');
    expect(beginning.partB, 'x');
    final ending = TextDifference.between('abc', 'ab')!;
    expect(ending.position, 3);
    expect(ending.partA, 'c');
    expect(ending.partB, '');
    final accent = TextDifference.between('Nguyen', 'Nguyễn')!;
    expect(accent.partA, 'e');
    expect(accent.partB, 'ễ');
    expect(TextDifference.between('', ''), isNull);
  });
  test('Unicode scalar offsets never split emoji or conflate Unicode normalization', () {
    final delta = TextDifference.between('😀 a', '😀a')!;
    expect(delta.position, 2);
    expect(delta.prefix, '😀');
    expect(delta.partA, ' ');
    expect(TextDifference.between('é', 'e\u0301'), isNotNull);
  });
  test(
    'whitespace display preserves the distinction between space, tab and NBSP',
    () {
      expect(TextDifference.visibleText('a b\t\n\r\u00a0'), 'a␠b⇥↵␍⍽');
      expect(
        TextDifference.visibleText(String.fromCharCodes([32, 9, 10, 13, 160])),
        '␠⇥↵␍⍽',
      );
      expect(
        TextDifference.between(String.fromCharCode(9), '')!.description,
        contains('tab (U+0009)'),
      );
    },
  );
  testWidgets(
    'oversized text omits highlight explicitly while keeping result responsibility separate',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextDifferenceEvidence(
              a: 'a' * (TextDifferenceEvidence.maxCodeUnits + 1),
              b: 'b',
            ),
          ),
        ),
      );
      expect(find.textContaining('vượt giới hạn hiển thị'), findsOneWidget);
      expect(find.text('Khác biệt trong chuỗi'), findsNothing);
    },
  );
}
