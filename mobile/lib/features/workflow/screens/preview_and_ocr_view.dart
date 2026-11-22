import 'dart:async';

import 'package:flutter/material.dart';

import '../../../application/workflow_controller.dart';
import '../../../design_system/design_system.dart';
import '../../../domain/workflow.dart';
import '../../../infrastructure/file_upload_service.dart';
import '../../../ocr/domain/ocr_models.dart';
import '../../../ocr/domain/ocr_session.dart';
import '../../../ocr/domain/vietnamese_text.dart';
import '../../../ocr/infrastructure/ocr_capture_service.dart';
import '../widgets/workflow_common_widgets.dart';

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
    final snapshot = source.snapshot;
    final info = source.artifact == null
        ? null
        : MobileFileUploadService.info(source.artifact!.privateRef);
    return WorkflowScreenLayout(
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'INPUT / ${source.side == SourceSide.a ? '01' : '02'}',
            style: DytavaTypography.labelSmall.copyWith(
              color: DytavaColors.primary,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Check your workbooks',
            style: DytavaTypography.displayMedium,
          ),
          const SizedBox(height: 12),
          const Text(
            'Preview values and types before comparing.',
            style: DytavaTypography.bodyMedium,
          ),
          const SizedBox(height: 16),
          WorkflowSectionCard(
            children: [
              for (final side in SourceSide.values) ...[
                Text(
                  '${side.name.toUpperCase()}  ${flow.slot(side).artifact?.label ?? 'No file selected'}',
                  style: DytavaTypography.titleSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  flow.slot(side).snapshot == null
                      ? 'Awaiting import'
                      : '${flow.slot(side).snapshot!.records.length} rows · ${flow.slot(side).snapshot!.fields.length} columns',
                  style: DytavaTypography.bodySmall,
                ),
                if (side == SourceSide.a) const SizedBox(height: 12),
              ],
            ],
          ),
          if (info != null && info.sheets.length > 1) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final sheet in info.sheets)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(sheet),
                        selected:
                            (snapshot?.sheetName ?? info.sheetName) == sheet,
                        onSelected: source.busy
                            ? null
                            : (_) => _sheet(source, sheet),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (source.issue != null) WorkflowIssueList(issues: [source.issue!]),
          if (snapshot != null)
            WorkflowSectionCard(
              children: [
                Text(
                  '${snapshot.sheetName ?? 'Sheet'} · ${source.side == SourceSide.a ? 'Original / A' : 'Updated / B'}',
                  style: DytavaTypography.titleSmall,
                ),
                const SizedBox(height: 10),
                Text(
                  '${snapshot.records.length} rows · ${snapshot.fields.length} columns',
                  style: DytavaTypography.bodySmall,
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowHeight: 36,
                    dataRowMinHeight: 36,
                    dataRowMaxHeight: 56,
                    horizontalMargin: 0,
                    columnSpacing: 24,
                    columns: [
                      for (final field in snapshot.fields)
                        DataColumn(
                          label: Text(
                            field.label,
                            style: DytavaTypography.labelSmall,
                          ),
                        ),
                    ],
                    rows: [
                      for (final row in snapshot.records.take(5))
                        DataRow(
                          cells: [
                            for (final field in snapshot.fields)
                              DataCell(
                                ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 180,
                                  ),
                                  child: Text(
                                    row.cells[field.id]?.rawLexeme ?? '—',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: DytavaTypography.dataSmall,
                                  ),
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Previewing ${snapshot.records.length.clamp(0, 5)} of ${snapshot.records.length} rows.',
                  style: DytavaTypography.bodySmall,
                ),
              ],
            ),
          const SizedBox(height: 20),
          WorkflowSectionCard(
            color: DytavaColors.primaryLight,
            border: Border.all(color: Colors.transparent),
            children: const [
              Text('Quick Compare', style: DytavaTypography.titleSmall),
              SizedBox(height: 8),
              Text(
                'Auto-detects sheet pairs, columns and row keys.',
                style: DytavaTypography.bodyMedium,
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
      bottomBar: StickyBottomBar(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (source.busy) ...[
              const LinearProgressIndicator(),
              TextButton(
                onPressed: source.cancelling
                    ? null
                    : () => flow.cancelImport(source.side),
                child: const Text('Cancel import'),
              ),
            ],
            if (source.state == InputState.selected ||
                source.state == InputState.failed ||
                source.state == InputState.cancelled)
              WorkflowPrimaryButton(
                label: 'Read and validate file',
                onPressed: () => flow.importSource(source.side),
              ),
            if (source.state == InputState.needsReview)
              WorkflowPrimaryButton(
                label: source.review!.cells.isEmpty
                    ? 'Confirm range and header'
                    : 'Review recognition',
                onPressed: source.review!.cells.isEmpty
                    ? () => flow.confirmImport(
                        source.side,
                        expectedBinding: source.binding,
                      )
                    : onOpenOcrReview,
              ),
            WorkflowSecondaryButton(
              label: 'Back to import files',
              iconAsset: DytavaIcons.back,
              onPressed: source.busy ? null : onBackToSources,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sheet(SourceSlot source, String name) async {
    if (flow.hasWorkbook && flow.inputsReady) {
      flow.selectWorkbookPreview(source.side, name);
      return;
    }
    final artifact = source.artifact!;
    MobileFileUploadService.selectSheet(artifact.privateRef, name);
    await flow.selectSource(
      source.side,
      artifact.format,
      artifact.privateRef,
      artifact.label,
    );
    await flow.importSource(source.side);
    final current = flow.slot(source.side);
    if (current.state == InputState.needsReview &&
        current.review!.cells.isEmpty) {
      await flow.confirmImport(source.side, expectedBinding: current.binding);
    }
  }
}

/// OCR Review & Table Structure Verification Screen (`SCR-04` / `OcrReviewScreenView`).
///
/// Built strictly with the mobile visual language (`WorkflowScreenLayout`,
/// `WorkflowSectionCard`, `StickyBottomBar`, `WorkflowPrimaryButton`,
/// `DytavaColors`, `DytavaTypography`).
///
/// Supports two flows:
/// 1. Full 6-step OCR session (`OcrCaptureService.session(privateRef)`):
///    - Tiền xử lý ảnh (xoay 90°, cắt & hiệu chỉnh phối cảnh 4 góc, tăng tương phản)
///    - Nhận dạng ký tự (OCR) hỗ trợ tiếng Việt có dấu (NFC)
///    - Tái cấu trúc hàng, cột và ô dữ liệu + xác nhận cấu trúc lưới trước
///    - Người dùng kiểm tra, hiệu chỉnh văn bản tiếng Việt và cấp receipt từng ô
///    - Chuẩn hóa dữ liệu → Comparison Engine
/// 2. Legacy fixture recognition review (`fixture:image-a`) for existing unit tests.
class OcrReviewScreenView extends StatelessWidget {
  final WorkflowController flow;
  final Set<String> reviewedCells;
  final ValueChanged<String> onToggleCell;
  final VoidCallback onReviewAll;
  final VoidCallback? onConfirmReviewed;
  final VoidCallback? onFinalizedSession;

  const OcrReviewScreenView({
    super.key,
    required this.flow,
    required this.reviewedCells,
    required this.onToggleCell,
    required this.onReviewAll,
    required this.onConfirmReviewed,
    this.onFinalizedSession,
  });

  @override
  Widget build(BuildContext context) {
    final source = flow.slot(flow.activeSide);
    final privateRef = source.artifact?.privateRef ?? '';
    final session = OcrCaptureService.session(privateRef);
    if (session != null) {
      return _OcrPipelineInteractiveView(
        flow: flow,
        source: source,
        session: session,
        onFinalized: onFinalizedSession,
      );
    }
    return _buildFixtureReview(context, source);
  }

  Widget _buildFixtureReview(BuildContext context, SourceSlot source) {
    final cells = source.review?.cells ?? const <ReviewCell>[];
    final allReviewed =
        cells.isNotEmpty && cells.every((c) => reviewedCells.contains(c.id));
    return WorkflowScreenLayout(
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Check before importing.',
            style: DytavaTypography.displayMedium,
          ),
          const SizedBox(height: 12),
          Text(
            source.artifact?.label ?? 'Sample image',
            style: DytavaTypography.bodyMedium,
          ),
          const SizedBox(height: 16),
          WorkflowSectionCard(
            color: DytavaColors.modifiedBg,
            border: Border.all(color: Colors.transparent),
            children: const [
              Text('Sample OCR review', style: DytavaTypography.titleSmall),
              SizedBox(height: 8),
              Text(
                'This sample tests the review flow. Every uncertain value must be confirmed before comparison.',
                style: DytavaTypography.bodySmall,
              ),
            ],
          ),
          Text(
            '${cells.length - reviewedCells.length} cells need review',
            style: DytavaTypography.titleSmall.copyWith(
              color: DytavaColors.modified,
            ),
          ),
          const SizedBox(height: 16),
          for (final cell in cells)
            WorkflowSectionCard(
              children: [
                Text(cell.id, style: DytavaTypography.titleSmall),
                const SizedBox(height: 8),
                Text(
                  'Recognized text: ${cell.recognizedText}',
                  style: DytavaTypography.bodyMedium,
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: reviewedCells.contains(cell.id),
                  onChanged: (_) => onToggleCell(cell.id),
                  title: const Text(
                    'Confirm this value',
                    style: DytavaTypography.titleSmall,
                  ),
                ),
              ],
            ),
          const SizedBox(height: 16),
        ],
      ),
      bottomBar: StickyBottomBar(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Uncertain cells must be confirmed before import.',
              style: DytavaTypography.bodySmall,
            ),
            const SizedBox(height: 8),
            WorkflowPrimaryButton(
              label: allReviewed
                  ? 'Import reviewed values'
                  : 'Confirm ${cells.length - reviewedCells.length} cells to continue',
              onPressed: allReviewed ? onConfirmReviewed : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _OcrPipelineInteractiveView extends StatefulWidget {
  final WorkflowController flow;
  final SourceSlot source;
  final OcrSession session;
  final VoidCallback? onFinalized;

  const _OcrPipelineInteractiveView({
    required this.flow,
    required this.source,
    required this.session,
    this.onFinalized,
  });

  @override
  State<_OcrPipelineInteractiveView> createState() =>
      _OcrPipelineInteractiveViewState();
}

class _OcrPipelineInteractiveViewState
    extends State<_OcrPipelineInteractiveView> {
  /// Perspective preset: 0 = Full image, 1 = Trim 6% margins, 2 = Top-skewed rectification
  int _perspectivePreset = 0;

  @override
  void initState() {
    super.initState();
    if (widget.session.processed == null && !widget.session.busy) {
      unawaited(widget.session.runPreprocessPreview());
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        return WorkflowScreenLayout(
          contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildModuleHeader(session),
              const SizedBox(height: 12),
              _buildStepProgressPills(session),
              const SizedBox(height: 12),
              if (session.error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: WorkflowInfoBanner(
                    text: session.error!,
                    iconAsset: DytavaIcons.error,
                    color: DytavaColors.different,
                    bgColor: DytavaColors.softRed,
                  ),
                ),
              switch (session.stage) {
                OcrPipelineStage.preprocess ||
                OcrPipelineStage.recognizing =>
                  _buildPreprocessStage(context, session),
                OcrPipelineStage.gridStructure =>
                  _buildGridStructureStage(context, session),
                OcrPipelineStage.cellReview =>
                  _buildCellReviewStage(context, session),
              },
            ],
          ),
          bottomBar: _buildBottomBar(context, session),
        );
      },
    );
  }

  Widget _buildModuleHeader(OcrSession session) {
    final tag = widget.source.side.name.toUpperCase();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: DytavaColors.primaryLight,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'MODULE OCR · NGUỒN $tag',
                style: const TextStyle(
                  fontFamily: DytavaTypography.primaryFont,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: DytavaColors.primary,
                  letterSpacing: 0.4,
                ),
              ),
            ),
            WorkflowStatusPill(
              label: 'Tiếng Việt NFC',
              color: DytavaColors.primaryDark,
              bg: DytavaColors.primaryLight,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          switch (session.stage) {
            OcrPipelineStage.preprocess ||
            OcrPipelineStage.recognizing =>
              'Tiền xử lý ảnh bảng tính',
            OcrPipelineStage.gridStructure =>
              'Tái cấu trúc hàng, cột và ô',
            OcrPipelineStage.cellReview =>
              'Kiểm tra và hiệu chỉnh ô dữ liệu',
          },
          style: const TextStyle(
            fontFamily: DytavaTypography.primaryFont,
            fontSize: 21,
            fontWeight: FontWeight.w800,
            color: DytavaColors.textPrimary,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          session.label,
          style: DytavaTypography.bodySmall.copyWith(
            color: DytavaColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildStepProgressPills(OcrSession session) {
    final activeStep = switch (session.stage) {
      OcrPipelineStage.preprocess || OcrPipelineStage.recognizing => 0,
      OcrPipelineStage.gridStructure => 1,
      OcrPipelineStage.cellReview => 2,
    };
    const labels = [
      '1. Tiền xử lý & OCR',
      '2. Cấu trúc bảng',
      '3. Duyệt ô & Chuẩn hóa',
    ];
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: DytavaColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: DytavaColors.subtleBorder),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                decoration: BoxDecoration(
                  color: i == activeStep
                      ? DytavaColors.primary
                      : (i < activeStep
                            ? DytavaColors.primaryLight
                            : Colors.transparent),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  labels[i],
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: DytavaTypography.primaryFont,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: i == activeStep
                        ? DytavaColors.white
                        : (i < activeStep
                              ? DytavaColors.primaryDark
                              : DytavaColors.textSecondary),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ===========================================================================
  // STAGE 1: Tiền xử lý ảnh (Cắt, xoay, tăng tương phản, hiệu chỉnh phối cảnh)
  // ===========================================================================

  Widget _buildPreprocessStage(BuildContext context, OcrSession session) {
    final processed = session.processed;
    final settings = session.settings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WorkflowSectionCard(
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Xem trước ảnh dẫn xuất',
                    style: DytavaTypography.titleSmall,
                  ),
                ),
                if (processed != null)
                  Text(
                    '${processed.geometry.outputWidth}×${processed.geometry.outputHeight} px',
                    style: DytavaTypography.bodySmall,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              height: 170,
              decoration: BoxDecoration(
                color: DytavaColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: DytavaColors.subtleBorder),
              ),
              alignment: Alignment.center,
              clipBehavior: Clip.antiAlias,
              child: session.busy && processed == null
                  ? const CircularProgressIndicator()
                  : (processed != null
                        ? Image.memory(
                            processed.pngBytes,
                            fit: BoxFit.contain,
                            gaplessPlayback: true,
                          )
                        : const BrandIllustration(
                            DytavaIllustrations.processingOcr,
                            size: 96,
                          )),
            ),
            const SizedBox(height: 12),
            const Text(
              'Ảnh gốc được giữ nguyên (read-only). Phép biến đổi nghịch đảo lưu ánh xạ tọa độ pixel về ảnh định hướng gốc.',
              style: DytavaTypography.bodySmall,
            ),
          ],
        ),
        WorkflowSectionCard(
          children: [
            const Text(
              'Công cụ tiền xử lý',
              style: DytavaTypography.titleSmall,
            ),
            const SizedBox(height: 12),
            // Rotation controls
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Góc xoay ảnh',
                    style: DytavaTypography.bodyMedium,
                  ),
                ),
                OutlinedButton.icon(
                  key: const ValueKey('ocr-rotate-button'),
                  onPressed: session.busy
                      ? null
                      : () => session.updatePreprocess(
                          settings.copyWith(
                            quarterTurns: (settings.quarterTurns + 1) % 4,
                            clearCorners: true,
                          ),
                        ),
                  icon: const Icon(Icons.rotate_90_degrees_cw_outlined, size: 18),
                  label: Text('${(settings.quarterTurns % 4) * 90}°'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Perspective & crop presets
            const Text(
              'Cắt & hiệu chỉnh phối cảnh 4 góc',
              style: DytavaTypography.bodyMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Toàn khung'),
                  selected: _perspectivePreset == 0,
                  onSelected: session.busy
                      ? null
                      : (_) => _applyPerspectivePreset(session, 0),
                ),
                ChoiceChip(
                  key: const ValueKey('ocr-crop-margins-chip'),
                  label: const Text('Cắt viền tài liệu'),
                  selected: _perspectivePreset == 1,
                  onSelected: session.busy
                      ? null
                      : (_) => _applyPerspectivePreset(session, 1),
                ),
                ChoiceChip(
                  key: const ValueKey('ocr-perspective-rectify-chip'),
                  label: const Text('Khử nghiêng phối cảnh'),
                  selected: _perspectivePreset == 2,
                  onSelected: session.busy
                      ? null
                      : (_) => _applyPerspectivePreset(session, 2),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeThumbColor: DytavaColors.primary,
              title: const Text(
                'Tăng tương phản dấu tiếng Việt',
                style: DytavaTypography.bodyMedium,
              ),
              subtitle: const Text(
                'Làm rõ dấu thanh nhỏ (hỏi, ngã, nặng) trên nền giấy chụp.',
                style: DytavaTypography.bodySmall,
              ),
              value: settings.enhanceContrast,
              onChanged: session.busy
                  ? null
                  : (v) => session.updatePreprocess(
                      settings.copyWith(enhanceContrast: v),
                    ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _applyPerspectivePreset(OcrSession session, int preset) async {
    setState(() => _perspectivePreset = preset);
    final geom = session.processed?.geometry;
    if (geom == null || preset == 0) {
      await session.updatePreprocess(
        session.settings.copyWith(clearCorners: true),
      );
      return;
    }
    final rw = geom.rotatedWidth.toDouble();
    final rh = geom.rotatedHeight.toDouble();
    final corners = preset == 1
        ? <OcrPoint>[
            OcrPoint(rw * 0.03, rh * 0.05),
            OcrPoint(rw * 0.97, rh * 0.05),
            OcrPoint(rw * 0.97, rh * 0.95),
            OcrPoint(rw * 0.03, rh * 0.95),
          ]
        : <OcrPoint>[
            OcrPoint(rw * 0.04, rh * 0.04),
            OcrPoint(rw * 0.96, rh * 0.06),
            OcrPoint(rw * 0.98, rh * 0.96),
            OcrPoint(rw * 0.02, rh * 0.94),
          ];
    await session.updatePreprocess(
      session.settings.copyWith(corners: corners),
    );
  }

  // ===========================================================================
  // STAGE 2: Tái cấu trúc hàng, cột và ô dữ liệu (Xác nhận lưới trước)
  // ===========================================================================

  Widget _buildGridStructureStage(BuildContext context, OcrSession session) {
    final grid = session.grid;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WorkflowSectionCard(
          color: DytavaColors.modifiedTint,
          border: Border.all(
            color: DytavaColors.modified.withValues(alpha: 0.35),
          ),
          children: const [
            Text(
              'Lưu ý kỹ thuật: Văn bản ≠ Cấu trúc bảng',
              style: DytavaTypography.titleSmall,
            ),
            SizedBox(height: 6),
            Text(
              'OCR có thể đọc đúng ký tự tiếng Việt nhưng vẫn gán sai vị trí hàng hoặc cột. Hãy kiểm tra và xác nhận cấu trúc lưới trước khi duyệt từng ô.',
              style: DytavaTypography.bodySmall,
            ),
          ],
        ),
        WorkflowSectionCard(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Lưới đề xuất: ${grid.rowCount} hàng × ${grid.columnCount} cột',
                    style: DytavaTypography.titleSmall,
                  ),
                ),
                const SizedBox(width: 8),
                WorkflowStatusPill(
                  label: '${session.tokens.length} cụm từ',
                  color: DytavaColors.primary,
                  bg: DytavaColors.primaryLight,
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Column count adjustment & header row toggle
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Số cột tái cấu trúc',
                    style: DytavaTypography.bodyMedium,
                  ),
                ),
                IconButton(
                  key: const ValueKey('ocr-col-decrease'),
                  tooltip: 'Giảm số cột',
                  onPressed: grid.columnCount > 1
                      ? () => session.reclusterColumns(grid.columnCount - 1)
                      : null,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Text(
                  '${grid.columnCount}',
                  style: DytavaTypography.titleSmall,
                ),
                IconButton(
                  key: const ValueKey('ocr-col-increase'),
                  tooltip: 'Tăng số cột',
                  onPressed: grid.columnCount < 12
                      ? () => session.reclusterColumns(grid.columnCount + 1)
                      : null,
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeThumbColor: DytavaColors.primary,
              title: const Text(
                'Hàng đầu tiên là tiêu đề cột',
                style: DytavaTypography.bodyMedium,
              ),
              value: grid.hasHeader,
              onChanged: session.setHasHeader,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  key: const ValueKey('ocr-add-row'),
                  onPressed: () => session.insertRow(grid.rowCount),
                  icon: const Icon(Icons.playlist_add, size: 18),
                  label: const Text('Thêm hàng'),
                ),
                OutlinedButton.icon(
                  key: const ValueKey('ocr-add-col'),
                  onPressed: () => session.insertColumn(grid.columnCount),
                  icon: const Icon(Icons.view_column_outlined, size: 18),
                  label: const Text('Thêm cột'),
                ),
                if (grid.columnCount > 1)
                  OutlinedButton.icon(
                    key: const ValueKey('ocr-merge-last-cols'),
                    onPressed: () =>
                        session.mergeColumnRight(grid.columnCount - 2),
                    icon: const Icon(Icons.merge_type, size: 18),
                    label: const Text('Gộp 2 cột cuối'),
                  ),
              ],
            ),
          ],
        ),
        // Grid preview table
        WorkflowSectionCard(
          children: [
            const Text(
              'Bố cục hàng / cột trước khi duyệt ô',
              style: DytavaTypography.titleSmall,
            ),
            const SizedBox(height: 10),
            if (grid.rowCount == 0 || grid.columnCount == 0)
              const Text(
                'Không tìm thấy lưới dữ liệu. Hãy quay lại bước tiền xử lý hoặc thêm hàng/cột.',
                style: DytavaTypography.bodySmall,
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowHeight: 38,
                  dataRowMinHeight: 38,
                  dataRowMaxHeight: 58,
                  horizontalMargin: 8,
                  columnSpacing: 18,
                  columns: [
                    const DataColumn(
                      label: Text('#', style: DytavaTypography.labelSmall),
                    ),
                    for (var c = 0; c < grid.columnCount; c++)
                      DataColumn(
                        label: Text(
                          grid.hasHeader && grid.rowCount > 0
                              ? '${session.currentText(OcrCellRef(0, c))} (C${c + 1})'
                              : 'Cột ${c + 1}',
                          style: DytavaTypography.labelSmall,
                        ),
                      ),
                  ],
                  rows: [
                    for (var r = 0; r < grid.rowCount; r++)
                      DataRow(
                        color: WidgetStatePropertyAll(
                          grid.hasHeader && r == 0
                              ? DytavaColors.primaryLight
                              : null,
                        ),
                        cells: [
                          DataCell(
                            Text(
                              grid.hasHeader && r == 0 ? 'Tiêu đề' : 'H${r + 1}',
                              style: DytavaTypography.labelSmall,
                            ),
                          ),
                          for (var c = 0; c < grid.columnCount; c++)
                            DataCell(
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 160),
                                child: Text(
                                  session.currentText(OcrCellRef(r, c)).isEmpty
                                      ? '—'
                                      : session.currentText(OcrCellRef(r, c)),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: DytavaTypography.dataSmall,
                                ),
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }

  // ===========================================================================
  // STAGE 3: Người dùng kiểm tra & hiệu chỉnh từng ô → Chuẩn hóa
  // ===========================================================================

  Widget _buildCellReviewStage(BuildContext context, OcrSession session) {
    final grid = session.grid;
    final pendingCount = session.totalCellCount - session.confirmedCellCount;
    final unflaggedPending = _countUnflaggedPending(session);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WorkflowSectionCard(
          color: pendingCount == 0
              ? DytavaColors.primaryLight
              : DytavaColors.modifiedBg,
          border: Border.all(color: Colors.transparent),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    pendingCount == 0
                        ? 'Đã xác nhận toàn bộ ${session.totalCellCount} ô'
                        : 'Còn $pendingCount / ${session.totalCellCount} ô cần xác nhận',
                    style: DytavaTypography.titleSmall.copyWith(
                      color: pendingCount == 0
                          ? DytavaColors.primaryDark
                          : DytavaColors.modified,
                    ),
                  ),
                ),
                TextButton.icon(
                  key: const ValueKey('ocr-unlock-grid-button'),
                  onPressed: session.unlockGridStructure,
                  icon: const Icon(Icons.grid_on_outlined, size: 16),
                  label: const Text('Sửa lưới'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Mọi chỉnh sửa văn bản đều chuẩn hóa tiếng Việt NFC và làm mới biên nhận (receipt) của ô đó.',
              style: DytavaTypography.bodySmall,
            ),
            if (unflaggedPending > 0) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                key: const ValueKey('ocr-confirm-unflagged-button'),
                onPressed: session.confirmUnflaggedCells,
                icon: const Icon(Icons.verified_outlined, size: 18),
                label: Text('Xác nhận nhanh $unflaggedPending ô không cảnh báo'),
              ),
            ],
          ],
        ),
        for (var r = 0; r < grid.rowCount; r++)
          for (var c = 0; c < grid.columnCount; c++)
            _OcrCellReviewCard(
              key: ValueKey(
                'ocr-cell-${session.extractionRevision}-${session.gridRevision}-$r-$c',
              ),
              session: session,
              ref: OcrCellRef(r, c),
              cell: grid.cells[r][c],
              isHeader: grid.hasHeader && r == 0,
            ),
      ],
    );
  }

  int _countUnflaggedPending(OcrSession session) {
    var count = 0;
    final grid = session.grid;
    for (var r = 0; r < grid.rowCount; r++) {
      for (var c = 0; c < grid.columnCount; c++) {
        final ref = OcrCellRef(r, c);
        if (grid.cells[r][c].risks.isEmpty && !session.isCellConfirmed(ref)) {
          count++;
        }
      }
    }
    return count;
  }

  Widget _buildBottomBar(BuildContext context, OcrSession session) {
    return StickyBottomBar(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: switch (session.stage) {
        OcrPipelineStage.preprocess || OcrPipelineStage.recognizing => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            WorkflowPrimaryButton(
              label: session.busy
                  ? 'Đang nhận dạng & tái cấu trúc…'
                  : 'Nhận dạng ký tự & Tái cấu trúc bảng',
              iconAsset: DytavaIcons.forward,
              onPressed: session.busy ? null : () => session.runRecognition(),
            ),
          ],
        ),
        OcrPipelineStage.gridStructure => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            WorkflowPrimaryButton(
              label:
                  'Xác nhận cấu trúc (${session.grid.rowCount}×${session.grid.columnCount})',
              iconAsset: DytavaIcons.forward,
              onPressed: session.grid.cellCount > 0 && !session.busy
                  ? session.confirmGridStructure
                  : null,
            ),
            WorkflowSecondaryButton(
              label: 'Quay lại tiền xử lý ảnh',
              iconAsset: DytavaIcons.back,
              onPressed: session.busy ? null : session.returnToPreprocess,
            ),
          ],
        ),
        OcrPipelineStage.cellReview => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            WorkflowPrimaryButton(
              label: session.readyToNormalize
                  ? 'Chuẩn hóa dữ liệu → Comparison Engine'
                  : 'Xác nhận còn ${session.totalCellCount - session.confirmedCellCount} ô để tiếp tục',
              iconAsset: DytavaIcons.forward,
              onPressed: session.readyToNormalize && !session.busy
                  ? () => _finalizeAndImport(context)
                  : null,
            ),
          ],
        ),
      },
    );
  }

  Future<void> _finalizeAndImport(BuildContext context) async {
    final artifact = widget.source.artifact;
    if (artifact == null) return;
    try {
      final table = OcrCaptureService.commitFinalized(artifact.privateRef);
      await widget.flow.changeImportConfig(
        widget.source.side,
        ImportConfiguration(
          scopeConfirmed: true,
          ocrRevision: table.gridRevision,
          reviewedCells: {
            for (final e in widget.session.receipts.keys) e.toString(),
          },
        ),
      );
      await widget.flow.importSource(widget.source.side);
      if (context.mounted) {
        DytavaToast.success(
          context,
          'Đã chuẩn hóa ${table.rows.length} hàng × ${table.headers.length} cột sang Comparison Engine.',
          title: 'OCR hoàn tất kiểm tra',
        );
      }
      widget.onFinalized?.call();
    } catch (e) {
      if (context.mounted) {
        DytavaToast.error(
          context,
          '$e',
          title: 'Không thể chuẩn hóa OCR',
        );
      }
    }
  }
}

