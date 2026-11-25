import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../application/workflow_controller.dart';
import '../../../design_system/design_system.dart';
import '../../../domain/workflow.dart';
import '../../../l10n/app_localizations.dart';
import '../../workflow/widgets/workflow_common_widgets.dart';

class ExportScreenView extends StatelessWidget {
  final WorkflowController flow;
  final ExportKind exportKind;
  final ExportSelection selection;
  final bool scopeConfirmed;
  final ValueChanged<ExportKind> onKindChanged;
  final ValueChanged<ExportSelection> onSelectionChanged;
  final ValueChanged<bool> onScopeConfirmedChanged;
  final VoidCallback onRunExportPreview;
  final VoidCallback onBackToResults;
  const ExportScreenView({
    super.key,
    required this.flow,
    required this.exportKind,
    required this.selection,
    required this.scopeConfirmed,
    required this.onKindChanged,
    required this.onSelectionChanged,
    required this.onScopeConfirmedChanged,
    required this.onRunExportPreview,
    required this.onBackToResults,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final hasReceipt = flow.receipt != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 4),
        Text(
          l10n.exportReport,
          style: const TextStyle(
            fontFamily: DytavaTypography.primaryFont,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.includeComparedCells(flow.result!.cells.length),
          style: const TextStyle(
            fontFamily: DytavaTypography.primaryFont,
            fontSize: 13,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 14),
        RadioGroup<ExportKind>(
          groupValue: exportKind,
          onChanged: (value) {
            if (value != null) onKindChanged(value);
          },
          child: Column(
            children: [
              for (final kind in [
                ExportKind.csvDiff,
                ExportKind.jsonReport,
                ExportKind.dytavaReportPdf,
                if (flow.exporter.supports(ExportKind.mergedDiffPdf))
                  ExportKind.mergedDiffPdf,
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: exportKind == kind
                        ? const Color(0xFFE8F5E9)
                        : const Color(0xFFF8FAF9),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                        color: exportKind == kind
                            ? DytavaColors.primary
                            : const Color(0xFFE2E8F0),
                        width: exportKind == kind ? 1.4 : 1.0,
                      ),
                    ),
                    child: RadioListTile<ExportKind>(
                      value: kind,
                      enabled: !flow.busy,
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      controlAffinity: ListTileControlAffinity.trailing,
                      activeColor: DytavaColors.primary,
                      title: Text(
                        switch (kind) {
                          ExportKind.csvDiff => 'CSV',
                          ExportKind.jsonReport => 'JSON',
                          ExportKind.dytavaReportPdf => 'PDF',
                          ExportKind.mergedDiffPdf =>
                            l10n.isVietnamese ? 'PDF Hợp nhất A/B' : 'Merged PDF A/B',
                        },
                        style: TextStyle(
                          fontFamily: DytavaTypography.primaryFont,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: exportKind == kind
                              ? DytavaColors.primaryDark
                              : const Color(0xFF1E293B),
                        ),
                      ),
                      subtitle: Text(
                        switch (kind) {
                          ExportKind.csvDiff => l10n.csvSubtitle,
                          ExportKind.jsonReport => l10n.jsonSubtitle,
                          ExportKind.dytavaReportPdf => l10n.pdfSubtitle,
                          ExportKind.mergedDiffPdf => l10n.mergedPdfSubtitle,
                        },
                        style: const TextStyle(
                          fontFamily: DytavaTypography.primaryFont,
                          fontSize: 11.5,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<ExportSelection>(
          isExpanded: true,
          initialValue: selection,
          decoration: InputDecoration(
            labelText: l10n.reportScope,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          items: [
            DropdownMenuItem(
              value: ExportSelection.fullComparison,
              child: Text(l10n.fullComparison),
            ),
            DropdownMenuItem(
              value: ExportSelection.differencesOnly,
              child: Text(l10n.differencesAndUnresolved),
            ),
          ],
          onChanged: flow.busy
              ? null
              : (v) {
                  if (v != null) onSelectionChanged(v);
                },
        ),
        const SizedBox(height: 10),
        if (!hasReceipt) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: scopeConfirmed
                  ? const Color(0xFFE8F5E9)
                  : const Color(0xFFF8FAF9),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: scopeConfirmed
                      ? DytavaColors.primary
                      : const Color(0xFFE2E8F0),
                ),
              ),
              child: CheckboxListTile(
                dense: true,
                visualDensity: VisualDensity.compact,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                activeColor: DytavaColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                title: Text(
                  l10n.confirmFormatAndReportScope,
                  style: const TextStyle(
                    fontFamily: DytavaTypography.primaryFont,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
                value: scopeConfirmed,
                onChanged: flow.busy
                    ? null
                    : (v) => onScopeConfirmedChanged(v ?? false),
              ),
            ),
          ),
          WorkflowPrimaryButton(
            label: l10n.prepareReport,
            onPressed: scopeConfirmed &&
                    flow.exporter.supports(exportKind) &&
                    !flow.busy
                ? onRunExportPreview
                : null,
          ),
        ],
        if (flow.issue != null) WorkflowIssueList(issues: [flow.issue!]),
        if (flow.exportState?.active == true) ...[
          const SizedBox(height: 10),
          const LinearProgressIndicator(),
          TextButton(
            onPressed: flow.exportState == ExportState.cancelling
                ? null
                : flow.cancelExport,
            child: Text(l10n.cancelExport),
          ),
        ],
        if (hasReceipt)
          DytavaFadeSlide(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        color: DytavaColors.primary,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.reportReady,
                          style: const TextStyle(
                            fontFamily: DytavaTypography.primaryFont,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF065F46),
                          ),
                        ),
                      ),
                      if (flow.receipt!.fileName != null)
                        Flexible(
                          child: Text(
                            flow.receipt!.fileName!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: DytavaTypography.primaryFont,
                              fontSize: 11.5,
                              color: Color(0xFF047857),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                WorkflowPrimaryButton(
                  label: l10n.saveToDevice,
                  iconAsset: DytavaIcons.export,
                  onPressed: () => _save(context),
                ),
                Theme(
                  data: Theme.of(context).copyWith(
                    dividerColor: Colors.transparent,
                  ),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 4),
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    title: Text(
                      l10n.previewReport,
                      style: const TextStyle(
                        fontFamily: DytavaTypography.primaryFont,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF334155),
                      ),
                    ),
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        constraints: const BoxConstraints(maxHeight: 160),
                        child: SingleChildScrollView(
                          child: SelectableText(
                            flow.receipt!.previewText.length > 20000
                                ? '${flow.receipt!.previewText.substring(0, 20000)}\n… Preview limited to 20,000 characters. The saved file includes all data.'
                                : flow.receipt!.previewText,
                            style: DytavaTypography.dataSmall,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 4),
        TextButton(
          onPressed: flow.busy ? null : onBackToResults,
          child: Text(
            l10n.cancel,
            style: const TextStyle(
              fontFamily: DytavaTypography.primaryFont,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _save(BuildContext context) async {
    final l10n = context.l10n;
    final receipt = flow.receipt!;
    final fileName = receipt.fileName ??
        switch (exportKind) {
          ExportKind.csvDiff => 'dytava-differences.csv',
          ExportKind.jsonReport => 'dytava-report.json',
          ExportKind.dytavaReportPdf => 'dytava-report.pdf',
          ExportKind.mergedDiffPdf => 'dytava-merged-diff.pdf',
        };
    final bytes = receipt.fileBytes != null
        ? Uint8List.fromList(receipt.fileBytes!)
        : Uint8List.fromList(utf8.encode(receipt.previewText));
    final mimeType = fileName.endsWith('.csv')
        ? 'text/csv'
        : fileName.endsWith('.pdf')
        ? 'application/pdf'
        : 'application/json';
    try {
      final uri = await FilePicker.saveFile(
        fileName: fileName,
        bytes: bytes,
        mimeType: mimeType,
      );
      if (context.mounted && uri != null) {
        DytavaToast.success(
          context,
          l10n.reportSavedToast,
          title: l10n.reportSavedTitle,
        );
      }
    } catch (_) {
      if (context.mounted) {
        DytavaToast.error(
          context,
          l10n.chooseAnotherLocationRetry,
          title: l10n.unableToSaveReport,
        );
      }
    }
  }
}
