import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../application/workflow_controller.dart';
import '../../../design_system/design_system.dart';
import '../../../domain/workflow.dart';

/// Dytava Home, Figma 1:23. History reflects the actual in-memory session.
class HomeScreenView extends StatelessWidget {
  final WorkflowController flow;
  final bool quickProcessing;
  final VoidCallback onStartNewSession;
  final VoidCallback onQuickRun;
  final VoidCallback onResumeSession;
  final VoidCallback onCloseSession;
  final VoidCallback? onViewHistory;

  const HomeScreenView({
    super.key,
    required this.flow,
    required this.quickProcessing,
    required this.onStartNewSession,
    required this.onQuickRun,
    required this.onResumeSession,
    required this.onCloseSession,
    this.onViewHistory,
  });

  @override
  Widget build(BuildContext context) {
    final hasSession = SourceSide.values.any(
      (s) => flow.slot(s).artifact != null,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final scale = (constraints.maxWidth / 364).clamp(0.7, 1.15);
            if (MediaQuery.textScalerOf(context).scale(1) > 1.3) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'WORKSPACE / 01',
                    style: DytavaTypography.labelSmall.copyWith(
                      color: DytavaColors.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Spot the difference.',
                    style: DytavaTypography.displayLarge,
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Image.asset(
                      'assets/dytava/figma/home-workbooks.png',
                      width: 150,
                      height: 165,
                      excludeFromSemantics: true,
                    ),
                  ),
                  const Text(
                    'Two spreadsheets. One clear view.',
                    style: DytavaTypography.bodyMedium,
                  ),
                ],
              );
            }

            return SizedBox(
              height: 180 * scale,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    top: 0,
                    left: 0,
                    child: Container(
                      width: 151 * scale,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: DytavaColors.primaryLight,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        'WORKSPACE / 01',
                        style: DytavaTypography.labelSmall.copyWith(
                          fontSize: 10 * scale,
                          letterSpacing: 1.6,
                          color: DytavaColors.primaryDark,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    top: 40 * scale,
                    child: Text(
                      'Spot the\ndifference.',
                      style: DytavaTypography.displayLarge.copyWith(
                        fontSize: 32 * scale,
                        height: 34 / 32,
                        letterSpacing: -1.4,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Positioned(
                    left: -14 * scale,
                    top: 104 * scale,
                    child: Transform.rotate(
                      angle: -0.1570796,
                      child: SvgPicture.asset(
                        'assets/dytava/figma/home-underline.svg',
                        width: 180 * scale,
                        height: 5.5 * scale,
                      ),
                    ),
                  ),
                  Positioned(
                    right: -10 * scale,
                    top: -4 * scale,
                    child: SizedBox(
                      width: 155 * scale,
                      height: 170 * scale,
                      child: ClipRect(
                        child: Stack(
                          children: [
                            Positioned(
                              left: -155 * 0.1685 * scale,
                              top: -170 * 0.1492 * scale,
                              width: 155 * 1.3214 * scale,
                              height: 170 * 1.277 * scale,
                              child: Image.asset(
                                'assets/dytava/figma/home-workbooks.png',
                                fit: BoxFit.fill,
                                excludeFromSemantics: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    top: 154 * scale,
                    child: Text(
                      'Two spreadsheets. One clear view.',
                      style: DytavaTypography.bodyMedium.copyWith(
                        color: DytavaColors.textPrimary,
                        fontSize: 12 * scale,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final item in [
              ('Same', DytavaColors.white),
              ('Changed', DytavaColors.primary),
              ('Different', DytavaColors.primaryDark),
            ])
              Flexible(
                flex: MediaQuery.textScalerOf(context).scale(1) > 1.3 ? 1 : 0,
                child: SizedBox(
                  width: MediaQuery.textScalerOf(context).scale(1) > 1.3
                      ? null
                      : 58,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: item.$2,
                            border: Border.all(
                              color: item.$2 == DytavaColors.white
                                  ? DytavaColors.border
                                  : item.$2,
                            ),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          item.$1,
                          style: DytavaTypography.bodySmall.copyWith(
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            Expanded(
              child: Text(
                'A1:Z200 · 2 files',
                style: DytavaTypography.bodySmall.copyWith(fontSize: 10),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
        const Divider(height: 20),
        Row(
          children: [
            Expanded(
              child: Text(
                'Recent comparisons',
                style: DytavaTypography.titleLarge.copyWith(
                  fontSize: 19,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: onViewHistory ?? onResumeSession,
              child: const Text('View all ›', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (hasSession)
          DytavaFadeSlide(
            duration: const Duration(milliseconds: 220),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              child: ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 2,
                ),
                leading: const _WorkbookMark(),
                title: Text(
                  flow.slot(SourceSide.a).artifact?.label ?? 'Current comparison',
                  style: DytavaTypography.titleMedium.copyWith(fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  flow.resultCurrent
                      ? 'Results ready · 2 files'
                      : 'In progress · Continue setup',
                  style: DytavaTypography.bodySmall.copyWith(fontSize: 11),
                ),
                trailing: const Icon(Icons.chevron_right, size: 18),
                onTap: onResumeSession,
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
            child: Text(
              'No comparisons yet.\nYour current comparison will appear here.',
              style: DytavaTypography.bodyMedium.copyWith(fontSize: 12),
            ),
          ),
        const Divider(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: quickProcessing ? null : onQuickRun,
            child: Text(
              quickProcessing ? 'Preparing sample…' : 'Try sample comparison ›',
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }
}

class _WorkbookMark extends StatelessWidget {
  const _WorkbookMark();
  @override
  Widget build(BuildContext context) => Container(
    width: 38,
    height: 38,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: DytavaColors.primaryLight,
      borderRadius: BorderRadius.circular(10),
    ),
    child: const Text(
      'X',
      style: TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 14,
        color: DytavaColors.primary,
      ),
    ),
  );
}