class _OcrCellReviewCard extends StatefulWidget {
  final OcrSession session;
  final OcrCellRef ref;
  final OcrCell cell;
  final bool isHeader;

  const _OcrCellReviewCard({
    super.key,
    required this.session,
    required this.ref,
    required this.cell,
    required this.isHeader,
  });

  @override
  State<_OcrCellReviewCard> createState() => _OcrCellReviewCardState();
}

class _OcrCellReviewCardState extends State<_OcrCellReviewCard> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.session.currentText(widget.ref),
    );
  }

  @override
  void didUpdateWidget(covariant _OcrCellReviewCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final latest = widget.session.currentText(widget.ref);
    if (VietnameseText.nfc(_controller.text) != latest) {
      _controller.value = TextEditingValue(
        text: latest,
        selection: TextSelection.collapsed(offset: latest.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final confirmed = widget.session.isCellConfirmed(widget.ref);
    final risks = widget.cell.risks;
    final confidence = widget.cell.confidence;
    final hasVietnamese = VietnameseText.hasVietnameseMarks(_controller.text);

    return WorkflowSectionCard(
      padding: const EdgeInsets.all(14),
      border: Border.all(
        color: confirmed
            ? DytavaColors.primary
            : (risks.isNotEmpty
                  ? DytavaColors.unresolved
                  : DytavaColors.subtleBorder),
        width: confirmed ? 1.5 : 1.0,
      ),
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: widget.isHeader
                    ? DytavaColors.primaryLight
                    : DytavaColors.background,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                widget.isHeader
                    ? '${widget.ref} · Tiêu đề'
                    : widget.ref.toString(),
                style: const TextStyle(
                  fontFamily: DytavaTypography.primaryFont,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: DytavaColors.textPrimary,
                ),
              ),
            ),
            if (confidence != null)
              WorkflowStatusPill(
                label: 'Độ tin cậy ${(confidence * 100).round()}%',
                color: confidence >= 0.85
                    ? DytavaColors.primary
                    : DytavaColors.modified,
                bg: confidence >= 0.85
                    ? DytavaColors.primaryLight
                    : DytavaColors.modifiedBg,
              ),
            if (hasVietnamese)
              const WorkflowStatusPill(
                label: 'Dấu TV',
                color: DytavaColors.primaryDark,
                bg: DytavaColors.primaryLight,
              ),
            if (_controller.text.trim().contains(' '))
              TextButton(
                onPressed: () => widget.session.splitCellRight(widget.ref),
                child: const Text(
                  'Tách sang cột phải',
                  style: TextStyle(fontSize: 11.5),
                ),
              ),
          ],
        ),
        if (risks.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final risk in risks)
                WorkflowStatusPill(
                  label: risk.label,
                  color: DytavaColors.modified,
                  bg: DytavaColors.modifiedBg,
                ),
            ],
          ),
        ],
        const SizedBox(height: 8),
        TextField(
          key: ValueKey('ocr-input-${widget.ref}'),
          controller: _controller,
          decoration: InputDecoration(
            labelText: widget.cell.detected
                ? 'Văn bản gốc: ${widget.cell.recognizedText}'
                : 'Ô trống / không phát hiện text (nhập tay nếu có)',
            isDense: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          style: DytavaTypography.bodyMedium,
          onChanged: (val) => widget.session.editCellText(widget.ref, val),
        ),
        const SizedBox(height: 6),
        CheckboxListTile(
          key: ValueKey('ocr-confirm-${widget.ref}'),
          contentPadding: EdgeInsets.zero,
          activeColor: DytavaColors.primary,
          value: confirmed,
          onChanged: (checked) {
            if (checked == true) {
              widget.session.confirmCell(widget.ref);
            } else {
              widget.session.unconfirmCell(widget.ref);
            }
          },
          title: Text(
            confirmed
                ? 'Đã xác nhận giá trị & vị trí ô'
                : 'Xác nhận giá trị & vị trí ô này',
            style: DytavaTypography.titleSmall.copyWith(
              color: confirmed
                  ? DytavaColors.primary
                  : DytavaColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
