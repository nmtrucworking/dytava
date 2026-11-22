import 'dart:isolate';

import 'package:excelcompare_core/excelcompare_core.dart';

import '../domain/workflow.dart';
import '../ocr/infrastructure/ocr_capture_service.dart';
import 'demo/demo_workflow_ports.dart';
import 'file_upload_service.dart';

final class MobileInputPort implements InputPort, InputCleanupPort {
  @override
  Future<ImportOutcome> importSource(
    SourceArtifact artifact,
    ImportBinding binding,
    ImportConfiguration config,
    Cancellation cancel,
    void Function() onParsing,
  ) async {
    if (artifact.isFixture) {
      return DemoInputPort().importSource(
        artifact,
        binding,
        config,
        cancel,
        onParsing,
      );
    }
    if (OcrCaptureService.isOcrRef(artifact.privateRef)) {
      cancel.check();
      onParsing();
      return OcrCaptureService.outcomeFor(
        artifact: artifact,
        binding: binding,
      );
    }
    cancel.check();
    onParsing();
    final workbook = await MobileFileUploadService.snapshotInBackground(
      artifact.privateRef,
      artifact,
      binding,
    );
    cancel.check();
    if (workbook != null) {
      return ImportOutcome.ready(workbook);
    }
    final data = DemoInputPort.userFile(artifact.privateRef);
    if (data == null) {
      throw const WorkflowIssue(
        'FILE_NOT_FOUND',
        'Không tìm thấy dữ liệu tệp đã chọn.',
      );
    }
    onParsing();
    final snapshot = await Isolate.run(
      () => _snapshot(artifact, binding, data),
    );
    cancel.check();
    return ImportOutcome.ready(snapshot);
  }

  @override
  void release(String ref) {
    if (OcrCaptureService.isOcrRef(ref)) {
      OcrCaptureService.release(ref);
      return;
    }
    MobileFileUploadService.release(ref);
  }
}

InputSnapshot _snapshot(
  SourceArtifact artifact,
  ImportBinding binding,
  UserFileSnapshotData data,
) => InputSnapshot(
  id: '${artifact.id}-snapshot-${binding.revision}-${binding.attempt}',
  binding: binding,
  fields: data.fields,
  fullValidation: true,
  ocrReviewed: false,
  records: [
    for (var r = 0; r < data.values.length; r++)
      TableRecord(
        '${artifact.id}-row-$r',
        r,
        {
          for (var c = 0; c < data.fields.length; c++)
            data.fields[c].id: SourceCell(
              CellKind.text,
              rawLexeme: data.values[r][c],
            ),
        },
        {
          for (final f in data.fields)
            f.id:
                '${data.sheetName ?? artifact.label}!R${r + data.headerRow + 1}/${f.id}',
        },
      ),
  ],
);
