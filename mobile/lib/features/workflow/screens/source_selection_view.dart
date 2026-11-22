import 'dart:async';

import 'package:flutter/material.dart';

import '../../../application/workflow_controller.dart';
import '../../../design_system/design_system.dart';
import '../../../domain/workflow.dart';
import '../../../infrastructure/file_upload_service.dart';
import '../widgets/workflow_common_widgets.dart';
import '../widgets/sheet_mapping_review.dart';

/// Màn hình Chọn nguồn dữ liệu (`SCR-02`):
/// - Hai thẻ A/B rõ ràng, thích ứng dọc trên điện thoại và 2 cột trên màn hình rộng.
/// - Áp dụng đúng quy tắc Branding: khi chưa chọn nguồn hiển thị `BrandIllustration.emptySource()`,
///   khi đã chọn nguồn chuyển sang `DytavaFileCard` với `BrandIcon.format(...)` (XLSX/CSV/PNG).
class SourceSelectionView extends StatelessWidget {
  final WorkflowController flow;
  final bool quickProcessing;
  final VoidCallback? onQuickPrepareBoth;
  final void Function(SourceSide side) onOpenPreview;
  final VoidCallback onContinueMapping;
  final VoidCallback? onContinueToProposal;

  const SourceSelectionView({
    super.key,
    required this.flow,
    this.quickProcessing = false,
    this.onQuickPrepareBoth,
    required this.onOpenPreview,
    required this.onContinueMapping,
    this.onContinueToProposal,
  });

