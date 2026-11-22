import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { unzipSync, zipSync, strFromU8, strToU8 } from 'fflate';
import { parseFile } from '../web/js/file-parser.js';
import { CompareEngine } from '../web/js/compare-engine.js';
import { mapSheets } from '../web/js/sheet-mapping.js';
import { validateReport } from '../web/js/report/model.js';
const fixture = async name => parseFile(new File([await readFile(new URL(`fixtures/${name}`, import.meta.url))], name));
const s = (name, headers, types = []) => ({ name, headers, types });
test('names precede structure; default tab names require unique structure; ties never use tab order', () => {
  assert.equal(mapSheets([s('Revenue', ['id'])], [s('Revenue', ['different'])]).pairs[0].method, 'name');
  const a = [s('Sheet1', ['sku', 'cost']), s('Sheet2', ['person', 'name'])], b = [s('Sheet1', ['person', 'name']), s('Sheet2', ['sku', 'cost'])];
  assert.deepEqual(mapSheets(a, b).pairs.map(p => [p.a, p.b, p.method]), [[0, 1, 'structure'], [1, 0, 'structure']]);
  const ambiguous = mapSheets([s('Sheet1', ['id']), s('Sheet2', ['id'])], [s('Sheet1', ['id']), s('Sheet2', ['id'])]);
  assert.equal(ambiguous.complete, false); assert.equal(ambiguous.pairs.length, 0);
  assert.equal(mapSheets([s('', ['id'])], [s('', ['id'])]).pairs[0].method, 'structure');
  assert.throws(() => mapSheets(a, b, [{ a: 'Sheet1', b: 'Sheet1' }, { a: 'Sheet2', b: 'Sheet1' }]), /một–một/);
});
test('whole workbook comparison covers renamed/reordered default tabs, hidden/empty sheets, and sheet additions', async () => {
  const a = await fixture('workbook-a.xlsx'), b = await fixture('workbook-b.xlsx');
  assert.equal(a.tables.length, 4); assert.equal(b.tables.length, 5);
  const result = new CompareEngine().compareTables(a, b, null, { alignmentMode: 'POSITIONAL' });
  assert.equal(result.sheetResults.length, 5);
  assert.equal(result.sheetResults.find(r => r.pair.nameA === 'Sheet1').pair.nameB, 'Sheet2');
  assert.equal(result.summary.different, 2); // Changed photo bytes and cost, on the second product.
  assert.equal(result.report.sheet_changes[0].sheetB, 'New empty');
  assert.equal(result.report.sheets.length, 5);
  assert.ok(result.report.warnings.some(w => w.includes('sheet ẩn')));
  assert.equal(result.summary.exact + result.summary.equivalent + result.summary.different + result.summary.unresolved, result.summary.total_cells_checked);
  assert.ok(result.report.differences.every(d => d.sheetA || d.sheetB));
  validateReport(result.report, { allowLegacy: true });
});
test('in-cell images use metadata chain, relationship IDs and bytes rather than paths or #VALUE!', async () => {
  const a = await fixture('workbook-a.xlsx'), b = await fixture('workbook-b.xlsx');
  const imageA = a.tables[0].specialCells['0,1'], imageB = b.tables[1].specialCells['0,1'];
  assert.equal(imageA.kind, 'image'); assert.equal(imageA.digest, imageB.digest);
  const result = new CompareEngine().compareTables(a, b, null, { alignmentMode: 'POSITIONAL' });
  const products = result.sheetResults.find(r => r.pair.nameA === 'Sheet1');
  assert.equal(products.alignedRows[0].cellComparisons.Photo.status, 'EXACT');
  assert.equal(products.alignedRows[1].cellComparisons.Photo.status, 'DIFFERENT');
  assert.equal(products.alignedRows[1].cellComparisons.Photo.ruleId, 'image/bytes');
});
test('missing image data stays unresolved even for identical cached errors', async () => {
  const a = await fixture('workbook-broken.xlsx');
  const result = new CompareEngine().compareTables(a, a, null, { alignmentMode: 'POSITIONAL' });
  assert.equal(result.summary.unresolved, 1);
  assert.equal(result.sheetResults.find(r => r.pair.nameA === 'Sheet1').alignedRows[1].cellComparisons.Photo.ruleId, 'content/unsupported');
});
test('IMAGE/DISPIMG without authenticated embedded bytes never become equal error strings', async () => {
  const entries = unzipSync(new Uint8Array(await readFile(new URL('fixtures/workbook-a.xlsx', import.meta.url))));
  const path = 'xl/worksheets/sheet1.xml';
  entries[path] = strToU8(strFromU8(entries[path]).replace(/ vm="1"/, '').replace('<c r="B2" t="e"><v>#VALUE!</v></c>', '<c r="B2" t="e"><f>_xlfn.IMAGE("https://example.com/private.png")</f><v>#VALUE!</v></c>'));
  const a = await parseFile(new File([zipSync(entries)], 'url-image.xlsx'));
  assert.equal(a.tables[0].specialCells['0,1'].kind, 'unsupported');
  const result = new CompareEngine().compareTables(a, a, null, { alignmentMode: 'POSITIONAL' });
  assert.equal(result.summary.unresolved, 1);
});
test('explicit missing sheet is rejected rather than falling back to the first sheet', async () => {
  await assert.rejects(parseFile(new File([await readFile(new URL('fixtures/workbook-a.xlsx', import.meta.url))], 'a.xlsx'), 'missing'), /Không tìm thấy sheet/);
});

