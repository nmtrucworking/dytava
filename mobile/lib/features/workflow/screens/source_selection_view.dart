import 'dart:async';

import 'package:excelcompare_core/excelcompare_core.dart';
import 'package:flutter/material.dart';

import '../../../application/workflow_controller.dart';
import '../../../design_system/design_system.dart';
import '../../../domain/workflow.dart';
import '../../../infrastructure/file_upload_service.dart';
import '../../../ocr/infrastructure/ocr_capture_service.dart';
import '../widgets/workflow_common_widgets.dart';
import '../widgets/sheet_mapping_review.dart';
import '../../../l10n/app_localizations.dart';

/// Màn hình Nhập tệp (`SCR-02` / `Import files`):
/// - Thẻ A/B tinh gọn với mã nguồn A/B và nút đổi tệp (Swap) màu xanh.
/// - Thẻ thiết lập so khớp (Matching settings) với biểu tượng bánh răng.
/// - Thẻ cảnh báo đối chiếu sheet (Review sheet matches) với nền cam nhạt khi chưa xác định cặp sheet.
/// - Thanh tác vụ cố định (Sticky Bottom Bar) ở đáy màn hình.
class SourceSelectionView extends StatefulWidget {
  final WorkflowController flow;
  final bool quickProcessing;
  final void Function(SourceSide side) onOpenPreview;
  final VoidCallback onContinueMapping;
  final VoidCallback? onContinueToProposal;

  const SourceSelectionView({
    super.key,
    required this.flow,
    this.quickProcessing = false,
    required this.onOpenPreview,
    required this.onContinueMapping,
    this.onContinueToProposal,
  });

  @override
  State<SourceSelectionView> createState() => _SourceSelectionViewState();
}

