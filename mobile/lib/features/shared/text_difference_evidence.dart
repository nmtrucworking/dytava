import 'package:flutter/material.dart';

import '../../design_system/design_system.dart';
import '../../domain/text_difference.dart';

/// A lazy, small-text diagnostic aid; not the production streaming highlighter.
class TextDifferenceEvidence extends StatelessWidget {
  const TextDifferenceEvidence({super.key, required this.a, required this.b});
  final String a;
  final String b;
  static const maxCodeUnits = 8192;

  Widget _side(TextDifference difference, String label, String part) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: SelectableText.rich(
      TextSpan(
        style: DytavaTypography.dataMedium,
        children: [
          TextSpan(
            text: '$label: ${TextDifference.visibleText(difference.prefix)}',
          ),
          TextSpan(
            text: '⟦${part.isEmpty ? '∅' : TextDifference.visibleText(part)}⟧',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              backgroundColor: DytavaColors.differentBg,
            ),
          ),
          TextSpan(text: TextDifference.visibleText(difference.suffix)),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (a.length > maxCodeUnits || b.length > maxCodeUnits) {
      return const Text(
        'Không tô vùng khác biệt: chuỗi vượt giới hạn hiển thị của màn hình thử nghiệm. Kết luận so sánh được giữ nguyên.',
      );
    }
    final difference = TextDifference.between(a, b);
    if (difference == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        const Text(
          'Khác biệt trong chuỗi',
          style: DytavaTypography.titleMedium,
        ),
        Text(difference.description),
        const Text(
          'Vị trí tính trên chuỗi sau chuẩn hóa; vùng khác nằm trong ⟦ ⟧.',
        ),
        _side(difference, 'A', difference.partA),
        _side(difference, 'B', difference.partB),
        const Text(
          '␠ dấu cách · ⇥ tab · ↵ xuống dòng · ␍ về đầu dòng · '
          '⍽ dấu cách không ngắt · ∅ đoạn trống',
        ),
      ],
    );
  }
}
