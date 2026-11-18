import { test } from 'node:test';
import assert from 'node:assert/strict';
import { CompareEngine } from '../web/js/compare-engine.js';

const makeTable = (headers, rows, name = 'test.csv') => ({
  name,
  format: 'csv',
  headers,
  rows
});

test('Kịch bản 1: Đảo thứ tự 100 bản ghi có ID ổn định -> 0 khác biệt nội dung', () => {
  const engine = new CompareEngine();
  const rowsA = Array.from({ length: 100 }, (_, i) => [`ID_${i + 1}`, `Name_${i + 1}`, `Value_${(i + 1) * 10}`]);
  // Reverse order in B
  const rowsB = [...rowsA].reverse();

  const fileA = makeTable(['ID', 'Name', 'Value'], rowsA);
  const fileB = makeTable(['ID', 'Name', 'Value'], rowsB);

  const result = engine.compareTables(fileA, fileB, 'ID');
  assert.equal(result.summary.exact, 300);
  assert.equal(result.summary.different, 0);
  assert.equal(result.summary.added_rows, 0);
  assert.equal(result.summary.removed_rows, 0);
});

test('Kịch bản 2 (Ground Truth từ ảnh thực tế): Chèn 2 sự kiện giữa bảng kế hoạch -> Đúng 2 ADDED, 0 khác biệt nghiệp vụ (xóa bỏ 41 ô đỏ giả)', () => {
  const engine = new CompareEngine();
  const headers = ['No.', 'Date', 'Title', 'Type', 'Progress', 'Note'];

  // Data exact match from user screenshot
  const fileA = makeTable(headers, [
    ['1', '2023-10-13', 'Agreed Project Brief', 'Deadline', '100%', 'SUBMIT a one-page'],
    ['2', '2023-12-11', 'ELEC3227 CW', 'Event', '0%', 'PRESENT Embedded'],
    ['3', '2023-12-12', 'Progress Report', 'Deadline', '0%', 'SUBMIT a max 3000'],
    ['4', '2024-04-30', 'Final Project Report', 'Deadline', '0%', 'SUBMIT final repo'],
    ['5', '2024-05-16', 'Project Viva', 'Event', '0%', 'PRESENT project d']
  ]);

  const fileB = makeTable(headers, [
    ['1', '2023-10-13', 'Agreed Project Brief', 'Deadline', '100%', 'SUBMIT a one-page'],
    ['2', '2023-11-13', 'ELEC3227 CW', 'Event', '0%', 'CW Review meeting'], // Chèn mới #1
    ['3', '2023-12-11', 'ELEC3227 CW', 'Event', '0%', 'PRESENT Embedded'], // Cũ dòng 2 A -> dời sang 3 B
    ['4', '2023-12-12', 'Progress Report', 'Deadline', '0%', 'SUBMIT a max 3000'], // Cũ dòng 3 A -> dời sang 4 B
    ['-', '2024-01-08', 'ELEC3227 CW', 'Event', '0%', 'SUBMIT written pr'], // Chèn mới #2
    ['5', '2024-04-30', 'Final Project Report', 'Deadline', '0%', 'SUBMIT final repo'], // Cũ dòng 4 A -> dời sang 6 B
    ['6', '2024-05-16', 'Project Viva', 'Event', '0%', 'PRESENT project d'] // Cũ dòng 5 A -> dời sang 7 B
  ]);

  // Run with Sequence Alignment (ORDERED_SEQUENCE mode)
  const result = engine.compareTables(fileA, fileB, '__ORDERED_SEQUENCE__');

  // Assertions against Ground Truth:
  // 1. Phải phát hiện đúng 2 dòng ADDED ở giữa bảng
  assert.equal(result.summary.added_rows, 2, 'Phải phát hiện chính xác 2 dòng thêm mới');
  assert.equal(result.summary.removed_rows, 0, 'Không có dòng nào bị xóa');

  // 2. Không được để trôi dòng gây ra 41 ô khác biệt giả
  assert.equal(result.summary.different, 0, 'Tuyệt đối không có ô khác biệt nghiệp vụ giả');

  // 3. Toàn bộ 5 bản ghi cũ phải được gióng hàng chính xác
  assert.equal(result.alignedRows.length, 7, 'Tổng số hàng sau khi căn chỉnh phải là 7');

  // Kiểm tra từng cặp dòng sau gióng hàng:
  // Dòng 1: Agreed Project Brief
  assert.equal(result.alignedRows[0].type, 'MATCHED');
  assert.equal(result.alignedRows[0].rowA[2], 'Agreed Project Brief');
  assert.equal(result.alignedRows[0].rowB[2], 'Agreed Project Brief');

  // Dòng 2: Chèn mới CW Review meeting ở B
  assert.equal(result.alignedRows[1].type, 'ADDED');
  assert.equal(result.alignedRows[1].rowA, null);
  assert.equal(result.alignedRows[1].rowB[5], 'CW Review meeting');

  // Dòng 3: ELEC3227 CW (2023-12-11)
  assert.equal(result.alignedRows[2].type, 'MATCHED');
  assert.equal(result.alignedRows[2].rowA[1], '2023-12-11');
  assert.equal(result.alignedRows[2].rowB[1], '2023-12-11');
  assert.equal(result.alignedRows[2].sourceLineA, 2);
  assert.equal(result.alignedRows[2].sourceLineB, 3);

  // Dòng 4: Progress Report
  assert.equal(result.alignedRows[3].type, 'MATCHED');
  assert.equal(result.alignedRows[3].rowA[2], 'Progress Report');
  assert.equal(result.alignedRows[3].rowB[2], 'Progress Report');
  assert.equal(result.alignedRows[3].sourceLineA, 3);
  assert.equal(result.alignedRows[3].sourceLineB, 4);

  // Dòng 5: Chèn mới SUBMIT written pr ở B
  assert.equal(result.alignedRows[4].type, 'ADDED');
  assert.equal(result.alignedRows[4].rowA, null);
  assert.equal(result.alignedRows[4].rowB[5], 'SUBMIT written pr');

  // Dòng 6: Final Project Report
  assert.equal(result.alignedRows[5].type, 'MATCHED');
  assert.equal(result.alignedRows[5].rowA[2], 'Final Project Report');
  assert.equal(result.alignedRows[5].rowB[2], 'Final Project Report');

  // Dòng 7: Project Viva
  assert.equal(result.alignedRows[6].type, 'MATCHED');
  assert.equal(result.alignedRows[6].rowA[2], 'Project Viva');
  assert.equal(result.alignedRows[6].rowB[2], 'Project Viva');
});

