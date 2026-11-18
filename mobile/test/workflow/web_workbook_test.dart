import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dytava/app/workflow_composition.dart';
import 'package:dytava/domain/workflow.dart';
import 'package:dytava/infrastructure/file_upload_service.dart';

void main() {
  test('XLSX relationships, banner header, styled ID/percentage/date, namespace and sheet switch', () async {
    final archive = Archive();
    final xml = {
      'xl/workbook.xml': '<workbook xmlns:r="urn:relationships"><sheets><sheet name="First" sheetId="1" r:id="r1"/><sheet name="Planned" sheetId="2" r:id="r2"/></sheets></workbook>',
      'xl/_rels/workbook.xml.rels': '<Relationships><Relationship Id="r1" Target="worksheets/first.xml"/><Relationship Id="r2" Target="worksheets/second.xml"/></Relationships>',
      'xl/styles.xml': '<styleSheet><numFmts><numFmt numFmtId="164" formatCode="00000"/></numFmts><cellXfs><xf numFmtId="0"/><xf numFmtId="164"/><xf numFmtId="9"/><xf numFmtId="14"/></cellXfs></styleSheet>',
      'xl/worksheets/first.xml': '<worksheet><sheetData><row r="1"><c r="A1" t="inlineStr"><is><t>ID</t></is></c><c r="B1" t="inlineStr"><is><t>Value</t></is></c></row><row r="2"><c r="A2" s="1"><v>123</v></c><c r="B2" s="2"><v>0.1</v></c></row></sheetData></worksheet>',
      'xl/worksheets/second.xml': '<x:worksheet xmlns:x="urn:spreadsheet"><x:sheetData><x:row r="1"><x:c r="A1" t="inlineStr"><x:is><x:t>Project banner</x:t></x:is></x:c></x:row><x:row r="3"><x:c r="A3" t="inlineStr"><x:is><x:t>Title</x:t></x:is></x:c><x:c r="B3" t="inlineStr"><x:is><x:t>Date</x:t></x:is></x:c></x:row><x:row r="4"><x:c r="A4" t="inlineStr"><x:is><x:r><x:t>Project </x:t></x:r><x:r><x:t>Brief</x:t></x:r></x:is></x:c><x:c r="B4" s="3"><x:v>45212</x:v></x:c></x:row></x:sheetData></x:worksheet>',
    };
    for (final entry in xml.entries) {
      final bytes = utf8.encode(entry.value);
      archive.addFile(ArchiveFile(entry.key, bytes.length, bytes));
    }
    final info = MobileFileUploadService.processFileBytes(
      side: SourceSide.a,
      fileName: 'plan.xlsx',
      bytes: Uint8List.fromList(ZipEncoder().encode(archive)!),
    );
    expect(info.sheets, ['First', 'Planned']);
    final flow = createMobileWorkflow();
    addTearDown(flow.dispose);
    await flow.selectSource(
      SourceSide.a,
      info.format,
      info.privateRef,
      info.fileName,
    );
    await flow.importSource(SourceSide.a);
    var snapshot = flow.slot(SourceSide.a).snapshot!;
    expect(snapshot.records.single.cells['ID']!.rawLexeme, '00123');
    expect(snapshot.records.single.cells['Value']!.rawLexeme, '10%');
    MobileFileUploadService.selectSheet(info.privateRef, 'Planned');
    await flow.selectSource(
      SourceSide.a,
      info.format,
      info.privateRef,
      info.fileName,
    );
    await flow.importSource(SourceSide.a);
    snapshot = flow.slot(SourceSide.a).snapshot!;
    expect(snapshot.fields.map((f) => f.id), ['Title', 'Date']);
    expect(snapshot.records.single.cells['Title']!.rawLexeme, 'Project Brief');
    expect(snapshot.records.single.cells['Date']!.rawLexeme, '2023-10-13');
    expect(snapshot.records.single.locations['Title'], 'Planned!R4/Title');
  });
  test('malformed delimited rows and unsupported binary XLS are rejected', () {
    for (final pair in [
      ('bad.csv', 'ID,Score\n001,8,5'),
      ('old.xls', 'not an XLSX'),
    ]) {
      expect(
        () => MobileFileUploadService.processFileBytes(
          side: SourceSide.a,
          fileName: pair.$1,
          bytes: Uint8List.fromList(utf8.encode(pair.$2)),
        ),
        throwsFormatException,
      );
    }
  });
}
