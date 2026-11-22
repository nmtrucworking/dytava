import 'dart:async';

import 'package:flutter/material.dart';

import '../../../application/workflow_controller.dart';
import '../../../design_system/design_system.dart';
import '../../../domain/workflow.dart';
import '../../../infrastructure/file_upload_service.dart';
import '../../../ocr/infrastructure/ocr_capture_service.dart';
import '../widgets/workflow_common_widgets.dart';
import '../widgets/sheet_mapping_review.dart';

/// Màn hình Nhập tệp (`SCR-02` / `Import files`):
/// - Thẻ A/B tinh gọn với mã nguồn A/B và nút đổi tệp (Swap) màu xanh.
/// - Thẻ thiết lập so khớp (Matching settings) với biểu tượng bánh răng.
/// - Thẻ cảnh báo đối chiếu sheet (Review sheet matches) với nền cam nhạt khi chưa xác định cặp sheet.
/// - Thanh tác vụ cố định (Sticky Bottom Bar) ở đáy màn hình.
class SourceSelectionView extends StatefulWidget {
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

  @override
  State<SourceSelectionView> createState() => _SourceSelectionViewState();
}

class _SourceSelectionViewState extends State<SourceSelectionView> {
  bool _showMappingReview = false;

  Widget _buildSideCard(BuildContext context, SourceSide side) {
    final slot = widget.flow.slot(side);
    final artifact = slot.artifact;
    final tag = side.name.toUpperCase();
    final isA = side == SourceSide.a;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Tag badge A or B
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(
              tag,
              style: const TextStyle(
                fontFamily: DytavaTypography.primaryFont,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: DytavaColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // File Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isA ? 'ORIGINAL FILE' : 'UPDATED FILE',
                  style: const TextStyle(
                    fontFamily: DytavaTypography.primaryFont,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF64748B),
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  artifact?.label ?? 'Choose file $tag',
                  style: const TextStyle(
                    fontFamily: DytavaTypography.primaryFont,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  artifact == null
                      ? 'XLSX, CSV, TSV, TXT, JSON'
                      : '${artifact.format.name.toUpperCase()}  ·  ${slot.snapshot == null ? 'Needs review' : '${slot.snapshot!.records.length} rows  ·  ${slot.snapshot!.fields.length} columns'}',
                  style: const TextStyle(
                    fontFamily: DytavaTypography.primaryFont,
                    fontSize: 11.5,
                    color: Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Action buttons (OCR Image Capture/Review + File Select/Replace)
          if (slot.busy)
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.2),
            )
          else ...[
            if (slot.state == InputState.needsReview &&
                slot.review?.cells.isNotEmpty == true)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Material(
                  color: DytavaColors.modifiedBg,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    key: ValueKey('open-ocr-review-${side.name}'),
                    borderRadius: BorderRadius.circular(10),
                    onTap: widget.flow.busy
                        ? null
                        : () => widget.flow.navigate(
                            WorkflowScreen.ocrReview,
                            side: side,
                          ),
                    child: Tooltip(
                      message: 'Duyệt OCR nguồn $tag',
                      child: Container(
                        height: 36,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        alignment: Alignment.center,
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.fact_check_outlined,
                              color: DytavaColors.modified,
                              size: 17,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Duyệt OCR',
                              style: TextStyle(
                                fontFamily: DytavaTypography.primaryFont,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: DytavaColors.modified,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Material(
                color: DytavaColors.softPurple,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  key: ValueKey('ocr-source-button-${side.name}'),
                  borderRadius: BorderRadius.circular(10),
                  onTap: widget.flow.busy
                      ? null
                      : () => _openOcrSourceSheet(context, side),
                  child: Tooltip(
                    message: 'Quét OCR bảng tính $tag',
                    child: Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      child: const BrandIcon(DytavaIcons.ocr, size: 19),
                    ),
                  ),
                ),
              ),
            ),
            Material(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: widget.flow.busy
                    ? null
                    : () => _handleFileUpload(context, side),
                child: Tooltip(
                  message: artifact == null
                      ? 'Select file $tag'
                      : 'Replace file $tag',
                  child: Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    child: Icon(
                      artifact == null
                          ? Icons.add_rounded
                          : Icons.swap_horiz_rounded,
                      color: DytavaColors.primary,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final flow = widget.flow;
    final count = SourceSide.values
        .where((s) => flow.slot(s).artifact != null)
        .length;
    final isUncertain = flow.sheetMapping?.complete == false;

    final snapA = flow.slot(SourceSide.a).snapshot;
    final snapB = flow.slot(SourceSide.b).snapshot;
    final sheetsA = snapA?.workbookSheets.isNotEmpty == true
        ? snapA!.workbookSheets.length
        : (snapA != null ? 1 : 0);
    final sheetsB = snapB?.workbookSheets.isNotEmpty == true
        ? snapB!.workbookSheets.length
        : (snapB != null ? 1 : 0);
    final totalSheetPairs = flow.sheetMapping?.pairs.length ?? 0;

    return WorkflowScreenLayout(
      contentPadding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // NEW COMPARISON badge
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'NEW COMPARISON',
                style: TextStyle(
                  fontFamily: DytavaTypography.primaryFont,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: DytavaColors.primary,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Compare spreadsheets',
            style: TextStyle(
              fontFamily: DytavaTypography.primaryFont,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E293B),
              height: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Choose the original and updated versions.',
            style: TextStyle(
              fontFamily: DytavaTypography.primaryFont,
              fontSize: 13,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 14),

          // File Card A and Card B
          for (final side in SourceSide.values) _buildSideCard(context, side),

          // Matching settings card
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x06000000),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: flow.inputsReady ? widget.onContinueMapping : null,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.settings_outlined,
                          color: DytavaColors.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Matching settings',
                              style: TextStyle(
                                fontFamily: DytavaTypography.primaryFont,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Auto match · Exact values',
                              style: TextStyle(
                                fontFamily: DytavaTypography.primaryFont,
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: Color(0xFF94A3B8),
                        size: 22,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Review sheet matches warning card (shown when pairings are uncertain)
          if (isUncertain) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFFEDD5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: Color(0xFFD97706),
                        size: 32,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Review ${totalSheetPairs > 0 ? totalSheetPairs : 4} sheet matches',
                              style: const TextStyle(
                                fontFamily: DytavaTypography.primaryFont,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '$sheetsA sheets in original  ·  $sheetsB in updated',
                              style: const TextStyle(
                                fontFamily: DytavaTypography.primaryFont,
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Some sheet pairings are uncertain. Confirm them to continue.',
                              style: TextStyle(
                                fontFamily: DytavaTypography.primaryFont,
                                fontSize: 12.5,
                                color: Color(0xFF475569),
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 46,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _showMappingReview = !_showMappingReview;
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: DytavaColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _showMappingReview
                                ? 'Hide sheet matches'
                                : 'Review matches',
                            style: const TextStyle(
                              fontFamily: DytavaTypography.primaryFont,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            _showMappingReview
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.arrow_forward_rounded,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_showMappingReview)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SheetMappingReview(flow: widget.flow),
              ),
          ],

          // Quick sample link when no files are chosen
          if (count == 0)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed:
                    widget.quickProcessing ? null : widget.onQuickPrepareBoth,
                child: Text(
                  widget.quickProcessing
                      ? 'Preparing sample…'
                      : 'Use sample files ›',
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
            Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: isUncertain
                      ? const Color(0xFF0F766E)
                      : const Color(0xFF64748B),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    isUncertain
                        ? 'Confirm sheet matches to continue'
                        : 'Confirm file order: original A, updated B.',
                    style: const TextStyle(
                      fontFamily: DytavaTypography.primaryFont,
                      fontSize: 12,
                      color: Color(0xFF334155),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            WorkflowPrimaryButton(
              label: 'Compare files',
              iconAsset: DytavaIcons.forward,
              onPressed:
                  flow.inputsReady &&
                          !flow.busy &&
                          flow.sheetMapping?.complete != false
                      ? widget.onContinueToProposal
                      : null,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleFileUpload(BuildContext context, SourceSide side) async {
    final flow = widget.flow;
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

  Future<void> _openOcrSourceSheet(
    BuildContext context,
    SourceSide side,
  ) async {
    final tag = side.name.toUpperCase();
    final kind = await showModalBottomSheet<OcrImageSourceKind>(
      context: context,
      useSafeArea: true,
      backgroundColor: DytavaColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const BrandIcon(DytavaIcons.ocr, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Quét OCR bảng tính · Nguồn $tag',
                    style: DytavaTypography.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Module OCR độc lập (Tiếng Việt NFC): Tiền xử lý ảnh → Nhận dạng ký tự → Tái cấu trúc hàng/cột → Kiểm tra & hiệu chỉnh → Chuẩn hóa.',
              style: DytavaTypography.bodySmall,
            ),
            const SizedBox(height: 16),
            WorkflowSecondaryButton(
              key: const ValueKey('ocr-pick-camera'),
              label: 'Chụp ảnh bảng tính / tài liệu',
              iconAsset: DytavaIcons.camera,
              onPressed: () =>
                  Navigator.pop(sheetContext, OcrImageSourceKind.camera),
            ),
            WorkflowSecondaryButton(
              key: const ValueKey('ocr-pick-gallery'),
              label: 'Chọn ảnh PNG / JPEG từ thiết bị',
              iconAsset: DytavaIcons.upload,
              onPressed: () =>
                  Navigator.pop(sheetContext, OcrImageSourceKind.gallery),
            ),
            WorkflowPrimaryButton(
              key: const ValueKey('ocr-pick-vietnamese-sample'),
              label: 'Nạp ảnh bảng tiếng Việt có dấu (Mẫu kiểm thử)',
              iconAsset: DytavaIcons.ocr,
              onPressed: () => Navigator.pop(
                sheetContext,
                OcrImageSourceKind.vietnameseSample,
              ),
            ),
          ],
        ),
      ),
    );
    if (kind == null || !context.mounted) return;
    await _handleOcrCapture(context, side, kind);
  }

  Future<void> _handleOcrCapture(
    BuildContext context,
    SourceSide side,
    OcrImageSourceKind kind,
  ) async {
    final flow = widget.flow;
    final generation = flow.slot(side).generation;
    try {
      final acquired = await OcrCaptureService.acquireImage(
        side: side,
        sourceKind: kind,
      );
      if (acquired == null) return;
      if (!context.mounted ||
          !flow.usable ||
          flow.slot(side).generation != generation) {
        OcrCaptureService.release(acquired.privateRef);
        return;
      }
      await flow.selectSource(
        side,
        acquired.format,
        acquired.privateRef,
        acquired.fileName,
      );
      if (flow.slot(side).artifact?.privateRef != acquired.privateRef) {
        OcrCaptureService.release(acquired.privateRef);
        return;
      }
      await flow.importSource(side);
      if (context.mounted &&
          flow.slot(side).state == InputState.needsReview) {
        flow.navigate(WorkflowScreen.ocrReview, side: side);
      }
    } catch (e) {
      if (context.mounted) {
        DytavaToast.error(
          context,
          'Lỗi nạp ảnh OCR: $e',
          title: 'Không thể khởi tạo OCR',
        );
      }
    }
  }
}
