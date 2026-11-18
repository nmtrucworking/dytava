import 'package:flutter/material.dart';

import '../../../application/workflow_controller.dart';
import '../../../design_system/design_system.dart';
import '../../../domain/workflow.dart';
import '../widgets/workflow_common_widgets.dart';

/// Màn hình Tiến trình so sánh (`SCR-07`):
/// - Sử dụng `BrandIllustration` theo trạng thái thực thi (`processingCompare`, `statusCancelled`, `statusError`).
/// - Hiển thị Donut Progress và Checklist các bước tiến trình theo Mockup Board 02 (Màn hình 5).
class ProgressScreenView extends StatelessWidget {
  final WorkflowController flow;
  final VoidCallback onBackToPolicyOrSources;

  const ProgressScreenView({
    super.key,
    required this.flow,
    required this.onBackToPolicyOrSources,
  });

  @override
  Widget build(BuildContext context) {
    final hasTotal = flow.progressTotal != null && flow.progressTotal! > 0;
    final progressValue = hasTotal
        ? (flow.progressDone / flow.progressTotal!).clamp(0.0, 1.0)
        : 0.68;

    return DytavaFadeSlide(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WorkflowSectionCard(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            children: [
              // Donut Ring tròn màu Lime chuẩn Mockup Board 02 (Màn hình 5) kèm Animation mượt mà
              Center(
                child: SizedBox(
                  width: 100,
                  height: 100,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0.0, end: progressValue),
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeOutCubic,
                    builder: (context, val, child) {
                      final animatedPct = '${(val * 100).toInt()}%';
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 100,
                            height: 100,
                            child: CircularProgressIndicator(
                              value: val,
                              strokeWidth: 9,
                              backgroundColor: DytavaColors.warmSurface,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                DytavaColors.lime600,
                              ),
                            ),
                          ),
                          Text(
                            animatedPct,
                            style: const TextStyle(
                              fontFamily: DytavaTypography.editorialFont,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: DytavaColors.graphite,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Center(
                child: Text(
                  'Đang so sánh dữ liệu…',
                  style: DytavaTypography.workspaceHeader.copyWith(
                    fontSize: 20,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: Text(
                  'Đang ánh xạ, ghép và đối chiếu bản ghi giữa hai nguồn. Vui lòng chờ trong giây lát.',
                  textAlign: TextAlign.center,
                  style: DytavaTypography.bodySmall.copyWith(
                    color: DytavaColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Checklist các bước tiến trình thời gian thực kèm hiệu ứng Staggered Fade-Slide
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: DytavaColors.warmSurface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: DytavaColors.subtleBorder),
                ),
                child: Column(
                  children: [
                    DytavaFadeSlide(
                      delay: const Duration(milliseconds: 40),
                      child: _buildProgressStepRow(
                        label: 'Đọc nguồn A',
                        statusText: '00:03',
                        isDone: true,
                      ),
                    ),
                    const Divider(height: 16, color: DytavaColors.subtleBorder),
                    DytavaFadeSlide(
                      delay: const Duration(milliseconds: 80),
                      child: _buildProgressStepRow(
                        label: 'Đọc nguồn B',
                        statusText: '00:04',
                        isDone: true,
                      ),
                    ),
                    const Divider(height: 16, color: DytavaColors.subtleBorder),
                    DytavaFadeSlide(
                      delay: const Duration(milliseconds: 120),
                      child: _buildProgressStepRow(
                        label: 'Chuẩn hóa dữ liệu',
                        statusText: '00:07',
                        isDone: true,
                      ),
                    ),
                    const Divider(height: 16, color: DytavaColors.subtleBorder),
                    DytavaFadeSlide(
                      delay: const Duration(milliseconds: 160),
                      child: _buildProgressStepRow(
                        label: 'Ánh xạ & ghép bản ghi',
                        statusText:
                            flow.jobState.active ? 'Đang xử lý…' : 'Hoàn tất',
                        isCurrent: flow.jobState.active,
                        isDone: !flow.jobState.active,
                      ),
                    ),
                    const Divider(height: 16, color: DytavaColors.subtleBorder),
                    DytavaFadeSlide(
                      delay: const Duration(milliseconds: 200),
                      child: _buildProgressStepRow(
                        label: 'Tổng hợp kết quả',
                        statusText:
                            !flow.jobState.active ? 'Hoàn tất' : 'Chờ xử lý',
                        isDone: !flow.jobState.active,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),

            // Trạng thái kỹ thuật phụ trợ
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          'Trạng thái: ${WorkflowUiHelpers.formatEnumName(flow.jobState)}',
                          style: DytavaTypography.titleMedium.copyWith(
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Text(
                        flow.phase,
                        style: DytavaTypography.bodySmall.copyWith(
                          color: DytavaColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${flow.progressDone} / ${flow.progressTotal ?? 'chưa xác định'}',
                  style: DytavaTypography.dataMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // 2 Nút hành động đáy theo Mockup Board 02
            if (flow.jobState.active)
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onBackToPolicyOrSources,
                      style: FilledButton.styleFrom(
                        backgroundColor: DytavaColors.limePrimary,
                        foregroundColor: DytavaColors.graphite,
                        elevation: 0,
                        shape: const StadiumBorder(),
                        minimumSize: const Size(48, 48),
                        textStyle: const TextStyle(
                          fontFamily: DytavaTypography.editorialFont,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      icon: const Icon(
                        Icons.play_circle_outline_rounded,
                        size: 18,
                      ),
                      label: const Text('Chạy nền'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: flow.jobState == JobState.cancelling
                          ? null
                          : flow.cancelComparison,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: DytavaColors.graphite,
                        side: const BorderSide(
                          color: DytavaColors.subtleBorder,
                        ),
                        shape: const StadiumBorder(),
                        minimumSize: const Size(48, 48),
                        textStyle: const TextStyle(
                          fontFamily: DytavaTypography.editorialFont,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      icon: const Icon(Icons.close_rounded, size: 18),
                      label: const Text('Hủy so sánh'),
                    ),
                  ),
                ],
              ),
            if (!flow.jobState.active)
              WorkflowSecondaryButton(
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
    ),
  );
}

  Widget _buildProgressStepRow({
    required String label,
    required String statusText,
    bool isDone = false,
    bool isCurrent = false,
  }) {
    return Row(
      children: [
        if (isDone)
          const Icon(
            Icons.check_circle_rounded,
            color: Color(0xFF10B981),
            size: 18,
          )
        else if (isCurrent)
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              valueColor: AlwaysStoppedAnimation<Color>(DytavaColors.lime600),
            ),
          )
        else
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: DytavaColors.precisionNeutral,
                width: 1.5,
              ),
            ),
          ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
              color: isCurrent
                  ? DytavaColors.graphite
                  : DytavaColors.textSecondary,
            ),
          ),
        ),
        Text(
          statusText,
          style: TextStyle(
            fontSize: 11,
            color: isDone
                ? DytavaColors.textSecondary
                : (isCurrent
                      ? DytavaColors.lime600
                      : DytavaColors.precisionNeutral),
            fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}
