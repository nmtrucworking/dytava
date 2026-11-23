import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:excelcompare_core/excelcompare_core.dart';
import 'package:flutter/material.dart';

import '../../../application/workflow_controller.dart';
import '../../../design_system/design_system.dart';
import '../../../domain/workflow.dart';
import '../../../infrastructure/file_upload_service.dart';
import '../../../ocr/domain/ocr_models.dart';
import '../../../ocr/domain/ocr_session.dart';
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
                                  child: Builder(
                                    builder: (_) {
                                      final cellObj = row.cells[field.id];
                                      if (cellObj != null &&
                                          cellObj.kind == CellKind.image &&
                                          cellObj.imageBytes != null &&
                                          cellObj.imageBytes!.isNotEmpty) {
                                        return Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              width: 28,
                                              height: 28,
                                              padding: const EdgeInsets.all(2),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                                border: Border.all(
                                                  color: DytavaColors.border,
                                                ),
                                              ),
                                              child: Image.memory(
                                                Uint8List.fromList(
                                                  cellObj.imageBytes!,
                                                ),
                                                fit: BoxFit.contain,
                                                filterQuality:
                                                    FilterQuality.none,
                                                errorBuilder: (_, _, _) =>
                                                    const Icon(
                                                      Icons.image_outlined,
                                                      size: 16,
                                                    ),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Flexible(
                                              child: Text(
                                                cellObj.imagePlacement ==
                                                        'drawingAnchor'
                                                    ? 'Ảnh thủ công'
                                                    : 'Ảnh trong ô',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: DytavaTypography.dataSmall,
                                              ),
                                            ),
                                          ],
                                        );
                                      }
                                      return Text(
                                        cellObj?.rawLexeme ?? '—',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: DytavaTypography.dataSmall,
                                      );
                                    },
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

/// Mobile-native, touch-first 2-step OCR flow (`SCR-04` / `OcrReviewScreenView`):
///
/// 1. **Chọn vùng bảng (Touch BBox & Pinch-to-Zoom)**:
///    - Full-viewport touch canvas where all crop, scale, pan and rotation
///      interactions are performed directly by touch on the image/frame.
///    - Single primary action: `Quét bảng`.
/// 2. **Kiểm tra bảng (Unified Table Review & 1-Tap Import)**:
///    - Evaluates the 4 business states (`noTextDetected`, `textWithoutTable`,
///      `tableDetected`, `processingFailed`).
///    - When a table is detected, displays a clean native table without per-cell
///      radio buttons or blocking cell counters. Tapping any cell opens a bottom
///      sheet to edit text; tapping `Dùng bảng này` confirms and imports in 1 tap.
class OcrReviewScreenView extends StatelessWidget {
  final WorkflowController flow;
  final Set<String> reviewedCells;
  final ValueChanged<String> onToggleCell;
  final VoidCallback onReviewAll;
  final VoidCallback? onConfirmReviewed;
  final VoidCallback? onFinalizedSession;
  final VoidCallback? onSelectAnotherImage;
  final VoidCallback? onStageChanged;

  const OcrReviewScreenView({
    super.key,
    required this.flow,
    required this.reviewedCells,
    required this.onToggleCell,
    required this.onReviewAll,
    required this.onConfirmReviewed,
    this.onFinalizedSession,
    this.onSelectAnotherImage,
    this.onStageChanged,
  });