test('Kịch bản 3: Xóa 1 bản ghi giữa bảng -> 1 REMOVED, các bản ghi xung quanh không bị cascade đỏ', () => {
  const engine = new CompareEngine();
  const headers = ['No.', 'Title', 'Status'];
  const fileA = makeTable(headers, [
    ['1', 'Task A', 'Done'],
    ['2', 'Task B', 'Pending'], // Bị xóa ở B
    ['3', 'Task C', 'Done'],
    ['4', 'Task D', 'Done']
  ]);

  const fileB = makeTable(headers, [
    ['1', 'Task A', 'Done'],
    ['2', 'Task C', 'Done'],
    ['3', 'Task D', 'Done']
  ]);

  const result = engine.compareTables(fileA, fileB, '__ORDERED_SEQUENCE__');
  assert.equal(result.summary.removed_rows, 1);
  assert.equal(result.summary.added_rows, 0);
  assert.equal(result.summary.different, 0);

  // Task B is marked REMOVED at index 1
  assert.equal(result.alignedRows[1].type, 'REMOVED');
  assert.equal(result.alignedRows[1].rowA[1], 'Task B');
  assert.equal(result.alignedRows[1].rowB, null);

  // Task C and D are preserved as MATCHED
  assert.equal(result.alignedRows[2].type, 'MATCHED');
  assert.equal(result.alignedRows[2].rowA[1], 'Task C');
  assert.equal(result.alignedRows[3].type, 'MATCHED');
  assert.equal(result.alignedRows[3].rowA[1], 'Task D');
});

