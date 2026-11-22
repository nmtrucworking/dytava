import 'package:flutter/material.dart';

import '../../../application/workflow_controller.dart';
import '../../../design_system/design_system.dart';
import '../../../domain/workflow.dart';
import '../../../infrastructure/file_upload_service.dart';
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

/// Existing fixture recognition review; every uncertain value remains gated.
class OcrReviewScreenView extends StatelessWidget {
  final WorkflowController flow;
  final Set<String> reviewedCells;
  final ValueChanged<String> onToggleCell;
  final VoidCallback onReviewAll;
  final VoidCallback? onConfirmReviewed;
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
                      'This sample tests the review flow. Camera capture and recognition are not available yet.',
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