  @override
  Widget build(BuildContext context) {
    final source = flow.slot(flow.activeSide);
    final privateRef = source.artifact?.privateRef ?? '';
    final session = OcrCaptureService.session(privateRef);
    if (session != null) {
      return _OcrNativeTaskFlowView(
        flow: flow,
        source: source,
        session: session,
        onFinalized: onFinalizedSession,
        onSelectAnotherImage: onSelectAnotherImage,
        onStageChanged: onStageChanged,
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
            source.artifact?.label ?? 'Bảng tính ảnh',
            style: DytavaTypography.bodyMedium,
          ),
          const SizedBox(height: 16),
          WorkflowSectionCard(
            color: DytavaColors.modifiedBg,
            border: Border.all(color: Colors.transparent),
            children: const [
              Text('Kiểm tra OCR', style: DytavaTypography.titleSmall),
              SizedBox(height: 8),
              Text(
                'Xác nhận các ô cần kiểm tra trước khi tiến hành so sánh.',
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

class _OcrNativeTaskFlowView extends StatefulWidget {
  final WorkflowController flow;
  final SourceSlot source;
  final OcrSession session;
  final VoidCallback? onFinalized;
  final VoidCallback? onSelectAnotherImage;
  final VoidCallback? onStageChanged;

  const _OcrNativeTaskFlowView({
    required this.flow,
    required this.source,
    required this.session,
    this.onFinalized,
    this.onSelectAnotherImage,
    this.onStageChanged,
  });

  @override
  State<_OcrNativeTaskFlowView> createState() => _OcrNativeTaskFlowViewState();
}

class _OcrNativeTaskFlowViewState extends State<_OcrNativeTaskFlowView> {
  /// Normalized `[0, 1]` bounding box for the table region on the image.
  Rect _bbox = const Rect.fromLTRB(0.06, 0.08, 0.94, 0.92);
  int _quarterTurns = 0;
  bool _flipHorizontal = false;
  bool _flipVertical = false;
  final TransformationController _zoomController = TransformationController();
  double _zoomScale = 1.0;

  @override
  void initState() {
    super.initState();
    _quarterTurns = widget.session.settings.quarterTurns;
    _flipHorizontal = widget.session.settings.flipHorizontal;
    _flipVertical = widget.session.settings.flipVertical;
    widget.session.addListener(_notifyStageChange);
    if (widget.session.processed == null && !widget.session.busy) {
      unawaited(widget.session.runPreprocessPreview());
    }
  }

  @override
  void didUpdateWidget(covariant _OcrNativeTaskFlowView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.session, widget.session)) {
      oldWidget.session.removeListener(_notifyStageChange);
      widget.session.addListener(_notifyStageChange);
      _quarterTurns = widget.session.settings.quarterTurns;
      _flipHorizontal = widget.session.settings.flipHorizontal;
      _flipVertical = widget.session.settings.flipVertical;
    }
  }

  @override
  void dispose() {
    _zoomController.dispose();
    widget.session.removeListener(_notifyStageChange);
    super.dispose();
  }

  void _setZoom(double targetScale) {
    final clamped = targetScale.clamp(1.0, 4.0);
    setState(() {
      _zoomScale = clamped;
      _zoomController.value = Matrix4.diagonal3Values(clamped, clamped, 1.0);
    });
  }

  void _applyImageTransform({
    int? quarterTurns,
    bool? flipHorizontal,
    bool? flipVertical,
  }) {
    setState(() {
      if (quarterTurns != null) _quarterTurns = quarterTurns % 4;
      if (flipHorizontal != null) _flipHorizontal = flipHorizontal;
      if (flipVertical != null) _flipVertical = flipVertical;
    });
    unawaited(
      widget.session.updatePreprocess(
        widget.session.settings.copyWith(
          quarterTurns: _quarterTurns,
          flipHorizontal: _flipHorizontal,
          flipVertical: _flipVertical,
          clearCorners: true,
        ),
      ),
    );
  }

  void _notifyStageChange() {
    widget.onStageChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        if (session.busy || session.stage == OcrPipelineStage.recognizing) {
          return _buildLoadingView();
        }
        if (session.stage == OcrPipelineStage.preprocess) {
          return _buildFullViewportBboxView(context, session);
        }
        return _buildUnifiedTableReviewView(context, session);
      },
    );
  }

  // ===========================================================================
  // Loading View
  // ===========================================================================

  Widget _buildLoadingView() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(strokeWidth: 2.6),
            ),
            SizedBox(height: 16),
            Text(
              'Đang quét bảng…',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: DytavaTypography.primaryFont,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: DytavaColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // SCREEN 1: Direct-Manipulation Touch BBox Canvas (No text paragraphs, no buttons for crop/scale)
  // ===========================================================================

  Widget _buildFullViewportBboxView(BuildContext context, OcrSession session) {
    final imageBytes = session.processed?.pngBytes ?? session.rawBytes;
    return LayoutBuilder(
      builder: (context, constraints) {
        final canvasWidget = Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Stack(
            children: [
              Positioned.fill(
                child: _InteractiveTableBboxSelector(
                  key: const ValueKey('ocr-bbox-selector'),
                  imageBytes: imageBytes,
                  bbox: _bbox,
                  zoomController: _zoomController,
                  onChanged: (next) => setState(() => _bbox = next),
                  onRotateGesture: () => _applyImageTransform(
                    quarterTurns: (_quarterTurns + 1) % 4,
                  ),
                ),
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xCC0F172A),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.18),
                      ),
                    ),
                    child: Wrap(
                      spacing: 2,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        IconButton(
                          key: const ValueKey('ocr-rotate-button'),
                          tooltip: 'Xoay 90°',
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _applyImageTransform(
                            quarterTurns: (_quarterTurns + 1) % 4,
                          ),
                          icon: const Icon(
                            Icons.rotate_90_degrees_cw_rounded,
                            color: Colors.white,
                            size: 19,
                          ),
                        ),
                        IconButton(
                          key: const ValueKey('ocr-flip-horizontal-button'),
                          tooltip: 'Lật ngang ảnh',
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _applyImageTransform(
                            flipHorizontal: !_flipHorizontal,
                          ),
                          icon: Icon(
                            Icons.flip_rounded,
                            color: _flipHorizontal
                                ? DytavaColors.sourceBlue
                                : Colors.white,
                            size: 19,
                          ),
                        ),
                        IconButton(
                          key: const ValueKey('ocr-flip-vertical-button'),
                          tooltip: 'Lật dọc ảnh',
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _applyImageTransform(
                            flipVertical: !_flipVertical,
                          ),
                          icon: Transform.rotate(
                            angle: math.pi / 2,
                            child: Icon(
                              Icons.flip_rounded,
                              color: _flipVertical
                                  ? DytavaColors.sourceBlue
                                  : Colors.white,
                              size: 19,
                            ),
                          ),
                        ),
                        IconButton(
                          key: const ValueKey('ocr-zoom-out-button'),
                          tooltip: 'Thu nhỏ ảnh',
                          visualDensity: VisualDensity.compact,
                          onPressed: _zoomScale > 1.0
                              ? () => _setZoom(_zoomScale - 0.5)
                              : null,
                          icon: const Icon(
                            Icons.zoom_out_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        IconButton(
                          key: const ValueKey('ocr-zoom-in-button'),
                          tooltip: 'Phóng to ảnh',
                          visualDensity: VisualDensity.compact,
                          onPressed: _zoomScale < 4.0
                              ? () => _setZoom(_zoomScale + 0.5)
                              : null,
                          icon: const Icon(
                            Icons.zoom_in_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        IconButton(
                          key: const ValueKey('ocr-zoom-reset-button'),
                          tooltip: 'Đặt lại khung & thu phóng',
                          visualDensity: VisualDensity.compact,
                          onPressed: () {
                            _setZoom(1.0);
                            setState(() {
                              _bbox = const Rect.fromLTRB(
                                0.06,
                                0.08,
                                0.94,
                                0.92,
                              );
                            });
                          },
                          icon: const Icon(
                            Icons.center_focus_strong_rounded,
                            color: Colors.white,
                            size: 19,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );

        final bottomBar = StickyBottomBar(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: WorkflowPrimaryButton(
            key: const ValueKey('ocr-confirm-bbox-scan-button'),
            label: 'Quét bảng',
            onPressed: () => session.confirmTableBboxAndRecognize(
              normalizedBbox: _bbox,
              quarterTurns: _quarterTurns,
              flipHorizontal: _flipHorizontal,
              flipVertical: _flipVertical,
            ),
          ),
        );

        if (constraints.hasBoundedHeight) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: canvasWidget),
              bottomBar,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: 420, child: canvasWidget),
            bottomBar,
          ],
        );
      },
    );
  }

  // ===========================================================================
  // SCREEN 2: Unified Table Review (4 Business States + 1-Tap Import)
  // ===========================================================================

  Widget _buildUnifiedTableReviewView(
    BuildContext context,
    OcrSession session,
  ) {
    final isTableDetected =
        session.detectionState == OcrDetectionState.tableDetected;
    return WorkflowScreenLayout(
      contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      content: switch (session.detectionState) {
        OcrDetectionState.noTextDetected =>
          _buildEmptyStructureState(
            context,
            session,
            title: 'Chưa phát hiện bảng dữ liệu',
            description:
                'Không tìm thấy cấu trúc hàng và cột trong vùng ảnh đã chọn.',
          ),
        OcrDetectionState.textWithoutTable =>
          _buildEmptyStructureState(
            context,
            session,
            title: 'Chưa phát hiện bảng dữ liệu',
            description:
                'Đã nhận diện văn bản nhưng chưa xác định được hàng và cột.',
          ),
        OcrDetectionState.processingFailed =>
          _buildProcessingFailedState(context, session),
        OcrDetectionState.tableDetected =>
          _buildCleanEditableTable(context, session),
      },
      bottomBar: isTableDetected
          ? StickyBottomBar(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: WorkflowPrimaryButton(
                key: const ValueKey('ocr-approve-and-import-button'),
                label: 'Dùng bảng này',
                onPressed: session.grid.cellCount > 0
                    ? () => _approveAndImport(context, session)
                    : null,
              ),
            )
          : null,
    );
  }

  Widget _buildEmptyStructureState(
    BuildContext context,
    OcrSession session, {
    required String title,
    required String description,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildCompactSourceRow(context, session),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: DytavaColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: DytavaColors.subtleBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: Icon(
                  Icons.table_rows_outlined,
                  size: 32,
                  color: DytavaColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontFamily: DytavaTypography.primaryFont,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: DytavaColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: const TextStyle(
                  fontFamily: DytavaTypography.primaryFont,
                  fontSize: 14.5,
                  color: DytavaColors.textSecondary,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 20),
              WorkflowPrimaryButton(
                key: const ValueKey('ocr-select-another-image'),
                label: 'Chọn ảnh khác',
                onPressed: widget.onSelectAnotherImage,
              ),
              WorkflowSecondaryButton(
                key: const ValueKey('ocr-create-manual-table'),
                label: 'Tạo bảng thủ công',
                onPressed: () => session.createManualTable(rows: 3, columns: 2),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProcessingFailedState(
    BuildContext context,
    OcrSession session,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildCompactSourceRow(context, session),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: DytavaColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: DytavaColors.subtleBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: Icon(
                  Icons.error_outline_rounded,
                  size: 32,
                  color: DytavaColors.different,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Không thể nhận diện ảnh này',
                style: TextStyle(
                  fontFamily: DytavaTypography.primaryFont,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: DytavaColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                session.error ?? 'Hãy thử khoanh lại vùng bảng hoặc chọn ảnh khác.',
                style: const TextStyle(
                  fontFamily: DytavaTypography.primaryFont,
                  fontSize: 14.5,
                  color: DytavaColors.textSecondary,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 20),
              WorkflowPrimaryButton(
                key: const ValueKey('ocr-retry-recognition'),
                label: 'Khoanh lại vùng bảng',
                onPressed: session.returnToPreprocess,
              ),
              WorkflowSecondaryButton(
                key: const ValueKey('ocr-failed-select-another'),
                label: 'Chọn ảnh khác',
                onPressed: widget.onSelectAnotherImage,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCompactSourceRow(BuildContext context, OcrSession session) {
    final processed = session.processed;
    return Material(
      color: DytavaColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: DytavaColors.subtleBorder),
      ),
      child: InkWell(
        key: const ValueKey('ocr-zoom-source-image'),
        borderRadius: BorderRadius.circular(14),
        onTap: () => _openSourceImageZoomDialog(context, session),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 36,
                decoration: BoxDecoration(
                  color: DytavaColors.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: DytavaColors.subtleBorder),
                ),
                clipBehavior: Clip.antiAlias,
                alignment: Alignment.center,
                child: processed != null
                    ? Image.memory(
                        processed.pngBytes,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                      )
                    : const Icon(
                        Icons.image_outlined,
                        size: 18,
                        color: DytavaColors.textSecondary,
                      ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Xem ảnh nguồn',
                  style: TextStyle(
                    fontFamily: DytavaTypography.primaryFont,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: DytavaColors.textPrimary,
                  ),
                ),
              ),
              TextButton(
                key: const ValueKey('ocr-reselect-bbox-button'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                onPressed: session.returnToPreprocess,
                child: const Text(
                  'Khoanh lại',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCleanEditableTable(BuildContext context, OcrSession session) {
    final grid = session.grid;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildCompactSourceRow(context, session),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: Text(
                '${grid.rowCount} hàng × ${grid.columnCount} cột',
                style: const TextStyle(
                  fontFamily: DytavaTypography.primaryFont,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: DytavaColors.textPrimary,
                ),
              ),
            ),
            TextButton.icon(
              key: const ValueKey('ocr-adjust-structure-sheet-button'),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              onPressed: () => _openStructureAdjustmentSheet(context, session),
              icon: const Icon(Icons.tune_rounded, size: 17),
              label: const Text(
                'Cấu trúc',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: DytavaColors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: DytavaColors.subtleBorder),
          ),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 40,
              dataRowMinHeight: 44,
              dataRowMaxHeight: 58,
              horizontalMargin: 14,
              columnSpacing: 20,
              columns: [
                const DataColumn(
                  label: Text('#', style: DytavaTypography.labelSmall),
                ),
                for (var c = 0; c < grid.columnCount; c++)
                  DataColumn(
                    label: Text(
                      grid.hasHeader && grid.rowCount > 0
                          ? (session.currentText(OcrCellRef(0, c)).isEmpty
                                ? 'Cột ${c + 1}'
                                : session.currentText(OcrCellRef(0, c)))
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
                          grid.hasHeader && r == 0 ? 'Tiêu đề' : '${r + 1}',
                          style: DytavaTypography.labelSmall,
                        ),
                      ),
                      for (var c = 0; c < grid.columnCount; c++)
                        _buildCleanCell(
                          context,
                          session,
                          OcrCellRef(r, c),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  DataCell _buildCleanCell(
    BuildContext context,
    OcrSession session,
    OcrCellRef ref,
  ) {
    final text = session.currentText(ref);
    final cell = session.grid.cells[ref.row][ref.column];
    final hasWarning =
        cell.risks.contains(OcrRisk.lowConfidence) ||
        cell.risks.contains(OcrRisk.diacritics) ||
        cell.risks.contains(OcrRisk.spansColumns);
    return DataCell(
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 165),
        child: Text(
          text.isEmpty ? '—' : text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: DytavaTypography.dataSmall.copyWith(
            color: hasWarning
                ? DytavaColors.modified
                : DytavaColors.textPrimary,
            fontWeight: hasWarning ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
      onTap: () => _openCellEditSheet(context, session, ref),
    );
  }

  // ===========================================================================
  // Bottom Sheets & Dialogs
  // ===========================================================================

  Future<void> _openSourceImageZoomDialog(
    BuildContext context,
    OcrSession session,
  ) async {
    final processed = session.processed;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ),
              Expanded(
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 5.0,
                  child: Center(
                    child: processed != null
                        ? Image.memory(processed.pngBytes, fit: BoxFit.contain)
                        : Image.memory(session.rawBytes, fit: BoxFit.contain),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openStructureAdjustmentSheet(
    BuildContext context,
    OcrSession session,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: DytavaColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => ListenableBuilder(
        listenable: session,
        builder: (context, _) {
          final grid = session.grid;
          return ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.85,
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
                  const Text(
                    'Cấu trúc bảng',
                    style: TextStyle(
                      fontFamily: DytavaTypography.primaryFont,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: DytavaColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Số cột',
                          style: TextStyle(
                            fontFamily: DytavaTypography.primaryFont,
                            fontSize: 15,
                            color: DytavaColors.textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        key: const ValueKey('ocr-col-decrease'),
                        onPressed: grid.columnCount > 1
                            ? () =>
                                session.reclusterColumns(grid.columnCount - 1)
                            : null,
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      Text(
                        '${grid.columnCount}',
                        style: const TextStyle(
                          fontFamily: DytavaTypography.primaryFont,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      IconButton(
                        key: const ValueKey('ocr-col-increase'),
                        onPressed: grid.columnCount < 12
                            ? () =>
                                session.reclusterColumns(grid.columnCount + 1)
                            : null,
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeThumbColor: DytavaColors.primary,
                    title: const Text(
                      'Hàng đầu là tiêu đề',
                      style: TextStyle(
                        fontFamily: DytavaTypography.primaryFont,
                        fontSize: 15,
                        color: DytavaColors.textPrimary,
                      ),
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
                        icon: const Icon(Icons.add, size: 18),
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
                  const SizedBox(height: 16),
                  WorkflowPrimaryButton(
                    label: 'Xong',
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

  Future<void> _openCellEditSheet(
    BuildContext context,
    OcrSession session,
    OcrCellRef ref,
  ) async {
    final cell = session.grid.cells[ref.row][ref.column];
    final controller = TextEditingController(text: session.currentText(ref));
    final isHeader = session.grid.hasHeader && ref.row == 0;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: DytavaColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          20 + MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    isHeader
                        ? 'Tiêu đề Cột ${ref.column + 1}'
                        : 'Hàng ${ref.row + 1}, Cột ${ref.column + 1}',
                    style: const TextStyle(
                      fontFamily: DytavaTypography.primaryFont,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: DytavaColors.textPrimary,
                    ),
                  ),
                ),
                if (cell.recognizedText != null &&
                    cell.recognizedText!.trim().contains(' '))
                  TextButton(
                    onPressed: () {
                      session.splitCellRight(ref);
                      Navigator.pop(sheetContext);
                    },
                    child: const Text('Tách cột'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              key: ValueKey('ocr-sheet-input-$ref'),
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Nhập giá trị',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              style: const TextStyle(
                fontFamily: DytavaTypography.primaryFont,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            WorkflowPrimaryButton(
              key: ValueKey('ocr-sheet-save-$ref'),
              label: 'Lưu',
              onPressed: () {
                session.editCellText(ref, controller.text);
                Navigator.pop(sheetContext);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _approveAndImport(
    BuildContext context,
    OcrSession session,
  ) async {
    final artifact = widget.source.artifact;
    if (artifact == null) return;
    try {
      session.approveTableForImport();
      final table = OcrCaptureService.commitFinalized(artifact.privateRef);
      await widget.flow.changeImportConfig(
        widget.source.side,
        ImportConfiguration(
          scopeConfirmed: true,
          ocrRevision: table.gridRevision,
          reviewedCells: {
            for (final e in session.receipts.keys) e.toString(),
          },
        ),
      );
      await widget.flow.importSource(widget.source.side);
      widget.onFinalized?.call();
    } catch (e) {
      if (context.mounted) {
        DytavaToast.error(
          context,
          '$e',
          title: 'Không thể nạp bảng OCR',
        );
      }
    }
  }
}

/// Touch-first BBox & Image Zoom/Scale Canvas:
/// - Pinch-to-zoom and pan directly on the image (`InteractiveViewer`).
/// - Two-finger rotation gesture rotates 90° without a text button.
/// - Touch-drag corner L-brackets, edge bars, or pan inside the BBox.
class _InteractiveTableBboxSelector extends StatefulWidget {
  final Uint8List imageBytes;
  final Rect bbox;
  final ValueChanged<Rect> onChanged;
  final VoidCallback? onRotateGesture;
  final TransformationController? zoomController;

  const _InteractiveTableBboxSelector({
    super.key,
    required this.imageBytes,
    required this.bbox,
    required this.onChanged,
    this.onRotateGesture,
    this.zoomController,
  });

  @override
  State<_InteractiveTableBboxSelector> createState() =>
      _InteractiveTableBboxSelectorState();
}

class _InteractiveTableBboxSelectorState
    extends State<_InteractiveTableBboxSelector> {
  static const _minSpan = 0.14;
  bool _rotatedInGesture = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(18),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          final bbox = widget.bbox;
          final left = bbox.left * w;
          final top = bbox.top * h;
          final right = bbox.right * w;
          final bottom = bbox.bottom * h;

          return GestureDetector(
            onScaleStart: (_) => _rotatedInGesture = false,
            onScaleUpdate: (details) {
              // Two-finger twist rotates image 90 degrees by touch
              if (!_rotatedInGesture &&
                  details.pointerCount >= 2 &&
                  details.rotation.abs() > math.pi / 5) {
                _rotatedInGesture = true;
                widget.onRotateGesture?.call();
              }
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Pinch-to-zoom & pan directly on the image
                InteractiveViewer(
                  transformationController: widget.zoomController,
                  minScale: 1.0,
                  maxScale: 4.0,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Image.memory(
                      widget.imageBytes,
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
                    ),
                  ),
                ),
                // Scrim + L-corner BBox frame overlay
                IgnorePointer(
                  child: CustomPaint(
                    painter: _BboxOverlayPainter(
                      rect: Rect.fromLTRB(left, top, right, bottom),
                    ),
                  ),
                ),
                // Interior drag area to move the whole BBox by touch
                Positioned(
                  left: left + 22,
                  top: top + 22,
                  width: (right - left - 44).clamp(0.0, w),
                  height: (bottom - top - 44).clamp(0.0, h),
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onPanUpdate: (details) {
                      final dx = details.delta.dx / w;
                      final dy = details.delta.dy / h;
                      final bw = bbox.width;
                      final bh = bbox.height;
                      final nl = (bbox.left + dx).clamp(0.0, 1.0 - bw);
                      final nt = (bbox.top + dy).clamp(0.0, 1.0 - bh);
                      widget.onChanged(Rect.fromLTWH(nl, nt, bw, bh));
                    },
                    onDoubleTap: () {
                      // Double-tap resets to full table bounds
                      widget.onChanged(
                        const Rect.fromLTRB(0.06, 0.08, 0.94, 0.92),
                      );
                    },
                  ),
                ),
                // 4 Edge touch targets (Top, Bottom, Left, Right)
                Positioned(
                  left: left + 24,
                  top: top - 20,
                  width: (right - left - 48).clamp(0.0, w),
                  height: 40,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanUpdate: (d) {
                      final nt = (bbox.top + d.delta.dy / h).clamp(
                        0.0,
                        bbox.bottom - _minSpan,
                      );
                      widget.onChanged(
                        Rect.fromLTRB(bbox.left, nt, bbox.right, bbox.bottom),
                      );
                    },
                  ),
                ),
                Positioned(
                  left: left + 24,
                  top: bottom - 20,
                  width: (right - left - 48).clamp(0.0, w),
                  height: 40,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanUpdate: (d) {
                      final nb = (bbox.bottom + d.delta.dy / h).clamp(
                        bbox.top + _minSpan,
                        1.0,
                      );
                      widget.onChanged(
                        Rect.fromLTRB(bbox.left, bbox.top, bbox.right, nb),
                      );
                    },
                  ),
                ),
                Positioned(
                  left: left - 20,
                  top: top + 24,
                  width: 40,
                  height: (bottom - top - 48).clamp(0.0, h),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanUpdate: (d) {
                      final nl = (bbox.left + d.delta.dx / w).clamp(
                        0.0,
                        bbox.right - _minSpan,
                      );
                      widget.onChanged(
                        Rect.fromLTRB(nl, bbox.top, bbox.right, bbox.bottom),
                      );
                    },
                  ),
                ),
                Positioned(
                  left: right - 20,
                  top: top + 24,
                  width: 40,
                  height: (bottom - top - 48).clamp(0.0, h),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanUpdate: (d) {
                      final nr = (bbox.right + d.delta.dx / w).clamp(
                        bbox.left + _minSpan,
                        1.0,
                      );
                      widget.onChanged(
                        Rect.fromLTRB(bbox.left, bbox.top, nr, bbox.bottom),
                      );
                    },
                  ),
                ),
                // 4 Corner touch zones (48x48dp invisible hit boxes; visual is L-bracket drawn by painter)
                _buildCornerTouchZone(
                  key: const ValueKey('ocr-bbox-handle-tl'),
                  x: left,
                  y: top,
                  onDrag: (d) {
                    final nl = (bbox.left + d.dx / w).clamp(
                      0.0,
                      bbox.right - _minSpan,
                    );
                    final nt = (bbox.top + d.dy / h).clamp(
                      0.0,
                      bbox.bottom - _minSpan,
                    );
                    widget.onChanged(
                      Rect.fromLTRB(nl, nt, bbox.right, bbox.bottom),
                    );
                  },
                ),
                _buildCornerTouchZone(
                  key: const ValueKey('ocr-bbox-handle-tr'),
                  x: right,
                  y: top,
                  onDrag: (d) {
                    final nr = (bbox.right + d.dx / w).clamp(
                      bbox.left + _minSpan,
                      1.0,
                    );
                    final nt = (bbox.top + d.dy / h).clamp(
                      0.0,
                      bbox.bottom - _minSpan,
                    );
                    widget.onChanged(
                      Rect.fromLTRB(bbox.left, nt, nr, bbox.bottom),
                    );
                  },
                ),
                _buildCornerTouchZone(
                  key: const ValueKey('ocr-bbox-handle-bl'),
                  x: left,
                  y: bottom,
                  onDrag: (d) {
                    final nl = (bbox.left + d.dx / w).clamp(
                      0.0,
                      bbox.right - _minSpan,
                    );
                    final nb = (bbox.bottom + d.dy / h).clamp(
                      bbox.top + _minSpan,
                      1.0,
                    );
                    widget.onChanged(
                      Rect.fromLTRB(nl, bbox.top, bbox.right, nb),
                    );
                  },
                ),
                _buildCornerTouchZone(
                  key: const ValueKey('ocr-bbox-handle-br'),
                  x: right,
                  y: bottom,
                  onDrag: (d) {
                    final nr = (bbox.right + d.dx / w).clamp(
                      bbox.left + _minSpan,
                      1.0,
                    );
                    final nb = (bbox.bottom + d.dy / h).clamp(
                      bbox.top + _minSpan,
                      1.0,
                    );
                    widget.onChanged(
                      Rect.fromLTRB(bbox.left, bbox.top, nr, nb),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCornerTouchZone({
    required Key key,
    required double x,
    required double y,
    required ValueChanged<Offset> onDrag,
  }) {
    return Positioned(
      left: x - 24,
      top: y - 24,
      width: 48,
      height: 48,
      child: GestureDetector(
        key: key,
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (details) => onDrag(details.delta),
      ),
    );
  }
}

class _BboxOverlayPainter extends CustomPainter {
  final Rect rect;

  const _BboxOverlayPainter({required this.rect});

  @override
  void paint(Canvas canvas, Size size) {
    final full = Offset.zero & size;
    final scrimPaint = Paint()..color = const Color(0x78000000);
    final path = Path()
      ..addRect(full)
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(6)))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, scrimPaint);

    // Subtle 3x3 alignment grid inside the BBox
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.22)
      ..strokeWidth = 0.8;
    for (var i = 1; i <= 2; i++) {
      final gx = rect.left + rect.width * i / 3;
      final gy = rect.top + rect.height * i / 3;
      canvas.drawLine(Offset(gx, rect.top), Offset(gx, rect.bottom), gridPaint);
      canvas.drawLine(Offset(rect.left, gy), Offset(rect.right, gy), gridPaint);
    }

    // Thin frame line
    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(6)),
      borderPaint,
    );

    // Native scanner L-bracket corners (clean mobile camera/scanner feel)
    final cornerPaint = Paint()
      ..color = DytavaColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;
    const arm = 22.0;
    // Top-left
    canvas.drawLine(
      Offset(rect.left, rect.top + arm),
      Offset(rect.left, rect.top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(rect.left, rect.top),
      Offset(rect.left + arm, rect.top),
      cornerPaint,
    );
    // Top-right
    canvas.drawLine(
      Offset(rect.right - arm, rect.top),
      Offset(rect.right, rect.top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(rect.right, rect.top),
      Offset(rect.right, rect.top + arm),
      cornerPaint,
    );
    // Bottom-left
    canvas.drawLine(
      Offset(rect.left, rect.bottom - arm),
      Offset(rect.left, rect.bottom),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(rect.left, rect.bottom),
      Offset(rect.left + arm, rect.bottom),
      cornerPaint,
    );
    // Bottom-right
    canvas.drawLine(
      Offset(rect.right - arm, rect.bottom),
      Offset(rect.right, rect.bottom),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(rect.right, rect.bottom - arm),
      Offset(rect.right, rect.bottom),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _BboxOverlayPainter oldDelegate) =>
      oldDelegate.rect != rect;
}