  Widget _buildSideCard(BuildContext context, SourceSide side) {
    final slot = flow.slot(side);
    final artifact = slot.artifact;
    final tag = side.name.toUpperCase();
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: DytavaColors.white,
        border: Border.all(color: DytavaColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          children: [
            ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 2,
              ),
              leading: Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: DytavaColors.primaryLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  tag,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: DytavaColors.primary,
                  ),
                ),
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    side == SourceSide.a ? 'ORIGINAL FILE' : 'UPDATED FILE',
                    style: DytavaTypography.labelSmall.copyWith(
                      fontSize: 10,
                      color: DytavaColors.textSecondary,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    artifact?.label ?? 'Choose file $tag',
                    style: DytavaTypography.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  artifact == null
                      ? 'XLSX, CSV, TSV, TXT, JSON'
                      : '${artifact.format.name.toUpperCase()}  ·  ${slot.snapshot == null ? 'Needs review' : '${slot.snapshot!.records.length} rows · ${slot.snapshot!.fields.length} columns'}',
                  style: DytavaTypography.bodySmall.copyWith(fontSize: 11),
                ),
              ),
              trailing: slot.busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (artifact != null)
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            tooltip: 'Remove file $tag',
                            onPressed: () => flow.resetSource(side),
                            icon: const Icon(
                              Icons.close,
                              size: 18,
                              color: DytavaColors.textSecondary,
                            ),
                          ),
                        const SizedBox(width: 8),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          tooltip: artifact == null
                              ? 'Select file $tag'
                              : 'Replace file $tag',
                          onPressed: flow.busy
                              ? null
                              : () => _handleFileUpload(context, side),
                          icon: Icon(
                            artifact == null ? Icons.add : Icons.refresh,
                            color: DytavaColors.primary,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
              onTap: slot.busy
                  ? null
                  : () => artifact == null
                        ? _handleFileUpload(context, side)
                        : onOpenPreview(side),
            ),
            if (artifact != null && !slot.ready && !slot.busy)
              TextButton(
                onPressed: () => onOpenPreview(side),
                child: Text('Review file $tag ›'),
              ),
            if (slot.busy)
              TextButton(
                onPressed: slot.cancelling
                    ? null
                    : () => flow.cancelImport(side),
                child: Text('Cancel import $tag'),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final count = SourceSide.values
        .where((s) => flow.slot(s).artifact != null)
        .length;
    return WorkflowScreenLayout(
      contentPadding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 4),
          const Text(
            'Two files. One comparison.',
            style: DytavaTypography.titleLarge,
          ),
          const SizedBox(height: 2),
          const Text(
            'Add both files. Dytava detects matching data.',
            style: DytavaTypography.bodySmall,
          ),
          const SizedBox(height: 8),
          for (final side in SourceSide.values) _buildSideCard(context, side),
          Material(
            color: DytavaColors.primaryLight,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: flow.inputsReady ? onContinueMapping : null,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Auto match · Exact values',
                        style: TextStyle(
                          fontSize: 12,
                          color: DytavaColors.primary,
                        ),
                      ),
                    ),
                    Text(
                      'Advanced ›',
                      style: TextStyle(
                        fontSize: 12,
                        color: DytavaColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: DytavaColors.primaryLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$count files',
                  style: DytavaTypography.labelSmall.copyWith(
                    color: DytavaColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  flow.inputsReady
                      ? 'Both workbooks are ready.'
                      : 'Choose an original and an updated file.',
                  style: DytavaTypography.bodySmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          WorkflowSectionCard(
            padding: const EdgeInsets.all(12),
            color: DytavaColors.primaryLight,
            border: Border.all(color: Colors.transparent),
            children: [
              Text(
                'AUTOMATIC ANALYSIS',
                style: DytavaTypography.labelSmall.copyWith(
                  color: DytavaColors.primary,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'No mapping steps required',
                style: DytavaTypography.titleSmall,
              ),
              const SizedBox(height: 4),
              const Text(
                'Dytava checks sheets, columns and row keys. You review only ambiguous matches.',
                style: DytavaTypography.bodySmall,
              ),
            ],
          ),
          if (flow.sheetMapping?.complete == false)
            SheetMappingReview(flow: flow),
          if (count == 0)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: quickProcessing ? null : onQuickPrepareBoth,
                child: Text(
                  quickProcessing ? 'Preparing sample…' : 'Use sample files ›',
                ),
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
      bottomBar: StickyBottomBar(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Confirm file order: original A, updated B.',
              style: DytavaTypography.bodySmall,
            ),
            const SizedBox(height: 6),
            WorkflowPrimaryButton(
              label: 'Compare files',
              iconAsset: DytavaIcons.forward,
              onPressed:
                  flow.inputsReady &&
                      !flow.busy &&
                      flow.sheetMapping?.complete != false
                  ? onContinueToProposal
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleFileUpload(BuildContext context, SourceSide side) async {
    final generation = flow.slot(side).generation;
    final navigator = Navigator.of(context);
    final dialog = DialogRoute<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(),
              ),
              SizedBox(width: 16),
              Expanded(child: Text('Đang chọn và đọc tệp…')),
            ],
          ),
        ),
      ),
    );
    unawaited(navigator.push(dialog));
    try {
      final info = await MobileFileUploadService.pickAndProcessFile(side);
      if (info == null) return;
      if (!context.mounted ||
          !flow.usable ||
          flow.slot(side).generation != generation) {
        MobileFileUploadService.release(info.privateRef);
        return;
      }
      await flow.selectSource(
        side,
        info.format,
        info.privateRef,
        info.fileName,
      );
      await flow.importSource(side);
      final slotNow = flow.slot(side);
      if (slotNow.state == InputState.needsReview) {
        await flow.confirmImport(side, expectedBinding: slotNow.binding);
      }
      if (context.mounted) {
        DytavaToast.success(
          context,
          'Đã tải ${info.fileName}: ${info.rowCount} hàng × ${info.columnCount} cột.',
          title: 'Tải tệp thành công',
        );
      }
    } catch (e) {
      if (context.mounted) {
        DytavaToast.error(
          context,
          'Lỗi tải tệp: $e',
          title: 'Không thể nạp tệp',
        );
      }
    } finally {
      if (dialog.isActive) navigator.removeRoute(dialog);
    }
  }
}