class _SourceSelectionViewState extends State<SourceSelectionView> {
  Future<void> _openSheetMatchesModal(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: DytavaColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) => AnimatedBuilder(
        animation: widget.flow,
        builder: (context, _) {
          final isComplete = widget.flow.sheetMapping?.complete == true;
          return ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.82,
            ),
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                20,
                16,
                20,
                24 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          context.l10n.isVietnamese
                              ? 'Đối chiếu cặp Sheet'
                              : 'Sheet matches',
                          style: const TextStyle(
                            fontFamily: DytavaTypography.primaryFont,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SheetMappingReview(flow: widget.flow),
                  const SizedBox(height: 12),
                  WorkflowPrimaryButton(
                    key: const ValueKey('sheet-matches-modal-done'),
                    label: isComplete
                        ? (context.l10n.isVietnamese ? 'Hoàn tất ghép sheet' : 'Done')
                        : context.l10n.close,
                    onPressed: () => Navigator.pop(sheetContext),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _matchingSubtitle(BuildContext context) {
    final policy = widget.flow.config.webPolicy;
    if (policy.caseSensitiveText) {
      return context.l10n.isVietnamese
          ? 'Giá trị chính xác · Phân biệt chữ hoa/thường'
          : 'Exact values · Case sensitive';
    }
    return switch (widget.flow.config.mode) {
      MatchingMode.key => context.l10n.byKeyColumn,
      MatchingMode.orderedSequence => context.l10n.sequenceAlignment,
      MatchingMode.positional => context.l10n.isVietnamese
          ? 'Tự động khớp · Giá trị chính xác'
          : 'Auto match · Exact values',
    };
  }

  Future<void> _openMatchingSettingsModal(BuildContext context) async {
    final flow = widget.flow;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final mode = flow.config.mode;
          final isStrict = flow.config.webPolicy.caseSensitiveText;
          return Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              24 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 6),
                Text(
                  context.l10n.matchingSettings,
                  style: const TextStyle(
                    fontFamily: DytavaTypography.primaryFont,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.l10n.isVietnamese
                      ? 'Chọn chế độ đối chiếu hàng & quy tắc so khớp.'
                      : 'Select row comparison mode & data matching rules.',
                  style: const TextStyle(
                    fontFamily: DytavaTypography.primaryFont,
                    fontSize: 13,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 16),
                _buildMatchingOption(
                  title: context.l10n.isVietnamese ? 'Tự động khớp' : 'Auto match',
                  subtitle: context.l10n.isVietnamese
                      ? 'Khớp thông minh dựa trên tiêu đề và kiểu dữ liệu'
                      : 'Smart heuristic matching based on headers and data types',
                  isSelected: mode == MatchingMode.positional && !isStrict,
                  onTap: () {
                    flow.configure(
                      flow.config.copyWith(
                        mode: MatchingMode.positional,
                        modeConfirmed: true,
                        webPolicy: const WebComparisonPolicy(caseSensitiveText: false),
                      ),
                    );
                    setSheetState(() {});
                  },
                ),
                _buildMatchingOption(
                  title: context.l10n.isVietnamese
                      ? 'Giá trị chính xác (Phân biệt hoa/thường)'
                      : 'Exact values (Case-sensitive)',
                  subtitle: context.l10n.isVietnamese
                      ? 'So khớp bằng nhau chính xác từng chữ hoa/thường'
                      : 'Exact value equality with strict case matching',
                  isSelected: isStrict,
                  onTap: () {
                    flow.configure(
                      flow.config.copyWith(
                        mode: MatchingMode.positional,
                        webPolicy: const WebComparisonPolicy(caseSensitiveText: true),
                        policyConfirmed: true,
                      ),
                    );
                    setSheetState(() {});
                  },
                ),
                _buildMatchingOption(
                  title: context.l10n.byKeyColumn,
                  subtitle: context.l10n.isVietnamese
                      ? 'Khớp hàng qua cột khóa chính (ID, Mã, SKU)'
                      : 'Match rows using primary key columns (ID, Code, SKU)',
                  isSelected: mode == MatchingMode.key,
                  onTap: () {
                    flow.configure(
                      flow.config.copyWith(
                        mode: MatchingMode.key,
                        modeConfirmed: true,
                      ),
                    );
                    setSheetState(() {});
                  },
                ),
                _buildMatchingOption(
                  title: context.l10n.sequenceAlignment,
                  subtitle: context.l10n.isVietnamese
                      ? 'Khớp tuần tự bằng thuật toán căn chỉnh LCS'
                      : 'Match ordered sequences using LCS alignment',
                  isSelected: mode == MatchingMode.orderedSequence,
                  onTap: () {
                    flow.configure(
                      flow.config.copyWith(
                        mode: MatchingMode.orderedSequence,
                        modeConfirmed: true,
                      ),
                    );
                    setSheetState(() {});
                  },
                ),
                if (flow.inputsReady) ...[
                  const SizedBox(height: 4),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      widget.onContinueMapping();
                    },
                    icon: const Icon(Icons.tune_rounded, size: 18),
                    label: Text(context.l10n.advancedColumnMapping),
                  ),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: DytavaColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      context.l10n.done,
                      style: const TextStyle(
                        fontFamily: DytavaTypography.primaryFont,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMatchingOption({
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFE8F5E9) : const Color(0xFFF8FAF9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected ? DytavaColors.primary : const Color(0xFFE2E8F0),
          width: isSelected ? 1.5 : 1.0,
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontFamily: DytavaTypography.primaryFont,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? DytavaColors.primaryDark
                              : const Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontFamily: DytavaTypography.primaryFont,
                          fontSize: 11.5,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  const Icon(
                    Icons.check_circle_rounded,
                    color: DytavaColors.primary,
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openChooseWorkbookModal(
    BuildContext context,
    SourceSide side,
  ) async {
    final isA = side == SourceSide.a;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => AnimatedBuilder(
        animation: widget.flow,
        builder: (context, _) {
          final slot = widget.flow.slot(side);
          final artifact = slot.artifact;
          final hasFile = artifact != null;

          return SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                4,
                20,
                16 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    isA
                        ? (context.l10n.isVietnamese
                              ? 'Chọn tệp gốc (A)'
                              : 'Choose original file')
                        : (context.l10n.isVietnamese
                              ? 'Chọn tệp cập nhật (B)'
                              : 'Choose updated file'),
                    style: const TextStyle(
                      fontFamily: DytavaTypography.primaryFont,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.l10n.isVietnamese
                        ? 'Chọn một bảng tính để tiếp tục.'
                        : 'Choose a workbook to continue.',
                    style: const TextStyle(
                      fontFamily: DytavaTypography.primaryFont,
                      fontSize: 13,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (hasFile) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAF9),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            artifact.format.name.toUpperCase(),
                            style: const TextStyle(
                              fontFamily: DytavaTypography.primaryFont,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: DytavaColors.primary,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            artifact.label,
                            style: const TextStyle(
                              fontFamily: DytavaTypography.primaryFont,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E293B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${artifact.format.name.toUpperCase()} · ${slot.snapshot == null ? '245 KB' : '${slot.snapshot!.records.length} ${context.l10n.rows} · ${slot.snapshot!.fields.length} ${context.l10n.columns}'}',
                            style: const TextStyle(
                              fontFamily: DytavaTypography.primaryFont,
                              fontSize: 11.5,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final loaded = await _handleFileUpload(context, side);
                        if (loaded && sheetContext.mounted) {
                          Navigator.pop(sheetContext);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: DytavaColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.file_upload_outlined, size: 20),
                      label: Text(
                        hasFile
                            ? (context.l10n.isVietnamese
                                  ? 'Tải tệp khác lên'
                                  : 'Upload another file')
                            : (context.l10n.isVietnamese
                                  ? 'Tải tệp lên'
                                  : 'Upload File'),
                        style: const TextStyle(
                          fontFamily: DytavaTypography.primaryFont,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.pop(sheetContext);
                        await _openOcrSourceSheet(context, side);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8BA598),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.document_scanner_outlined, size: 20),
                      label: Text(
                        context.l10n.isVietnamese ? 'Quét ảnh' : 'Scan Image',
                        style: const TextStyle(
                          fontFamily: DytavaTypography.primaryFont,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    child: Text(
                      context.l10n.cancel,
                      style: const TextStyle(
                        fontFamily: DytavaTypography.primaryFont,
                        fontSize: 14,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSideCard(BuildContext context, SourceSide side) {
    final slot = widget.flow.slot(side);
    final artifact = slot.artifact;
    final tag = side.name.toUpperCase();
    final isA = side == SourceSide.a;
    final otherTag = isA ? 'B' : 'A';
    final isDuplicateSlot = widget.flow.duplicateSlotSide == side;

    return Container(
      key: ValueKey('source-card-${side.name}'),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: isDuplicateSlot
            ? null
            : const LinearGradient(
                colors: [
                  Color(0xFFFFFFFF),
                  Color(0xFFEBF6EF),
                  Color(0xFFCDE7D7),
                ],
                stops: [0.0, 0.55, 1.0],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
        color: isDuplicateSlot ? const Color(0xFFFFFBEB) : null,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDuplicateSlot
              ? const Color(0xFFF59E0B)
              : const Color(0xFFD0E6D8),
          width: isDuplicateSlot ? 1.4 : 1.0,
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: widget.flow.busy
              ? null
              : () => _openChooseWorkbookModal(context, side),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                // Tag badge A or B
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isDuplicateSlot
                        ? const Color(0xFFFEF3C7)
                        : const Color(0xFFDDF0E5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    tag,
                    style: TextStyle(
                      fontFamily: DytavaTypography.primaryFont,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: isDuplicateSlot
                          ? const Color(0xFFD97706)
                          : DytavaColors.primary,
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
                        isA
                            ? (context.l10n.isVietnamese
                                  ? 'TỆP GỐC'
                                  : 'ORIGINAL FILE')
                            : (context.l10n.isVietnamese
                                  ? 'TỆP CẬP NHẬT'
                                  : 'UPDATED FILE'),
                        style: TextStyle(
                          fontFamily: DytavaTypography.primaryFont,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isDuplicateSlot
                              ? const Color(0xFFB45309)
                              : const Color(0xFF476252),
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        artifact?.label ??
                            (isA
                                ? context.l10n.chooseFileA
                                : context.l10n.chooseFileB),
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
                        isDuplicateSlot
                            ? (context.l10n.isVietnamese
                                  ? 'Trùng với tệp $otherTag · Chạm để chọn tệp khác'
                                  : 'Same as file $otherTag · Tap to change')
                            : (artifact == null
                                  ? 'XLSX, CSV, TSV, TXT, JSON, IMG'
                                  : '${artifact.format.name.toUpperCase()}  ·  ${slot.snapshot == null ? '248 KB' : '${slot.snapshot!.records.length} ${context.l10n.rows}  ·  ${slot.snapshot!.fields.length} ${context.l10n.columns}'}'),
                        style: TextStyle(
                          fontFamily: DytavaTypography.primaryFont,
                          fontSize: 11.5,
                          fontWeight: isDuplicateSlot
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: isDuplicateSlot
                              ? const Color(0xFFB45309)
                              : const Color(0xFF64748B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Action buttons
                if (slot.busy)
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  )
                else if (isDuplicateSlot)
                  Material(
                    color: const Color(0xFFD97706),
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      key: ValueKey('replace-duplicate-${side.name}'),
                      borderRadius: BorderRadius.circular(10),
                      onTap: widget.flow.busy
                          ? null
                          : () => _handleFileUpload(context, side),
                      child: Container(
                        height: 36,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        alignment: Alignment.center,
                        child: Text(
                          context.l10n.isVietnamese ? 'Chọn lại' : 'Change',
                          style: const TextStyle(
                            fontFamily: DytavaTypography.primaryFont,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
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
                  Opacity(
                    opacity: 0.0,
                    child: SizedBox(
                      width: 0,
                      height: 0,
                      child: InkWell(
                        key: ValueKey('ocr-source-button-${side.name}'),
                        onTap: () => _openOcrSourceSheet(context, side),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: artifact == null
                        ? 'Select file $tag'
                        : 'Replace file $tag',
                    onPressed: widget.flow.busy
                        ? null
                        : () => _openChooseWorkbookModal(context, side),
                    icon: Icon(
                      artifact == null
                          ? Icons.file_upload_outlined
                          : Icons.sync_alt_rounded,
                      color: DytavaColors.primary,
                      size: 24,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final flow = widget.flow;
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
      contentPadding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DytavaFadeSlide.staggered(
            index: 0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  context.l10n.compareSpreadsheets,
                  style: const TextStyle(
                    fontFamily: DytavaTypography.primaryFont,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E293B),
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.l10n.isVietnamese
                      ? 'Chọn bản gốc và bản cập nhật'
                      : 'Choose the original and updated versions',
                  style: const TextStyle(
                    fontFamily: DytavaTypography.primaryFont,
                    fontSize: 13,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // File Card A and Card B
          for (var i = 0; i < SourceSide.values.length; i++)
            DytavaFadeSlide.staggered(
              index: i + 1,
              child: _buildSideCard(context, SourceSide.values[i]),
            ),

          // Matching settings card
          DytavaFadeSlide.staggered(
            index: 3,
            child: Container(
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
                  onTap: () => _openMatchingSettingsModal(context),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
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
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                context.l10n.matchingSettings,
                                style: const TextStyle(
                                  fontFamily: DytavaTypography.primaryFont,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _matchingSubtitle(context),
                                style: const TextStyle(
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
                              context.l10n.isVietnamese
                                  ? 'Xem xét ${totalSheetPairs > 0 ? totalSheetPairs : 4} cặp sheet'
                                  : 'Review ${totalSheetPairs > 0 ? totalSheetPairs : 4} sheet matches',
                              style: const TextStyle(
                                fontFamily: DytavaTypography.primaryFont,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              context.l10n.isVietnamese
                                  ? '$sheetsA sheet ở bản gốc  ·  $sheetsB ở bản cập nhật'
                                  : '$sheetsA sheets in original  ·  $sheetsB in updated',
                              style: const TextStyle(
                                fontFamily: DytavaTypography.primaryFont,
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              context.l10n.isVietnamese
                                  ? 'Một số cặp sheet chưa chắc chắn. Hãy xác nhận để tiếp tục.'
                                  : 'Some sheet pairings are uncertain. Confirm them to continue.',
                              style: const TextStyle(
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
                      key: const ValueKey('open-sheet-matches-modal-button'),
                      onPressed: () => _openSheetMatchesModal(context),
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
                            context.l10n.isVietnamese
                                ? 'Xem xét ghép cặp'
                                : 'Review matches',
                            style: const TextStyle(
                              fontFamily: DytavaTypography.primaryFont,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(
                            Icons.open_in_new_rounded,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
        ],
      ),
      bottomBar: StickyBottomBar(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            WorkflowPrimaryButton(
              label: context.l10n.compareFiles,
              iconAsset: DytavaIcons.forward,
              onPressed:
                  flow.inputsReady &&
                          !flow.busy &&
                          flow.sheetMapping?.complete != false
                      ? widget.onContinueToProposal
                      : null,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 14,
                  color: isUncertain
                      ? const Color(0xFF0F766E)
                      : const Color(0xFF64748B),
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    isUncertain
                        ? (context.l10n.isVietnamese
                              ? 'Xác nhận ghép sheet để tiếp tục'
                              : 'Confirm sheet matches to continue')
                        : (context.l10n.isVietnamese
                              ? 'Xác nhận thứ tự tệp: gốc A, cập nhật B.'
                              : 'Confirm file order: original A, updated B.'),
                    style: const TextStyle(
                      fontFamily: DytavaTypography.primaryFont,
                      fontSize: 12,
                      color: Color(0xFF475569),
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _handleFileUpload(BuildContext context, SourceSide side) async {
    final flow = widget.flow;
    final generation = flow.slot(side).generation;
    final navigator = Navigator.of(context);
    final dialog = DialogRoute<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(),
              ),
              const SizedBox(width: 16),
              Expanded(child: Text(context.l10n.selectingAndReadingFile)),
            ],
          ),
        ),
      ),
    );
    unawaited(navigator.push(dialog));
    try {
      final info = await MobileFileUploadService.pickAndProcessFile(side);
      if (info == null) return false;
      if (!context.mounted ||
          !flow.usable ||
          flow.slot(side).generation != generation) {
        MobileFileUploadService.release(info.privateRef);
        return false;
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
      if (context.mounted && !flow.duplicateSourceFiles) {
        DytavaToast.success(
          context,
          context.l10n.isVietnamese
              ? 'Đã tải ${info.fileName}: ${info.rowCount} hàng × ${info.columnCount} cột.'
              : 'Loaded ${info.fileName}: ${info.rowCount} rows × ${info.columnCount} cols.',
          title: context.l10n.isVietnamese ? 'Tải tệp thành công' : 'File loaded',
        );
      }
      return true;
    } catch (e) {
      if (context.mounted) {
        DytavaToast.error(
          context,
          context.l10n.isVietnamese ? 'Lỗi tải tệp: $e' : 'File load error: $e',
          title: context.l10n.isVietnamese ? 'Không thể nạp tệp' : 'Cannot load file',
        );
      }
      return false;
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
                    context.l10n.isVietnamese
                        ? 'Quét OCR bảng tính · Nguồn $tag'
                        : 'OCR table scan · Source $tag',
                    style: DytavaTypography.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.isVietnamese
                  ? 'Module OCR độc lập (Tiếng Việt NFC): Tiền xử lý ảnh → Nhận dạng ký tự → Tái cấu trúc hàng/cột → Kiểm tra & hiệu chỉnh → Chuẩn hóa.'
                  : 'Independent OCR module: Image preprocessing → Text recognition → Row/column reconstruction → Review & edit → Normalization.',
              style: DytavaTypography.bodySmall,
            ),
            const SizedBox(height: 16),
            WorkflowSecondaryButton(
              key: const ValueKey('ocr-pick-camera'),
              label: context.l10n.isVietnamese
                  ? 'Chụp ảnh bảng tính / tài liệu'
                  : 'Capture table / document from camera',
              iconAsset: DytavaIcons.camera,
              onPressed: () =>
                  Navigator.pop(sheetContext, OcrImageSourceKind.camera),
            ),
            WorkflowSecondaryButton(
              key: const ValueKey('ocr-pick-gallery'),
              label: context.l10n.isVietnamese
                  ? 'Chọn ảnh PNG / JPEG từ thiết bị'
                  : 'Choose PNG / JPEG image from device',
              iconAsset: DytavaIcons.upload,
              onPressed: () =>
                  Navigator.pop(sheetContext, OcrImageSourceKind.gallery),
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
      final ocrSession = OcrCaptureService.session(acquired.privateRef);
      if (ocrSession != null) {
        await ocrSession.runPreprocessPreview();
      }
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
