import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dytava/app/workflow_composition.dart';
import 'package:dytava/design_system/design_system.dart';
import 'package:dytava/domain/workflow.dart';
import 'package:dytava/features/workflow/screens/source_selection_view.dart';
import 'package:dytava/infrastructure/file_upload_service.dart';

void main() {
  group('Mobile File Upload & Parser Tests', () {
    test('processFileBytes correctly parses CSV bytes into fields and rows', () {
      const csvContent = '''Mã NV,Họ và Tên,Phòng Ban,Lương Cơ Bản
NV001,Nguyễn Văn An,Kế Toán,15000000
NV002,Trần Thị Bình,Kỹ Thuật,18500000
NV003,Lê Hoàng Nam,Kinh Doanh,12000000''';

      final bytes = Uint8List.fromList(utf8.encode(csvContent));
      final info = MobileFileUploadService.processFileBytes(
        side: SourceSide.a,
        fileName: 'nhan_vien.csv',
        bytes: bytes,
      );

      expect(info.fileName, 'nhan_vien.csv');
      expect(info.format, SourceFormat.csv);
      expect(info.rowCount, 3);
      expect(info.columnCount, 4);
      expect(info.privateRef.startsWith('userfile:'), isTrue);
    });

    test('processFileBytes correctly parses XLSX bytes into fields and rows', () {
      final excel = Excel.createExcel();
      final sheet = excel['Sheet1'];
      sheet.appendRow([
        TextCellValue('Mã SP'),
        TextCellValue('Tên Sản Phẩm'),
        TextCellValue('Số Lượng'),
      ]);
      sheet.appendRow([
        TextCellValue('SP01'),
        TextCellValue('Bàn phím cơ'),
        IntCellValue(25),
      ]);
      sheet.appendRow([
        TextCellValue('SP02'),
        TextCellValue('Chuột không dây'),
        IntCellValue(40),
      ]);

      final bytes = Uint8List.fromList(excel.save()!);
      final info = MobileFileUploadService.processFileBytes(
        side: SourceSide.b,
        fileName: 'ton_kho.xlsx',
        bytes: bytes,
      );

      expect(info.fileName, 'ton_kho.xlsx');
      expect(info.format, SourceFormat.xlsx);
      expect(info.rowCount, 2);
      expect(info.columnCount, 3);
    });

    test('processFileBytes recovers from Excel files without styles (Damaged Excel file: styles)', () {
      // Build a minimal OpenXML archive without styles.xml (which causes standard Excel.decodeBytes to throw)
      final archive = Archive();
      const sheetXml = '''<?xml version="1.0" encoding="UTF-8"?>
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <sheetData>
    <row r="1">
      <c r="A1" t="inlineStr"><is><t>Mã SP</t></is></c>
      <c r="B1" t="inlineStr"><is><t>Giá Tiền</t></is></c>
    </row>
    <row r="2">
      <c r="A2" t="inlineStr"><is><t>SP01</t></is></c>
      <c r="B2"><v>150000</v></c>
    </row>
    <row r="3">
      <c r="A3" t="inlineStr"><is><t>SP02</t></is></c>
      <c r="B3"><v>250000</v></c>
    </row>
  </sheetData>
</worksheet>''';
      archive.addFile(ArchiveFile('xl/worksheets/sheet1.xml', sheetXml.length, utf8.encode(sheetXml)));
      final zipBytes = Uint8List.fromList(ZipEncoder().encode(archive)!);

      final info = MobileFileUploadService.processFileBytes(
        side: SourceSide.a,
        fileName: 'damaged_styles.xlsx',
        bytes: zipBytes,
      );

      expect(info.fileName, 'damaged_styles.xlsx');
      expect(info.format, SourceFormat.xlsx);
      expect(info.rowCount, 2);
      expect(info.columnCount, 2);
    });

    test('WorkflowController imports registered user file and reaches ready state', () async {
      const csvA = 'ID,Name,Score\n001,Alice,8.5\n002,Bob,9.0';
      const csvB = 'ID,Name,Score\n001,Alice,"8,5"\n002,Bob,9.5';

      final infoA = MobileFileUploadService.processFileBytes(
        side: SourceSide.a,
        fileName: 'test_a.csv',
        bytes: Uint8List.fromList(utf8.encode(csvA)),
      );
      final infoB = MobileFileUploadService.processFileBytes(
        side: SourceSide.b,
        fileName: 'test_b.csv',
        bytes: Uint8List.fromList(utf8.encode(csvB)),
      );

      final flow = createDemoWorkflow();
      expect(flow.slot(SourceSide.a).state, InputState.unselected);
      expect(flow.slot(SourceSide.b).state, InputState.unselected);

      // Select and import Source A
      await flow.selectSource(
        SourceSide.a,
        infoA.format,
        infoA.privateRef,
        infoA.fileName,
      );
      expect(flow.slot(SourceSide.a).state, InputState.selected);
      await flow.importSource(SourceSide.a);
      expect(flow.slot(SourceSide.a).state, InputState.previewReady);

      // Select and import Source B
      await flow.selectSource(
        SourceSide.b,
        infoB.format,
        infoB.privateRef,
        infoB.fileName,
      );
      expect(flow.slot(SourceSide.b).state, InputState.selected);
      await flow.importSource(SourceSide.b);
      expect(flow.slot(SourceSide.b).state, InputState.previewReady);

      expect(flow.inputsReady, isTrue);
    });

    testWidgets('SourceSelectionView renders device upload button and empty state correctly', (tester) async {
      final flow = createDemoWorkflow();

      await tester.pumpWidget(
        MaterialApp(
          theme: DytavaTheme.lightTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: SourceSelectionView(
                flow: flow,
                quickProcessing: false,
                onOpenPreview: (_) {},
                onContinueMapping: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Empty State is shown when no files are uploaded
      expect(find.text('Choose file A'), findsOneWidget);
      expect(find.text('Choose file B'), findsOneWidget);
      expect(find.byTooltip('Select file A'), findsOneWidget);
      expect(find.byTooltip('Select file B'), findsOneWidget);
      expect(find.text('Compare spreadsheets'), findsOneWidget);

    });
  });
}
