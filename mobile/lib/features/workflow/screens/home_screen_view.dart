import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../application/workflow_controller.dart';
import '../../../design_system/design_system.dart';
import '../../../domain/workflow.dart';
import '../../../l10n/app_localizations.dart';

/// Dytava Home, Figma 1:23. History reflects the actual in-memory session.
class HomeScreenView extends StatelessWidget {
  final WorkflowController flow;
  final bool quickProcessing;
  final VoidCallback onStartNewSession;
  final VoidCallback onResumeSession;
  final VoidCallback onCloseSession;
  final VoidCallback? onViewHistory;

  const HomeScreenView({
    super.key,
    required this.flow,
    required this.quickProcessing,
    required this.onStartNewSession,
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
        DytavaFadeSlide.staggered(
          index: 0,
          child: LayoutBuilder(
            builder: (context, constraints) {
            final scale = (constraints.maxWidth / 364).clamp(0.7, 1.15);
            if (MediaQuery.textScalerOf(context).scale(1) > 1.3) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.compareWithClarity,
                    style: DytavaTypography.labelSmall.copyWith(
                      color: DytavaColors.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    context.l10n.spotTheDifferenceInline,
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
                  Text(
                    context.l10n.appTagline,
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
                      padding: EdgeInsets.symmetric(
                        horizontal: 10 * scale,
                        vertical: 3.5 * scale,
                      ),
                      decoration: BoxDecoration(
                        color: DytavaColors.primaryLight,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        context.l10n.compareWithClarity,
                        style: DytavaTypography.labelSmall.copyWith(
                          fontSize: 9.5 * scale,
                          letterSpacing: 0.8,
                          fontWeight: FontWeight.w700,
                          color: DytavaColors.primaryDark,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    top: 40 * scale,
                    child: Text(
                      context.l10n.spotTheDifference,
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
                      context.l10n.appTagline,
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
        ),
        const SizedBox(height: 10),
        const Divider(height: 20),
        DytavaFadeSlide.staggered(
          index: 1,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  context.l10n.recentComparisons,
                  style: DytavaTypography.titleLarge.copyWith(
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: onViewHistory ?? onResumeSession,
                child: Text(
                  context.l10n.viewAll,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        if (hasSession) ...[
          DytavaFadeSlide.staggered(
            index: 2,
            child: _buildSessionCard(
              title:
                  flow.slot(SourceSide.a).artifact?.label ??
                  context.l10n.spreadsheetComparison,
              subtitle: flow.resultCurrent
                  ? context.l10n.completedWorkbooks(2)
                  : context.l10n.inProgressWorkbooks(2),
              onTap: onResumeSession,
            ),
          ),
          if (flow.lastSavedSession != null)
            DytavaFadeSlide.staggered(
              index: 3,
              child: _buildSessionCard(
                title: flow.lastSavedSession!.labelA.isNotEmpty
                    ? flow.lastSavedSession!.labelA
                    : context.l10n.savedComparison,
                subtitle: context.l10n.cellsAndDiffs(
                  flow.lastSavedSession!.totalCells,
                  flow.lastSavedSession!.differentCount,
                ),
                onTap: () async {
                  await flow.restoreSavedSession(
                    flow.lastSavedSession!.sessionId,
                  );
                  onResumeSession();
                },
              ),
            ),
        ] else if (flow.lastSavedSession != null) ...[
          DytavaFadeSlide.staggered(
            index: 2,
            child: _buildSessionCard(
              title: flow.lastSavedSession!.labelA.isNotEmpty
                  ? flow.lastSavedSession!.labelA
                  : context.l10n.savedComparison,
              subtitle: context.l10n.cellsAndDiffs(
                flow.lastSavedSession!.totalCells,
                flow.lastSavedSession!.differentCount,
              ),
              onTap: () async {
                await flow.restoreSavedSession(
                  flow.lastSavedSession!.sessionId,
                );
                onResumeSession();
              },
            ),
          ),
        ] else ...[
          DytavaFadeSlide.staggered(
            index: 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
              child: Text(
                context.l10n.noComparisonsHomeHint,
                style: DytavaTypography.bodyMedium.copyWith(fontSize: 12),
              ),
            ),
          ),
        ],
      ],
    );
  }
  Widget _buildSessionCard({
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          const _WorkbookMark(),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFF6FAF7),
                    Color(0xFFE4F2E9),
                    Color(0xFFBDE0C9),
                  ],
                  stops: [0.0, 0.55, 1.0],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: onTap,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(
                                  fontFamily: DytavaTypography.primaryFont,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1E293B),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.calendar_today_outlined,
                                    size: 11.5,
                                    color: Color(0xFF64748B),
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      subtitle,
                                      style: const TextStyle(
                                        fontFamily: DytavaTypography.primaryFont,
                                        fontSize: 11.5,
                                        color: Color(0xFF64748B),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: Color(0xFF1E293B),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkbookMark extends StatelessWidget {
  const _WorkbookMark();
  @override
  Widget build(BuildContext context) => Container(
    width: 36,
    height: 36,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: const Color(0xFFE1F2E8),
      borderRadius: BorderRadius.circular(10),
    ),
    child: const Text(
      'X',
      style: TextStyle(
        fontFamily: DytavaTypography.primaryFont,
        fontWeight: FontWeight.w800,
        fontSize: 14,
        color: DytavaColors.primary,
      ),
    ),
  );
}
