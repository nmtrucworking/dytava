import 'package:excelcompare_core/excelcompare_core.dart';
import 'package:flutter/material.dart';

import '../../../application/workflow_controller.dart';
import '../../../design_system/design_system.dart';
import '../../../domain/workflow.dart';

/// SCR-01: mobile-first entry point.
///
/// Show one clear primary action and distinguish the fixture-only demo from
/// production file import. Keep current-session recovery ahead of new work.
class HomeScreenView extends StatelessWidget {
  final WorkflowController flow;
  final bool quickProcessing;
  final VoidCallback onStartNewSession;
  final VoidCallback onQuickRun;
  final VoidCallback onResumeSession;
  final VoidCallback onCloseSession;

  const HomeScreenView({
    super.key,
    required this.flow,
    required this.quickProcessing,
    required this.onStartNewSession,
    required this.onQuickRun,
    required this.onResumeSession,
    required this.onCloseSession,
  });

  bool get _hasActiveSession =>
      flow.slot(SourceSide.a).artifact != null ||
      flow.slot(SourceSide.b).artifact != null ||
      flow.resultCurrent;

  String _sessionStageLabel() {
    if (flow.resultCurrent) {
      return 'Bước 4/4 · Đã hoàn tất đối chiếu';
    }
    if (flow.inputsReady) {
      return flow.config.mappingConfirmed
          ? 'Bước 2/4 · Sẵn sàng xác nhận quy tắc & chạy'
          : 'Bước 2/4 · Đang chờ ghép cột A ↔ B';
    }
    return 'Bước 1/4 · Đang chuẩn bị Nguồn A & Nguồn B';
  }

