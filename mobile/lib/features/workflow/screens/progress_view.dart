import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../application/workflow_controller.dart';
import '../../../design_system/design_system.dart';
import '../../../domain/workflow.dart';
import '../widgets/workflow_common_widgets.dart';

class ProgressScreenView extends StatefulWidget {
  final WorkflowController flow;
  final VoidCallback onBackToPolicyOrSources;
  const ProgressScreenView({
    super.key,
    required this.flow,
    required this.onBackToPolicyOrSources,
  });
  @override
  State<ProgressScreenView> createState() => _ProgressScreenViewState();
}

class _ProgressScreenViewState extends State<ProgressScreenView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _timeline = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _timeline.stop();
      _timeline.value = 1;
    } else if (!_timeline.isAnimating) {
      _timeline.repeat();
    }
  }

  @override
  void dispose() {
    _timeline.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final flow = widget.flow;
    final hasTotal = flow.progressTotal != null && flow.progressTotal! > 0;
    final value = hasTotal
        ? (flow.progressDone / flow.progressTotal!).clamp(0.0, 1.0)
        : null;
    final active = flow.jobState.active;
    final validating = flow.jobState == JobState.validating;
    return AnimatedBuilder(
      animation: _timeline,
      builder: (context, _) {
        final t = _timeline.value;
        final entrance = Curves.easeOut.transform((t / 0.07).clamp(0.0, 1.0));
        return WorkflowScreenLayout(
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),
              Center(
                child: Opacity(
                  opacity: entrance,
                  child: Transform.scale(
                          scale: 0.96 + entrance * 0.04,
                          child: SizedBox(
                            width: 160,
                    height: 160,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SvgPicture.asset(
                          'assets/dytava/figma/progress-track.svg',
                          width: 160,
                          height: 160,
                        ),
                        Transform.rotate(
                          angle:
                              active && !MediaQuery.disableAnimationsOf(context)
                              ? t * math.pi
                              : 0,
                          child: SizedBox(
                            width: 150,
                            height: 150,
                            child: CircularProgressIndicator(
                              value: value,
                              strokeWidth: 10,
                              color: DytavaColors.primary,
                              backgroundColor: Colors.transparent,
                            ),
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              value == null ? '…' : '${(value * 100).round()}%',
                              style: DytavaTypography.displayLarge.copyWith(
                                fontSize: 38,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              active
                                  ? 'IN PROGRESS'
                                  : flow.jobState.name.toUpperCase(),
                              style: DytavaTypography.labelSmall.copyWith(
                                color: DytavaColors.primary,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              flow.jobState == JobState.failed
                  ? 'Comparison failed'
                  : flow.jobState == JobState.cancelled
                  ? 'Comparison cancelled'
                  : 'Comparing your data',
              textAlign: TextAlign.center,
              style: DytavaTypography.displayMedium,
            ),
            const SizedBox(height: 10),
            const Text(
              'Matching sheets, columns, keys and values.',
              textAlign: TextAlign.center,
              style: DytavaTypography.bodyMedium,
            ),
            const SizedBox(height: 30),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Checking sheets and records',
                    style: DytavaTypography.bodySmall,
                  ),
                ),
                Text(
                  value == null ? 'Working…' : '${(value * 100).round()}%',
                  style: DytavaTypography.bodySmall.copyWith(
                    color: DytavaColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: value,
              minHeight: 7,
              borderRadius: BorderRadius.circular(4),
              color: DytavaColors.primary,
              backgroundColor: DytavaColors.primaryLight,
            ),
            const SizedBox(height: 26),
            _reveal(
              t,
              0.02,
              0.09,
              WorkflowSectionCard(
                children: [
                  for (final side in SourceSide.values) ...[
                    if (side == SourceSide.b)
                      const Divider(indent: 42, height: 18),
                    Row(
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: DytavaColors.primaryLight,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Text(
                            side.name.toUpperCase(),
                            style: const TextStyle(
                              color: DytavaColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            flow.slot(side).artifact?.label ??
                                'File ${side.name.toUpperCase()}',
                            style: DytavaTypography.bodyMedium.copyWith(
                              color: DytavaColors.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            _reveal(
              t,
              0.035,
              0.105,
              Column(
                children: [
                  _stage(
                    1,
                    'Read and validate files',
                    'Source workbooks recognized',
                    !validating,
                    validating,
                  ),
                  _stage(
                    2,
                    'Match and compare records',
                    'Checking structure and cell values',
                    flow.jobState == JobState.completed,
                    !validating && active,
                  ),
                  _stage(
                    3,
                    'Prepare results',
                    flow.jobState == JobState.completed ? 'Ready' : 'Up next',
                    flow.jobState == JobState.completed,
                    false,
                  ),
                ],
              ),
            ),
                    const SizedBox(height: 16),
                  ],
                ),
                bottomBar: StickyBottomBar(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (active)
                        OutlinedButton(
                          onPressed: flow.jobState == JobState.cancelling
                              ? null
                              : flow.cancelComparison,
                          child: Text(
                            flow.jobState == JobState.cancelling
                                ? 'Cancelling…'
                                : 'Cancel comparison',
                          ),
                        )
                      else
                        WorkflowPrimaryButton(
                          label: 'Back to setup',
                          onPressed: widget.onBackToPolicyOrSources,
                        ),
                      if (flow.jobState == JobState.failed ||
                          flow.jobState == JobState.cancelled)
                        TextButton(
                          onPressed: flow.startBlockers.isEmpty
                              ? flow.runComparison
                              : null,
                          child: const Text('Try again'),
                        ),
                    ],
                  ),
                ),
              );
      },
    );
  }

  Widget _reveal(double t, double start, double end, Widget child) {
    final v = Curves.easeOut.transform(
      ((t - start) / (end - start)).clamp(0.0, 1.0),
    );
    return Opacity(
      opacity: v,
      child: Transform.translate(offset: Offset(0, 8 * (1 - v)), child: child),
    );
  }

  Widget _stage(
    int number,
    String title,
    String subtitle,
    bool done,
    bool current,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (done)
          SvgPicture.asset(
            'assets/dytava/figma/progress-read.svg',
            width: 24,
            height: 24,
          )
        else if (number == 3)
          SvgPicture.asset(
            'assets/dytava/figma/progress-report.svg',
            width: 24,
            height: 24,
          )
        else
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: current ? DytavaColors.primary : DytavaColors.primaryLight,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              style: TextStyle(
                color: current ? Colors.white : DytavaColors.textPrimary,
                fontSize: 12,
              ),
            ),
          ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: DytavaTypography.bodyMedium.copyWith(
                  color: current || done
                      ? DytavaColors.textPrimary
                      : DytavaColors.textSecondary,
                  fontWeight: current ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: DytavaTypography.bodySmall.copyWith(fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
