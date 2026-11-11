import { test } from 'node:test';
import assert from 'node:assert/strict';
import { CompareEngine } from '../web/js/compare-engine.js';
import { AdminPortal } from '../web/js/admin-portal.js';
import { parseText, parseFile, validateTable } from '../web/js/file-parser.js';
import ExcelJS from 'exceljs';
import Papa from 'papaparse';

const table = rows => ({ name: 'test.csv', format: 'csv', headers: ['ID', 'Value'], rows });
test('all ten documented semantic golden fixtures pass', () => {
  const results = new AdminPortal().runAllAcceptanceTests();
  assert.equal(results.length, 10);
  for (const row of results) assert.equal(row.actual, row.expected, row.id);
});
test('row-order mode does not implicitly align on first column; complete differences exported', () => {
  const result = new CompareEngine().compareTables(table([['1', 'a'], ['2', 'b']]), table([['2', 'b'], ['1', 'a']]), null);
  assert.equal(result.alignedRows.length, 2); assert.ok(result.summary.different > 0); assert.ok(result.report.differences.length > 0);
});
test('key alignment preserves reordered rows and rejects duplicate/blank keys instead of losing data', () => {
  const engine = new CompareEngine();
  assert.equal(engine.compareTables(table([['1', 'a'], ['2', 'b']]), table([['2', 'b'], ['1', 'a']]), 'ID').summary.exact, 4);
  assert.throws(() => engine.compareTables(table([['1', 'a']]), table([['1', 'a'], ['1', 'b']]), 'ID'), /trống hoặc trùng/);
  assert.throws(() => engine.compareTables(table([['', 'a']]), table([['1', 'a']]), 'ID'), /trống hoặc trùng/);
});
test('reports added/removed rows and missing columns even if values are blank', () => {
  const engine = new CompareEngine();
  const result = engine.compareTables(table([['1', 'a']]), table([['2', 'b']]), 'ID');
  assert.equal(result.summary.added_rows, 1); assert.equal(result.summary.removed_rows, 1); assert.equal(result.report.differences.length, 2);
  const a = { ...table([['1', '']]), headers: ['ID', 'OnlyA'] }, b = table([['1', '']]);
  assert.equal(engine.compareTables(a, b, 'ID').summary.different, 2);
});
test('column names that look like Object properties remain ordinary data', () => {
  const table = value => ({ headers: ['__proto__'], rows: [[value]], format: 'csv' });
  const result = new CompareEngine().compareTables(table('a'), table('b'), null);
  assert.equal(result.summary.different, 1); assert.equal(result.alignedRows[0].cellComparisons.__proto__.status, 'DIFFERENT');
});
test('explicit types honor text and identifier settings', () => {
  assert.equal(new CompareEngine().compareCells('01', '1', '', 'text').status, 'DIFFERENT');
  assert.equal(new CompareEngine({ preserve_leading_zeros: false, case_sensitive_identifier: false }).compareCells('ABC', 'abc', '', 'identifier').status, 'EQUIVALENT');
  assert.equal(new CompareEngine({ case_sensitive_text: true }).compareCells(' Hello ', 'Hello').status, 'EQUIVALENT');
});
test('CSV parser preserves leading zeros, apostrophes, whitespace, embedded newlines and quoted delimiters', () => {
  const result = parseText('\uFEFFID,Name,Note\r\n001,"O\'Brien","two\nlines, here"\r\n002, Bob ,plain', 'csv');
  assert.deepEqual(result.headers, ['ID', 'Name', 'Note']);
  assert.equal(result.rows[0][0], '001'); assert.equal(result.rows[0][1], "O'Brien"); assert.equal(result.rows[0][2], 'two\nlines, here'); assert.equal(result.rows[1][1], ' Bob ');
  assert.equal(parseText('ID;Value\n01;8,5', 'csv').rows[0][1], '8,5');
  assert.equal(parseText('ID\tValue\n01\t8,5', 'tsv').rows[0][1], '8,5');
});
test('JSON adapters validate flat cells and unique headers, enforcing limits', () => {
  assert.deepEqual(parseText('[{"ID":"001","Value":true},{"ID":"002","Other":2}]', 'json').rows, [['001', 'true', ''], ['002', '', '2']]);
  assert.deepEqual(parseText('{"headers":["ID"],"rows":[["01"]]}', 'json').rows, [['01']]);
  assert.throws(() => parseText('[{"nested":{"secret":1}}]', 'json'), /chỉ được chứa/);
  assert.throws(() => validateTable(['ID', 'ID'], []), /duy nhất/);
  assert.throws(() => validateTable(['ID'], Array(20001).fill(['1'])), /vượt giới hạn/);
});
test('XLSX import handles sheets, formatted identifiers, cached formula results and rich text', async () => {
  const workbook = new ExcelJS.Workbook(); const sheet = workbook.addWorksheet('Primary');
  sheet.addRow(['ID', 'Value', 'Note']); sheet.addRow([123, { formula: '1+1', result: 2 }, { richText: [{ text: 'Hello ' }, { text: 'world' }] }]); sheet.getCell('A2').numFmt = '00000';
  workbook.addWorksheet('Second').addRows([['ID'], ['002']]);
  const buffer = await workbook.xlsx.writeBuffer(); const file = new File([buffer], 'test.xlsx');
  const first = await parseFile(file); assert.equal(first.rows[0][0], '00123'); assert.equal(first.rows[0][1], '2'); assert.equal(first.rows[0][2], 'Hello world'); assert.deepEqual(first.sheets, ['Primary', 'Second']);
  const second = await parseFile(file, 'Second'); assert.equal(second.rows[0][0], '002');
});
test('unsupported or malformed files are rejected; CSV export neutralizes formulas including leading whitespace', async () => {
  await assert.rejects(parseFile(new File(['a'], 'macro.xlsm')), /Chỉ hỗ trợ/);
  await assert.rejects(parseFile(new File(['broken'], 'broken.xlsx')));
  const csv = Papa.unparse({ fields: ['Test'], data: [['=HYPERLINK("https://evil.example")'], ['  =1+1'], ['@SUM(A1)']] }, { escapeFormulae: /^[\s]*[=+\-@\t\r\n]/, quotes: true });
  const rows = Papa.parse(csv).data;
  assert.ok(rows.slice(1).every(row => row[0].startsWith("'")));
});

test('every published policy toggle affects actual cell comparison and precision loss stays unresolved', () => {
  assert.equal(new CompareEngine({ distinct_null_zero: false }).compareCells('0', 'BLANK').status, 'EQUIVALENT');
  assert.equal(new CompareEngine({ preserve_leading_zeros: false }).compareCells('00123', '123').status, 'EQUIVALENT');
  assert.equal(new CompareEngine({ case_sensitive_identifier: false }).compareCells('SV001', 'sv001').status, 'EQUIVALENT');
  assert.equal(new CompareEngine().compareCells('9007199254740992', '9007199254740993').status, 'UNRESOLVED');
});