test('Kịch bản 4: Đánh lại toàn bộ số thứ tự No. -> Không báo thay đổi nghiệp vụ nếu No. là Metadata', () => {
  const engine = new CompareEngine();
  const headers = ['No.', 'Code', 'Desc'];
  const fileA = makeTable(headers, [
    ['1', 'ITM-01', 'Item One'],
    ['2', 'ITM-02', 'Item Two'],
    ['3', 'ITM-03', 'Item Three']
  ]);

  // Insert at top, shifting all No.
  const fileB = makeTable(headers, [
    ['1', 'ITM-00', 'Item Zero'],
    ['2', 'ITM-01', 'Item One'],
    ['3', 'ITM-02', 'Item Two'],
    ['4', 'ITM-03', 'Item Three']
  ]);

  const result = engine.compareTables(fileA, fileB, '__ORDERED_SEQUENCE__');
  assert.equal(result.summary.added_rows, 1);
  assert.equal(result.summary.different, 0);
  // Renumbered No. is classified as equivalent metadata
  assert.ok(result.summary.equivalent > 0);
});

test('Kịch bản 5: Khóa trùng hoặc không xác định trong chế độ KEY -> Từ chối bảo vệ an toàn dữ liệu', () => {
  const engine = new CompareEngine();
  const headers = ['ID', 'Value'];
  const fileA = makeTable(headers, [['1', 'A']]);
  const fileB = makeTable(headers, [['1', 'A'], ['1', 'Duplicate']]);

  assert.throws(
    () => engine.compareTables(fileA, fileB, 'ID'),
    /trống hoặc trùng/
  );
});

test('Kịch bản 6: Sửa nội dung 1 bản ghi giữa chuỗi -> Chỉ báo ô thực sự thay đổi', () => {
  const engine = new CompareEngine();
  const headers = ['Date', 'Title', 'Progress'];
  const fileA = makeTable(headers, [
    ['2026-01-01', 'Milestone 1', '100%'],
    ['2026-02-01', 'Milestone 2', '20%'], // Progress changed to 50%
    ['2026-03-01', 'Milestone 3', '0%']
  ]);

  const fileB = makeTable(headers, [
    ['2026-01-01', 'Milestone 1', '100%'],
    ['2026-02-01', 'Milestone 2', '50%'],
    ['2026-03-01', 'Milestone 3', '0%']
  ]);

  const result = engine.compareTables(fileA, fileB, '__ORDERED_SEQUENCE__');
  assert.equal(result.summary.added_rows, 0);
  assert.equal(result.summary.removed_rows, 0);
  assert.equal(result.summary.different, 1, 'Chỉ đúng 1 ô Progress bị khác biệt');
  assert.equal(result.alignedRows[1].cellComparisons['Progress'].status, 'DIFFERENT');
  assert.equal(result.alignedRows[1].cellComparisons['Title'].status, 'EXACT');
  assert.equal(result.alignedRows[1].cellComparisons['Date'].status, 'EXACT');
});

test('Kịch bản 7: Lưu trữ Lineage và Match Rationale rõ ràng', () => {
  const engine = new CompareEngine();
  const headers = ['Title', 'Score'];
  const fileA = makeTable(headers, [
    ['Quiz 1', '10'],
    ['Quiz 2', '9']
  ]);
  const fileB = makeTable(headers, [
    ['Quiz 0', '8'], // Added at top
    ['Quiz 1', '10'],
    ['Quiz 2', '9']
  ]);

  const result = engine.compareTables(fileA, fileB, '__ORDERED_SEQUENCE__');
  // First row is added
  assert.equal(result.alignedRows[0].type, 'ADDED');
  assert.equal(result.alignedRows[0].sourceLineA, null);
  assert.equal(result.alignedRows[0].sourceLineB, 1);
  assert.ok(result.alignedRows[0].matchRationale.includes('chèn') || result.alignedRows[0].matchRationale.includes('thêm'));

  // Second row is Quiz 1: line 1 in A, line 2 in B
  assert.equal(result.alignedRows[1].type, 'MATCHED');
  assert.equal(result.alignedRows[1].sourceLineA, 1);
  assert.equal(result.alignedRows[1].sourceLineB, 2);
  assert.ok(result.alignedRows[1].matchRationale.length > 0);
});

