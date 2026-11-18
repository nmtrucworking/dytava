import 'package:flutter/material.dart';

import '../../../application/workflow_controller.dart';
import '../../../design_system/design_system.dart';
import '../../../domain/workflow.dart';
import '../widgets/workflow_common_widgets.dart';

/// Màn hình Xem trước & Kiểm tra nguồn (`SCR-03`):
/// - Tóm tắt số hàng/cột và trạng thái xác thực trước, bảng dữ liệu chi tiết bên dưới.
/// - Tích hợp `BrandIllustration` theo trạng thái: `processingImport`, `successImport`, `statusCancelled`, `issue`.
class PreviewScreenView extends StatelessWidget {
  final WorkflowController flow;
  final VoidCallback onOpenOcrReview;
  final VoidCallback onBackToSources;

  const PreviewScreenView({
    super.key,
    required this.flow,
    required this.onOpenOcrReview,
    required this.onBackToSources,
  });

  @override
  Widget build(BuildContext context) {
    final source = flow.slot(flow.activeSide);
    final sideUpper = source.side.name.toUpperCase();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WorkflowSectionCard(
          children: [
            Row(
              children: [
                if (source.artifact != null) ...[
                  BrandIcon.format(source.artifact!.format, size: 28),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Text(
                    'Nguồn $sideUpper · ${source.artifact?.label ?? 'Chưa chọn'}',
                    style: DytavaTypography.titleLarge.copyWith(
                      color: DytavaColors.textPrimary,
                    ),
                  ),
                ),
                WorkflowInputStateBadge(state: source.state),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              WorkflowUiHelpers.formatEnumName(source.state),
              style: DytavaTypography.bodyMedium,
            ),
            if (source.snapshot != null) ...[
              const SizedBox(height: 10),
              // Tóm tắt nhanh số hàng & số cột trước khi đi vào bảng chi tiết
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: DytavaColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: DytavaColors.border),
                ),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    _QuickStatItem(
                      iconAsset: DytavaIcons.rows,
                      label: 'Số bản ghi',
                      value: '${source.snapshot!.records.length} hàng',
                    ),
                    _QuickStatItem(
                      iconAsset: DytavaIcons.columns,
                      label: 'Số trường',
                      value: '${source.snapshot!.fields.length} cột',
                    ),
                  ],
                ),
              ),
            ],
            if (source.issue != null) ...[
              const SizedBox(height: 8),
              WorkflowIssueList(issues: [source.issue!]),
            ],
            if (source.state == InputState.cancelled) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const BrandIllustration(
                    DytavaIllustrations.statusCancelled,
                    size: 52,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Thao tác nạp nguồn đã được hủy và dọn dữ liệu tạm.',
                      style: DytavaTypography.bodyMedium,
                    ),
                  ),
                ],
              ),
            ],
            if (source.busy) ...[
              const SizedBox(height: 12),
              Center(
                child: BrandIllustration.processing(
                  asset: DytavaIllustrations.processingImport,
                  size: 72,
                ),
              ),
              const SizedBox(height: 10),
              const LinearProgressIndicator(),
              const SizedBox(height: 12),
              WorkflowPrimaryButton(
                label: 'Hủy nhập nguồn',
                iconAsset: DytavaIcons.cancel,
                onPressed: source.cancelling
                    ? null
                    : () => flow.cancelImport(source.side),
              ),
            ],
            if (source.state == InputState.selected ||
                source.state == InputState.failed ||
                source.state == InputState.cancelled) ...[
              const SizedBox(height: 12),
              WorkflowPrimaryButton(
                label: source.state == InputState.selected
                    ? 'Kiểm tra nguồn mẫu'
                    : 'Thử lại nhập nguồn',
                iconAsset: DytavaIcons.play,
                onPressed:
                    source.state == InputState.failed &&
                        source.issue?.retryable != true
                    ? null
                    : () => flow.importSource(source.side),
              ),
            ],
            if (source.state == InputState.needsReview &&
                source.review!.cells.isEmpty) ...[
              const SizedBox(height: 12),
              WorkflowPrimaryButton(
                label: 'Xác nhận phạm vi và header mẫu',
                iconAsset: DytavaIcons.check,
                onPressed: () => flow.confirmImport(
                  source.side,
                  expectedBinding: source.binding,
                ),
              ),
            ],
            if (source.state == InputState.needsReview &&
                source.review!.cells.isNotEmpty) ...[
              const SizedBox(height: 12),
              WorkflowPrimaryButton(
                label: 'Review từng ô OCR mẫu',
                iconAsset: DytavaIcons.ocr,
                onPressed: onOpenOcrReview,
              ),
            ],
          ],
        ),
        if (source.ready) ...[
          WorkflowSectionCard(
            children: [
              Row(
                children: [
                  BrandIllustration.success(
                    asset: DytavaIllustrations.successImport,
                    size: 48,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Đã xác thực toàn bộ fixture · ${source.snapshot!.records.length} hàng. Đây không phải bằng chứng parser tệp thật.',
                      style: DytavaTypography.titleMedium.copyWith(
                        color: DytavaColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DytavaSheetPreviewTable(
                sheetTitle:
                    'Sheet $sideUpper (${source.artifact?.label ?? 'sample.csv'})',
                fields: source.snapshot!.fields,
                records: source.snapshot!.records,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 46),
                  ),
                  icon: const BrandIcon(DytavaIcons.refresh, size: 16),
                  onPressed: () => flow.changeImportConfig(
                    source.side,
                    ImportConfiguration(
                      ocrRevision: source.config.ocrRevision + 1,
                    ),
                  ),
                  label: const Text('Đổi cấu hình nhập mẫu'),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 6),
        WorkflowPrimaryButton(
          label: 'Trở về nguồn A/B',
          iconAsset: DytavaIcons.back,
          onPressed: source.busy ? null : onBackToSources,
        ),
      ],
    );
  }
}

class _QuickStatItem extends StatelessWidget {
  final String iconAsset;
  final String label;
  final String value;

  const _QuickStatItem({
    required this.iconAsset,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        BrandIcon(iconAsset, size: 18),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: DytavaTypography.bodySmall.copyWith(
            color: DytavaColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: DytavaTypography.dataSmall.copyWith(
            color: DytavaColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

/// Màn hình Duyệt OCR mẫu (`SCR-04`):
/// - Sử dụng `BrandIllustration.processing(asset: DytavaIllustrations.processingOcr)`.
/// - Yêu cầu người dùng xác nhận đầy đủ các ô nhận dạng trước khi mở khóa bước tiếp theo.
class OcrReviewScreenView extends StatelessWidget {
  final WorkflowController flow;
  final Set<String> reviewedCells;
  final ValueChanged<String> onToggleCell;
  final VoidCallback onReviewAll;
  final VoidCallback onConfirmReviewed;

  const OcrReviewScreenView({
    super.key,
    required this.flow,
    required this.reviewedCells,
    required this.onToggleCell,
    required this.onReviewAll,
    required this.onConfirmReviewed,
  });

  @override
  Widget build(BuildContext context) {
    final source = flow.slot(flow.activeSide);
    final cells = source.review?.cells ?? const <ReviewCell>[];
    final allReviewed =
        cells.isNotEmpty && cells.every((c) => reviewedCells.contains(c.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WorkflowSectionCard(
          color: DytavaColors.softAmber,
          border: Border.all(
            color: DytavaColors.unresolved.withValues(alpha: 0.4),
          ),
          children: [
            Row(
              children: [
                BrandIllustration.processing(
                  asset: DytavaIllustrations.processingOcr,
                  size: 52,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'OCR Giả lập',
                        style: DytavaTypography.titleMedium.copyWith(
                          color: DytavaColors.unresolved,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'OCR GIẢ LẬP · Chưa có ảnh, geometry, crop hoặc bộ nhận dạng thật. Review này chỉ kiểm tra điều kiện của flow.',
                        style: DytavaTypography.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        WorkflowSectionCard(
          children: [
            Row(
              children: [
                const BrandIcon(DytavaIcons.ocr, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Danh sách ô cần review',
                    style: DytavaTypography.titleLarge.copyWith(
                      color: DytavaColors.textPrimary,
                    ),
                  ),
                ),
                WorkflowStatusPill(
                  label: '${reviewedCells.length}/${cells.length} ô',
                  color: DytavaColors.primary,
                  bg: DytavaColors.softBlue,
                  iconAsset: DytavaIcons.cells,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Đã xác nhận ${reviewedCells.length}/${cells.length} ô. Confidence không thay thế review.',
              style: DytavaTypography.bodyMedium,
            ),
            const Divider(height: 20),
            if (cells.isNotEmpty && reviewedCells.length < cells.length)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 44),
                  ),
                  icon: const BrandIcon(DytavaIcons.check, size: 16),
                  label: const Text('Chọn duyệt nhanh toàn bộ ô OCR'),
                  onPressed: onReviewAll,
                ),
              ),
            for (final cell in cells)
              WorkflowCheckTile(
                label: '${cell.id}: ${cell.recognizedText}',
                checked: reviewedCells.contains(cell.id),
                onChanged: (_) => onToggleCell(cell.id),
              ),
            const SizedBox(height: 12),
            WorkflowPrimaryButton(
              label: 'Xác nhận các ô đã review',
              iconAsset: DytavaIcons.check,
              onPressed: allReviewed ? onConfirmReviewed : null,
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(48, 46),
                ),
                icon: const BrandIcon(DytavaIcons.crop, size: 16),
                onPressed: () async {
                  await flow.changeImportConfig(
                    source.side,
                    ImportConfiguration(
                      ocrRevision: source.config.ocrRevision + 1,
                    ),
                  );
                  await flow.importSource(source.side);
                },
                label: const Text('Giả lập đổi crop/layout, xóa review cũ'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