  String _sessionSourceSummary() {
    final labelA = flow.slot(SourceSide.a).artifact?.label ?? 'Chưa chọn A';
    final labelB = flow.slot(SourceSide.b).artifact?.label ?? 'Chưa chọn B';
    if (flow.resultCurrent && flow.result != null) {
      final diffCount = flow.result!.count(DecisionStatus.different);
      final unresolvedCount = flow.result!.count(DecisionStatus.unresolved);
      return '$labelA ↔ $labelB · $diffCount ô khác biệt · $unresolvedCount ô chưa kết luận';
    }
    return 'Nguồn A: $labelA · Nguồn B: $labelB';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 4, 4, 0),
          child: _HomeHeading(),
        ),
        const SizedBox(height: 20),
        if (_hasActiveSession) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text(
              'Tiếp tục phiên của bạn',
              style: DytavaTypography.titleMedium.copyWith(
                fontSize: 16,
              ),
            ),
          ),
          DytavaSessionResumeCard(
            stageLabel: _sessionStageLabel(),
            sourceSummary: _sessionSourceSummary(),
            hasCompletedResult: flow.resultCurrent,
            onResume: onResumeSession,
            onCloseSession: flow.usable ? onCloseSession : null,
          ),
          if (flow.resultCurrent && flow.result != null) ...[
            const SizedBox(height: 12),
            DytavaResultCard(
              fileA: flow.slot(SourceSide.a).artifact?.label ?? 'Sheet A',
              fileB: flow.slot(SourceSide.b).artifact?.label ?? 'Sheet B',
              totalPairs: flow.result!.cells.length,
              equivalentCount: flow.result!.count(DecisionStatus.equivalent),
              differentCount: flow.result!.count(DecisionStatus.different),
              unresolvedCount: flow.result!.count(DecisionStatus.unresolved),
              onTap: onResumeSession,
            ),
          ],
          const SizedBox(height: 20),
        ],
        _StartComparisonPanel(
          hasActiveSession: _hasActiveSession,
          quickProcessing: quickProcessing,
          onStartNewSession: onStartNewSession,
          onQuickRun: onQuickRun,
        ),
        const SizedBox(height: 16),
        const _PrivacyNotice(),
        const SizedBox(height: 12),
        const _WorkflowSteps(),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _HomeHeading extends StatelessWidget {
  const _HomeHeading();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ĐỐI CHIẾU DỮ LIỆU',
          style: DytavaTypography.labelSmall.copyWith(
            color: DytavaColors.primary,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.3,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Nhìn rõ từng sai khác.',
          style: DytavaTypography.displayMedium.copyWith(
            fontSize: 27,
            height: 1.19,
            letterSpacing: -0.65,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Đối chiếu hai nguồn bảng tính và truy vết kết quả đến từng giá trị.',
          style: DytavaTypography.bodyLarge.copyWith(
            color: DytavaColors.textSecondary,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

class _StartComparisonPanel extends StatelessWidget {
  final bool hasActiveSession;
  final bool quickProcessing;
  final VoidCallback onStartNewSession;
  final VoidCallback onQuickRun;

  const _StartComparisonPanel({
    required this.hasActiveSession,
    required this.quickProcessing,
    required this.onStartNewSession,
    required this.onQuickRun,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: DytavaColors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: DytavaColors.border),
        boxShadow: [
          BoxShadow(
            color: DytavaColors.darkNavy.withValues(alpha: 0.035),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  hasActiveSession ? 'SO SÁNH KHÁC' : 'PHIÊN SO SÁNH MỚI',
                  style: DytavaTypography.labelSmall.copyWith(
                    color: DytavaColors.textSecondary,
                    letterSpacing: 0.9,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: DytavaColors.softAmber,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  'Bản demo',
                  style: DytavaTypography.labelSmall.copyWith(
                    color: const Color(0xFF92400E),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Row(
            children: [
              Expanded(
                child: _SourceTile(
                  tag: 'A',
                  title: 'Bảng tham chiếu',
                  icon: Icons.description_outlined,
                  accentColor: DytavaColors.primary,
                  backgroundColor: DytavaColors.softBlue,
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 7),
                child: Icon(
                  Icons.sync_alt_rounded,
                  size: 22,
                  color: DytavaColors.textSecondary,
                ),
              ),
              Expanded(
                child: _SourceTile(
                  tag: 'B',
                  title: 'Bảng đối chiếu',
                  icon: Icons.table_chart_outlined,
                  accentColor: Color(0xFF047857),
                  backgroundColor: DytavaColors.softGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onStartNewSession,
              icon: const Icon(Icons.add_rounded, size: 22),
              label: const Text('Bắt đầu so sánh'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: DytavaTypography.labelLarge.copyWith(
                  fontSize: 15,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: quickProcessing ? null : onQuickRun,
              icon: quickProcessing
                  ? const SizedBox(
                      height: 17,
                      width: 17,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.play_circle_outline_rounded, size: 21),
              label: Text(
                quickProcessing
                    ? 'Đang chạy dữ liệu mẫu…'
                    : 'Chạy thử tự động bằng dữ liệu mẫu',
              ),
              style: TextButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
                foregroundColor: DytavaColors.primary,
                textStyle: DytavaTypography.labelLarge,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Chức năng chọn tệp thật chưa được tích hợp ở bản hiện tại.',
            textAlign: TextAlign.center,
            style: DytavaTypography.bodySmall.copyWith(
              color: DytavaColors.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  final String tag;
  final String title;
  final IconData icon;
  final Color accentColor;
  final Color backgroundColor;

  const _SourceTile({
    required this.tag,
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 114),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 27, color: accentColor),
          const SizedBox(height: 11),
          Text(
            'NGUỒN $tag',
            style: DytavaTypography.labelSmall.copyWith(
              color: accentColor,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: DytavaTypography.bodySmall.copyWith(
              color: DytavaColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivacyNotice extends StatelessWidget {
  const _PrivacyNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: DytavaColors.softBlue,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.shield_outlined,
            color: DytavaColors.primary,
            size: 23,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Xử lý dữ liệu mẫu trên thiết bị',
                  style: DytavaTypography.titleMedium.copyWith(
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Không tự tải dữ liệu demo lên máy chủ.',
                  style: DytavaTypography.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkflowSteps extends StatelessWidget {
  const _WorkflowSteps();

  @override
  Widget build(BuildContext context) {
    const steps = ['Nguồn', 'Ánh xạ', 'Đối chiếu', 'Kết quả'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'QUY TRÌNH 4 BƯỚC',
            style: DytavaTypography.labelSmall.copyWith(
              letterSpacing: 0.8,
              color: DytavaColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (var i = 0; i < steps.length; i++) ...[
                if (i > 0)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 5),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: DytavaColors.textMuted,
                    ),
                  ),
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        height: 27,
                        width: 27,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: i == 0
                              ? DytavaColors.primary
                              : DytavaColors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: i == 0
                                ? DytavaColors.primary
                                : DytavaColors.border,
                          ),
                        ),
                        child: Text(
                          '${i + 1}',
                          style: DytavaTypography.labelSmall.copyWith(
                            color: i == 0
                                ? DytavaColors.white
                                : DytavaColors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        steps[i],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DytavaTypography.bodySmall.copyWith(
                          fontSize: 10.5,
                          color: DytavaColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
