import 'package:flutter/material.dart';

import '../../design_system/design_system.dart';
import '../../domain/text_difference.dart';
import '../../domain/word_difference.dart';
import '../../l10n/app_localizations.dart';

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
      return Text(
        context.l10n.textDiffExceedsLimit,
      );
    }
    final words = WordDifference.between(a, b);
    final difference = TextDifference.between(a, b);
    if (difference == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (words.similarity != null)
          Text(context.l10n.similarityRatio(words.similarity.toString())),
        for (final side in [(words.a, 'A'), (words.b, 'B')])
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: SelectableText.rich(
              TextSpan(
                style: DytavaTypography.dataMedium,
                children: [
                  TextSpan(text: '${side.$2}: '),
                  for (final token in side.$1)
                    TextSpan(
                      text: token.text,
                      style: token.changed
                          ? const TextStyle(
                              backgroundColor: DytavaColors.differentBg,
                              fontWeight: FontWeight.bold,
                            )
                          : null,
                    ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 12),
        Text(
          context.l10n.differenceInString,
          style: DytavaTypography.titleMedium,
        ),
        Text(difference.localizedDescription(context.l10n.isVietnamese)),
        Text(
          context.l10n.diffPositionNote,
        ),
        _side(difference, 'A', difference.partA),
        _side(difference, 'B', difference.partB),
        Text(
          context.l10n.diffLegend,
        ),
      ],
    );
  }
}