test('merged children do not duplicate anchor values and images beyond a blank header are retained', async () => {
  const { default: ExcelJS } = await import('exceljs');
  const wb = new ExcelJS.Workbook(), sheet = wb.addWorksheet('Data');
  sheet.addRows([['ID', 'Note', 'Other'], ['001', 'anchor', null]]); sheet.mergeCells('B2:C2');
  const a = await parseFile(new File([await wb.xlsx.writeBuffer()], 'merged.xlsx'));
  assert.deepEqual(a.rows[0], ['001', 'anchor', '']);
  assert.ok(a.warnings.some(w => w.includes('ô gộp')));
});

test('literal text resembling an image label never equals an actual image', async () => {
  const a = await fixture('workbook-a.xlsx');
  const b = structuredClone(a); delete b.tables[0].specialCells['0,1'];
  const result = new CompareEngine().compareTables(a, b, null, { alignmentMode: 'POSITIONAL' });
  assert.equal(result.sheetResults.find(r => r.pair.nameA === 'Sheet1').alignedRows[0].cellComparisons.Photo.status, 'DIFFERENT');
});

test('ordinal metadata policy cannot hide an image change beyond the sampling window', async () => {
  const a = await fixture('workbook-a.xlsx'), image = a.tables[0].specialCells['0,1'];
  const rows = Array.from({ length: 60 }, (_, r) => [String(r + 1)]);
  const ta = { headers: ['No.'], rows: [...rows, [image.label]], specialCells: { '60,0': image } };
  const tb = { headers: ['No.'], rows: [...rows, [image.label]], specialCells: { '60,0': { ...image, digest: 'different', bytes: Uint8Array.from([1]) } } };
  const result = new CompareEngine().compareTables(ta, tb, null, { alignmentMode: 'POSITIONAL' });
  assert.equal(result.alignedRows[60].cellComparisons['No.'].status, 'DIFFERENT');
  assert.equal(result.alignedRows[60].cellComparisons['No.'].ruleId, 'image/bytes');
});

test('place-in-cell and manual drawing-anchored images distinguish placement and expose renderable data URLs', async () => {
  const entries = unzipSync(new Uint8Array(await readFile(new URL('fixtures/workbook-a.xlsx', import.meta.url))));
  // Add a drawing relationship and drawing1.xml anchoring a manual image at B3 on sheet2 (Employee sheet)
  const sheet2Xml = strFromU8(entries['xl/worksheets/sheet2.xml']).replace(
    '</worksheet>',
    '<drawing r:id="rIdDrawing1"/></worksheet>',
  );
  entries['xl/worksheets/sheet2.xml'] = strToU8(sheet2Xml);
  entries['xl/worksheets/_rels/sheet2.xml.rels'] = strToU8(
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">' +
    '<Relationship Id="rIdDrawing1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/drawing" Target="../drawings/drawing1.xml"/>' +
    '</Relationships>',
  );
  entries['xl/drawings/drawing1.xml'] = strToU8(
    '<xdr:wsDr xmlns:xdr="http://schemas.openxmlformats.org/drawingml/2006/spreadsheetDrawing" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">' +
    '<xdr:twoCellAnchor><xdr:from><xdr:col>1</xdr:col><xdr:row>1</xdr:row></xdr:from><xdr:pic><xdr:blipFill><a:blip r:embed="rIdImg1"/></xdr:blipFill></xdr:pic></xdr:twoCellAnchor>' +
    '</xdr:wsDr>',
  );
  entries['xl/drawings/_rels/drawing1.xml.rels'] = strToU8(
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">' +
    '<Relationship Id="rIdImg1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="../media/image1.png"/>' +
    '</Relationships>',
  );
  const a = await parseFile(new File([zipSync(entries)], 'manual-drawing.xlsx'));
  // Sheet1 has Place in Cell (RichData)
  const placeInCell = a.tables[0].specialCells['0,1'];
  assert.equal(placeInCell.kind, 'image');
  assert.equal(placeInCell.imagePlacement, 'placeInCell');
  assert.ok(placeInCell.dataUrl.startsWith('data:image/png;base64,'));
  assert.ok(placeInCell.label.includes('Ảnh trong ô'));
  // Sheet2 has Manual Drawing Anchor at B2 (col=1, row=1 -> B2 -> data row 0, col 1)
  const manualCell = a.tables[1].specialCells['0,1'];
  assert.equal(manualCell.kind, 'image');
  assert.equal(manualCell.imagePlacement, 'drawingAnchor');
  assert.ok(manualCell.dataUrl.startsWith('data:image/png;base64,'));
  assert.ok(manualCell.label.includes('Ảnh đặt thủ công'));
  assert.ok(a.warnings.some(w => w.includes('Place over Cells')));
});
