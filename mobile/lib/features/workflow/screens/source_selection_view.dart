import 'package:flutter/material.dart';

import '../../../application/workflow_controller.dart';
import '../../../design_system/design_system.dart';
import '../../../domain/workflow.dart';
import '../widgets/workflow_common_widgets.dart';

/// Màn hình Chọn nguồn dữ liệu (`SCR-02`):
/// - Hai thẻ A/B rõ ràng, thích ứng dọc trên điện thoại và 2 cột trên màn hình rộng.
/// - Áp dụng đúng quy tắc Branding: khi chưa chọn nguồn hiển thị `BrandIllustration.emptySource()`,
///   khi đã chọn nguồn chuyển sang `DytavaFileCard` với `BrandIcon.format(...)` (XLSX/CSV/PNG).
class SourceSelectionView extends StatelessWidget {
  final WorkflowController flow;
  final bool quickProcessing;
  final VoidCallback onQuickPrepareBoth;
  final void Function(SourceSide side) onOpenPreview;
  final VoidCallback onContinueMapping;

  const SourceSelectionView({
    super.key,
    required this.flow,
    required this.quickProcessing,
    required this.onQuickPrepareBoth,
    required this.onOpenPreview,
    required this.onContinueMapping,
  });

  Widget _buildSideCard(BuildContext context, SourceSide side) {
    final slot = flow.slot(side);
    final sideUpper = side.name.toUpperCase();
    final otherSide = side == SourceSide.a ? SourceSide.b : SourceSide.a;
    final otherIsImage = flow.slot(otherSide).artifact?.format.isImage == true;

    return WorkflowSectionCard(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: side == SourceSide.a
                    ? DytavaColors.primary
                    : DytavaColors.secondary,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Text(
                sideUpper,
                style: const TextStyle(
                  color: DytavaColors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nguồn $sideUpper',
                    style: DytavaTypography.titleLarge.copyWith(
                      color: DytavaColors.textPrimary,
                    ),
                  ),
                  Text(
                    side == SourceSide.a
                        ? 'Sheet A (Bảng tham chiếu)'
                        : 'Sheet B (Bảng đối chiếu)',
                    style: DytavaTypography.bodySmall,
                  ),
                ],
              ),
            ),
            WorkflowInputStateBadge(state: slot.state),
          ],
        ),
        const Divider(height: 20),

        // Quy tắc Branding:
        // - Khi chưa chọn nguồn (`artifact == null`): hiển thị `BrandIllustration.emptySource()` (`emptyFiles`)
        // - Khi đã có tệp (`artifact != null`): chuyển sang `DytavaFileCard` với `BrandIcon.format(...)`
        if (slot.artifact == null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            decoration: BoxDecoration(
              color: DytavaColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: DytavaColors.border),
            ),
            child: Row(
              children: [
                BrandIllustration.emptySource(size: 56),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Chưa chọn · ${WorkflowUiHelpers.formatEnumName(slot.state)}',
                        style: DytavaTypography.titleMedium.copyWith(
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Chọn tệp bảng tính (Excel/CSV) hoặc ảnh bảng (OCR) cho Nguồn $sideUpper.',
                        style: DytavaTypography.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        else ...[
          DytavaFileCard(
            fileName: slot.artifact!.label,
            metaText:
                '${slot.artifact!.format.name.toUpperCase()} • ${slot.snapshot != null ? '${slot.snapshot!.records.length} hàng × ${slot.snapshot!.fields.length} cột' : WorkflowUiHelpers.formatEnumName(slot.state)}',
            format: slot.artifact!.format,
            verified: slot.ready,
            onTap: slot.busy ? null : () => onOpenPreview(side),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              BrandIcon.format(slot.artifact!.format, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${slot.artifact!.label} · ${WorkflowUiHelpers.formatEnumName(slot.state)}${slot.cancelling ? ' · Đang dọn dữ liệu tạm' : ''}',
                  style: DytavaTypography.bodyMedium,
                ),
              ),
            ],
          ),
        ],

        if (slot.issue != null) ...[
          const SizedBox(height: 8),
          WorkflowIssueList(issues: [slot.issue!]),
        ],
        const SizedBox(height: 12),

        // Tác vụ nhanh theo trạng thái nguồn
        if (slot.state == InputState.selected)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                style: FilledButton.styleFrom(minimumSize: const Size(48, 46)),
                icon: const BrandIcon(DytavaIcons.play, size: 16),
                label: Text('Kiểm tra nhanh $sideUpper (1 chạm)'),
                onPressed: slot.busy ? null : () => flow.importSource(side),
              ),
            ),
          ),
        if (slot.state == InputState.needsReview && slot.review!.cells.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                style: FilledButton.styleFrom(minimumSize: const Size(48, 46)),
                icon: const BrandIcon(DytavaIcons.check, size: 16),
                label: Text('Xác nhận nhanh phạm vi $sideUpper (1 chạm)'),
                onPressed: () =>
                    flow.confirmImport(side, expectedBinding: slot.binding),
              ),
            ),
          ),

        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size(48, 44)),
              icon: const BrandIcon(DytavaIcons.fileCsv, size: 16),
              onPressed: slot.busy
                  ? null
                  : () => flow.selectSource(
                      side,
                      SourceFormat.csv,
                      side == SourceSide.a ? 'fixture:a' : 'fixture:b',
                      'sample.csv',
                    ),
              label: Text(
                slot.artifact == null
                    ? 'Chọn bảng mẫu $sideUpper'
                    : 'Thay bảng mẫu $sideUpper',
              ),
            ),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size(48, 44)),
              icon: const BrandIcon(DytavaIcons.ocr, size: 16),
              onPressed: slot.busy || otherIsImage
                  ? null
                  : () => flow.selectSource(
                      side,
                      SourceFormat.png,
                      'fixture:image-a',
                      'sample-image.png',
                    ),
              label: Text('Chọn OCR giả lập $sideUpper'),
            ),
            if (slot.artifact != null)
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(48, 44),
                ),
                icon: const BrandIcon(DytavaIcons.preview, size: 16),
                onPressed: slot.busy ? null : () => onOpenPreview(side),
                label: Text('Kiểm tra $sideUpper'),
              ),
            if (slot.artifact != null)
              TextButton.icon(
                style: TextButton.styleFrom(minimumSize: const Size(48, 44)),
                icon: const BrandIcon(DytavaIcons.delete, size: 16),
                onPressed: () => flow.resetSource(side),
                label: Text(
                  'Xóa $sideUpper',
                  style: const TextStyle(color: DytavaColors.different),
                ),
              ),
          ],
        ),
        if (otherIsImage && slot.artifact?.format.isImage != true)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Phía còn lại đã là ảnh OCR; phía này chỉ nhận bảng dữ liệu.',
              style: DytavaTypography.bodySmall.copyWith(
                color: DytavaColors.textSecondary,
              ),
            ),
          ),
        if (slot.busy) ...[
          const SizedBox(height: 8),
          WorkflowPrimaryButton(
            label: 'Hủy nhập $sideUpper',
            iconAsset: DytavaIcons.cancel,
            onPressed: slot.cancelling ? null : () => flow.cancelImport(side),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WorkflowSectionCard(
          padding: const EdgeInsets.all(14),
          color: DytavaColors.softBlue,
          border: Border.all(
            color: DytavaColors.primary.withValues(alpha: 0.3),
          ),
          children: [
            Row(
              children: [
                BrandIllustration.onboarding(
                  DytavaIllustrations.onboardingImport,
                  maxHeight: 54,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Mỗi nguồn có trạng thái riêng. Thay nguồn làm mất hiệu lực ánh xạ và kết quả liên quan.',
                    style: DytavaTypography.bodyMedium.copyWith(
                      color: DytavaColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        if (!flow.inputsReady)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            child: OutlinedButton.icon(
              icon: quickProcessing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const BrandIcon(DytavaIcons.play, size: 18),
              label: const Text(
                'Tự động chuẩn bị nhanh cả 2 nguồn (1 chạm)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: DytavaColors.primary,
                ),
              ),
              style: OutlinedButton.styleFrom(
                backgroundColor: DytavaColors.softBlue,
                side: const BorderSide(color: DytavaColors.primary),
                minimumSize: const Size(48, 48),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: quickProcessing ? null : onQuickPrepareBoth,
            ),
          ),

        // Bố cục thích ứng: 2 cột trên màn hình rộng (>= 680dp), xếp dọc trên điện thoại
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 680) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildSideCard(context, SourceSide.a)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildSideCard(context, SourceSide.b)),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSideCard(context, SourceSide.a),
                _buildSideCard(context, SourceSide.b),
              ],
            );
          },
        ),

        const SizedBox(height: 6),
        WorkflowPrimaryButton(
          label: 'Tiếp tục ánh xạ cột',
          iconAsset: DytavaIcons.mapping,
          onPressed: flow.inputsReady ? onContinueMapping : null,
        ),
        if (!flow.inputsReady)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Center(
              child: Text(
                'Cần cả A và B ở PREVIEW_READY trước khi ánh xạ.',
                style: DytavaTypography.bodyMedium,
              ),
            ),
          ),
      ],
    );
  }
}
