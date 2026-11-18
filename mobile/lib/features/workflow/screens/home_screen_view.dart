import 'package:excelcompare_core/excelcompare_core.dart';
import 'package:flutter/material.dart';

import '../../../application/workflow_controller.dart';
import '../../../design_system/design_system.dart';
import '../../../domain/workflow.dart';
import '../../diagnostics/compare_demo_page.dart';
import '../widgets/workflow_common_widgets.dart';

/// Màn hình Trang chủ (`SCR-01`) thiết kế theo mô hình Guided Mobile Workflow:
/// - Một nhiệm vụ trọng tâm: bắt đầu phiên đối chiếu mới hoặc tiếp tục phiên hiện tại.
/// - Hiển thị đúng 1 `BrandIllustration.hero` (`heroGetStarted` / `heroEmptyWorkspace`).
/// - Loại bỏ lưới 8 module kiểu web dashboard; gom các tiện ích phụ vào thanh tác vụ thứ cấp gọn nhẹ.
class HomeScreenView extends StatelessWidget {
  final WorkflowController flow;
  final bool quickProcessing;
  final VoidCallback onStartNewSession;
  final VoidCallback onQuickRun;
  final VoidCallback onResumeSession;
  final VoidCallback onCloseSession;
  final VoidCallback onOpenPresets;
  final VoidCallback onOpenSettings;

  const HomeScreenView({
    super.key,
    required this.flow,
    required this.quickProcessing,
    required this.onStartNewSession,
    required this.onQuickRun,
    required this.onResumeSession,
    required this.onCloseSession,
    required this.onOpenPresets,
    required this.onOpenSettings,
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
        // 1. Thẻ nhiệm vụ chính: Bắt đầu phiên so sánh mới (Mobile-first Hero)
        WorkflowSectionCard(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: DytavaColors.softBlue,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: const BrandIcon(DytavaIcons.symbol, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Dytava',
                        style: DytavaTypography.titleMedium,
                      ),
                      Text(
                        'So sánh dữ liệu trên thiết bị',
                        style: DytavaTypography.bodySmall.copyWith(
                          color: DytavaColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Center(
              child: BrandIllustration.hero(
                hasActiveSession: _hasActiveSession,
                maxHeight: 108,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'So sánh hai nguồn dữ liệu',
              style: DytavaTypography.titleLarge.copyWith(
                color: DytavaColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Phát hiện sai khác giữa hai bảng tính, kiểm tra từng giá trị và vị trí nguồn.',
              style: DytavaTypography.bodyMedium,
            ),
            const SizedBox(height: 12),
            // Định dạng hỗ trợ với BrandIcon
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: const [
                _FormatChip(
                  iconAsset: DytavaIcons.fileXlsx,
                  label: 'Excel (XLSX)',
                ),
                _FormatChip(
                  iconAsset: DytavaIcons.fileCsv,
                  label: 'CSV / TSV',
                ),
                _FormatChip(
                  iconAsset: DytavaIcons.filePng,
                  label: 'Dữ liệu từ ảnh (OCR)',
                ),
              ],
            ),
            const SizedBox(height: 16),
            // CTA Chính: Bắt đầu phiên mới (Chọn 2 nguồn dữ liệu)
            WorkflowPrimaryButton(
              label: 'So sánh mới (dữ liệu mẫu)',
              iconAsset: DytavaIcons.importData,
              onPressed: onStartNewSession,
            ),
            const SizedBox(height: 6),
            // CTA Nhanh: Trải nghiệm nhanh 1 chạm với bộ dữ liệu mẫu
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  backgroundColor: DytavaColors.softBlue,
                  side: const BorderSide(color: DytavaColors.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: quickProcessing ? null : onQuickRun,
                icon: quickProcessing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const BrandIcon(DytavaIcons.play, size: 18),
                label: Text(
                  quickProcessing
                      ? 'Đang tự động xử lý 2 Sheets...'
                      : 'Trải nghiệm nhanh (1 chạm)',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: DytavaColors.primary,
                  ),
                ),
              ),
            ),
          ],
        ),

        // 2. Phiên hiện tại ("Tiếp tục phiên so sánh") — chỉ hiển thị khi có phiên hợp lệ
        if (_hasActiveSession) ...[
          DytavaSessionResumeCard(
            stageLabel: _sessionStageLabel(),
            sourceSummary: _sessionSourceSummary(),
            hasCompletedResult: flow.resultCurrent,
            onResume: onResumeSession,
            onCloseSession: flow.usable ? onCloseSession : null,
          ),
          if (flow.resultCurrent && flow.result != null) ...[
            DytavaResultCard(
              fileA: flow.slot(SourceSide.a).artifact?.label ?? 'Sheet A',
              fileB: flow.slot(SourceSide.b).artifact?.label ?? 'Sheet B',
              totalPairs: flow.result!.cells.length,
              equivalentCount: flow.result!.count(DecisionStatus.equivalent),
              differentCount: flow.result!.count(DecisionStatus.different),
              unresolvedCount: flow.result!.count(DecisionStatus.unresolved),
              onTap: onResumeSession,
            ),
            const SizedBox(height: 12),
          ],
        ],

        // 3. Quyền riêng tư & Tiện ích phụ trợ (không cạnh tranh với CTA chính)
        WorkflowSectionCard(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                BrandIllustration.securityLocal(size: 42),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Xử lý tại thiết bị; không tự tải dữ liệu lên mạng',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: DytavaColors.exact,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Bản hiện hành dùng dữ liệu mẫu cục bộ để kiểm chứng hành trình 4 bước và bằng chứng sai khác.',
                        style: DytavaTypography.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 22),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 44),
                  ),
                  onPressed: onOpenPresets,
                  icon: const BrandIcon(DytavaIcons.saveRule, size: 16),
                  label: const Text('Mẫu quy tắc'),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 44),
                  ),
                  onPressed: onOpenSettings,
                  icon: const BrandIcon(DytavaIcons.settings, size: 16),
                  label: const Text('Cài đặt & Bảo mật'),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 44),
                  ),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const CompareDemoPage(),
                    ),
                  ),
                  icon: const BrandIcon(DytavaIcons.compare, size: 16),
                  label: const Text('Mở thử nghiệm so sánh hai giá trị'),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _FormatChip extends StatelessWidget {
  final String iconAsset;
  final String label;

  const _FormatChip({required this.iconAsset, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: DytavaColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: DytavaColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          BrandIcon(iconAsset, size: 16),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: DytavaTypography.bodySmall.copyWith(
                color: DytavaColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
