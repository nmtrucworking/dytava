import 'package:flutter/material.dart';

import '../../../application/workflow_controller.dart';
import '../../../design_system/design_system.dart';
import '../../../domain/workflow.dart';
import '../widgets/workflow_common_widgets.dart';

/// Màn hình Tiến trình so sánh (`SCR-07`):
/// - Sử dụng `BrandIllustration` theo trạng thái thực thi (`processingCompare`, `statusCancelled`, `statusError`).
/// - Luôn đi kèm chỉ báo tiến trình thực (`LinearProgressIndicator`), không thay bằng animation trang trí.
class ProgressScreenView extends StatelessWidget {
  final WorkflowController flow;
  final VoidCallback onBackToPolicyOrSources;

  const ProgressScreenView({
    super.key,
    required this.flow,
    required this.onBackToPolicyOrSources,
  });

  String _stateIllustration() {
    if (flow.jobState == JobState.cancelled) {
      return DytavaIllustrations.statusCancelled;
    }
    if (flow.jobState == JobState.failed) {
      return DytavaIllustrations.statusError;
    }
    return DytavaIllustrations.processingCompare;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WorkflowSectionCard(
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: BrandIllustration.processing(
                asset: _stateIllustration(),
                size: 84,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (flow.jobState.active) ...[
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                  const SizedBox(width: 14),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          'Trạng thái: ${WorkflowUiHelpers.formatEnumName(flow.jobState)}',
                          style: DytavaTypography.titleMedium,
                        ),
                      ),
                      Text(
                        flow.phase,
                        style: DytavaTypography.bodySmall.copyWith(
                          color: DytavaColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (flow.jobState.active)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: flow.progressTotal != null && flow.progressTotal! > 0
                      ? flow.progressDone / flow.progressTotal!
                      : null,
                  minHeight: 8,
                  backgroundColor: DytavaColors.border,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    DytavaColors.primary,
                  ),
                ),
              ),
            const SizedBox(height: 10),
            Center(
              child: Text(
                '${flow.progressDone} / ${flow.progressTotal ?? 'chưa xác định'}',
                style: DytavaTypography.dataMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (flow.jobState.active)
              WorkflowPrimaryButton(
                label: 'Hủy so sánh',
                iconAsset: DytavaIcons.cancel,
                onPressed: flow.jobState == JobState.cancelling
                    ? null
                    : flow.cancelComparison,
              ),
            if (!flow.jobState.active)
              WorkflowPrimaryButton(
                label: flow.inputsReady ? 'Trở lại cấu hình' : 'Về nguồn A/B',
                iconAsset: DytavaIcons.back,
                onPressed: onBackToPolicyOrSources,
              ),
            if (flow.jobState == JobState.failed ||
                flow.jobState == JobState.cancelled) ...[
              const SizedBox(height: 8),
              WorkflowPrimaryButton(
                label: 'Thử lại so sánh',
                iconAsset: DytavaIcons.refresh,
                onPressed: flow.startBlockers.isEmpty
                    ? flow.runComparison
                    : null,
              ),
            ],
          ],
        ),
      ],
    );
  }
}