test('Kịch bản 8: Chuyển sheet Excel có dòng banner/tiêu đề rỗng ở đầu (Gantt template)', async () => {
  const { parseFile } = await import('../web/js/file-parser.js');
  const ExcelJS = (await import('exceljs')).default;
  const wb = new ExcelJS.Workbook();

  // Sheet 1: Bắt đầu từ dòng 1 bình thường
  const s1 = wb.addWorksheet('Important dates');
  s1.addRow(['No.', 'Date', 'Title']);
  s1.addRow(['1', '2023-10-13', 'Brief']);

  // Sheet 2: Dòng 1 là tiêu đề lớn có ô null, dòng 2 trống, dòng 3 mới là tiêu đề bảng (như Planned)
  const s2 = wb.addWorksheet('Planned');
  s2.addRow(['Gantt Chart Title', 'Legend', '', 'Note', '']); // Dòng 1 có ô rỗng
  s2.addRow([]); // Dòng 2 trống
  s2.addRow(['Tasks', 'Start Date', 'Duration', 'Progress']); // Dòng 3 là tiêu đề bảng chuẩn
  s2.addRow(['Task 1', '2023-10-01', '5', '100%']);
  s2.addRow(['Task 2', '2023-10-06', '10', '50%']);

  const buffer = await wb.xlsx.writeBuffer();
  const file = new File([buffer], 'Gantt.xlsx');

  // Chuyển sang sheet 1
  const res1 = await parseFile(file, 'Important dates');
  assert.equal(res1.sheetName, 'Important dates');
  assert.deepEqual(res1.headers, ['No.', 'Date', 'Title']);
  assert.equal(res1.rows.length, 1);

  // Chuyển sang sheet 2 (Planned) - Trước đây bị văng lỗi 'Tiêu đề cột phải có tên, duy nhất và không để trống'
  const res2 = await parseFile(file, 'Planned');
  assert.equal(res2.sheetName, 'Planned');
  assert.deepEqual(res2.headers, ['Tasks', 'Start Date', 'Duration', 'Progress']);
  assert.equal(res2.rows.length, 2);
  assert.equal(res2.rows[0][0], 'Task 1');
  assert.equal(res2.rows[1][0], 'Task 2');
});

test('Kịch bản 9: Xử lý văn bản - Highlight Inline Diff theo từ và chuẩn hóa khoảng trắng thừa', () => {
  const engine = new CompareEngine();

  // 1. Highlight chính xác từ khác biệt trong câu dài (SUBMIT a none-page vs one-page)
  const cmp = engine.compareCells('SUBMIT a none-page PDF', 'SUBMIT a one-page PDF', 'Note');
  assert.equal(cmp.status, 'DIFFERENT');
  assert.ok(cmp.diffHtmlA.includes('<mark class="diff-word-del">none</mark>'));
  assert.ok(cmp.diffHtmlB.includes('<mark class="diff-word-ins">one</mark>'));
  assert.equal(cmp.similarity, 95);
  assert.ok(cmp.reason.includes('none'));
  assert.ok(cmp.reason.includes('one'));

  // 2. Chuẩn hóa nhiều khoảng trắng thừa liên tiếp và khoảng trắng không ngắt (non-breaking space)
  const cmpSpace = engine.compareCells('SUBMIT   a   one-page   PDF', 'SUBMIT a one-page PDF', 'Note');
  assert.equal(cmpSpace.status, 'EQUIVALENT');
  assert.equal(cmpSpace.ruleId, 'text/whitespace_normalized');

  const cmpNbsp = engine.compareCells('SUBMIT\u00A0a\u00A0one-page\u00A0PDF', 'SUBMIT a one-page PDF', 'Note');
  assert.equal(cmpNbsp.status, 'EQUIVALENT');
  assert.equal(cmpNbsp.ruleId, 'text/whitespace_normalized');
});
