// Synthetic OOXML fixtures shared by Node and Flutter tests (not Excel-authored).
import ExcelJS from 'exceljs';
import { unzipSync, zipSync, strToU8, strFromU8 } from 'fflate';
import { writeFile } from 'node:fs/promises';
const NS = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships';
const RD = 'http://schemas.microsoft.com/office/2017/06/relationships';
const PNG = Uint8Array.from(Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jc1sAAAAASUVORK5CYII=', 'base64'));
export async function imageWorkbook({ reversed = false, broken = false } = {}) {
  const wb = new ExcelJS.Workbook();
  const products = [['ProductID', 'Photo', 'Cost'], ['P01', { error: '#VALUE!' }, 10], ['P02', { error: '#VALUE!' }, reversed ? 21 : 20]];
  const people = [['EmployeeID', 'Name', 'StartDate'], ['E01', 'Alice', '2026-11-20']];
  wb.addWorksheet('Sheet1').addRows(reversed ? people : products);
  wb.addWorksheet('Sheet2').addRows(reversed ? products : people);
  wb.addWorksheet('Archive', { state: 'hidden' }).addRows([['Code', 'Note'], ['X01', 'old']]);
  wb.addWorksheet('Empty');
  if (reversed) wb.addWorksheet('New empty');
  const entries = unzipSync(new Uint8Array(await wb.xlsx.writeBuffer()));
  const sheetPath = `xl/worksheets/sheet${reversed ? 2 : 1}.xml`;
  let xml = strFromU8(entries[sheetPath]);
  xml = xml.replace('<c r="B2"', '<c vm="1" r="B2"').replace('<c r="B3"', '<c vm="2" r="B3"');
  entries[sheetPath] = strToU8(xml);
  entries['xl/_rels/workbook.xml.rels'] = strToU8(strFromU8(entries['xl/_rels/workbook.xml.rels']).replace('</Relationships>', `<Relationship Id="meta" Type="${NS}/sheetMetadata" Target="meta/custom.xml"/><Relationship Id="rv" Type="${RD}/rdRichValue" Target="richData/values.xml"/><Relationship Id="rs" Type="${RD}/rdRichValueStructure" Target="richData/structure.xml"/><Relationship Id="rr" Type="http://schemas.microsoft.com/office/2022/10/relationships/richValueRel" Target="richData/references.xml"/></Relationships>`));
  entries['xl/meta/custom.xml'] = strToU8(`<metadata xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:rd="http://schemas.microsoft.com/office/spreadsheetml/2017/richdata"><metadataTypes count="1"><metadataType name="XLRICHVALUE"/></metadataTypes><futureMetadata name="XLRICHVALUE" count="2"><bk><extLst><ext uri="{3E2802C4-A4D2-4D8B-9148-E3BE6C30E623}"><rd:rvb i="0"/></ext></extLst></bk><bk><extLst><ext uri="{3E2802C4-A4D2-4D8B-9148-E3BE6C30E623}"><rd:rvb i="1"/></ext></extLst></bk></futureMetadata><valueMetadata count="2"><bk><rc t="1" v="0"/></bk><bk><rc t="1" v="1"/></bk></valueMetadata></metadata>`);
  entries['xl/richData/structure.xml'] = strToU8('<rvStructures xmlns="http://schemas.microsoft.com/office/spreadsheetml/2017/richdata" count="1"><s t="_localImage"><k n="CalcOrigin" t="i"/><k n="_rvRel:LocalImageIdentifier" t="i"/></s></rvStructures>');
  entries['xl/richData/values.xml'] = strToU8('<rvData xmlns="http://schemas.microsoft.com/office/spreadsheetml/2017/richdata" count="2"><rv s="0"><v>5</v><v>0</v></rv><rv s="0"><v>5</v><v>1</v></rv></rvData>');
  entries['xl/richData/references.xml'] = strToU8(`<richValueRels xmlns="http://schemas.microsoft.com/office/spreadsheetml/2022/richvaluerel" xmlns:r="${NS}"><rel r:id="first"/><rel r:id="second"/></richValueRels>`);
  const first = reversed ? 'renamed.png' : 'image1.png', second = 'image2.png';
  // Deliberately reverse relationship order; IDs and rel-list indices must be resolved.
  entries['xl/richData/_rels/references.xml.rels'] = strToU8(`<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="second" Type="${NS}/image" Target="../media/${second}"/><Relationship Id="first" Type="${NS}/image" Target="../media/${first}"/></Relationships>`);
  entries[`xl/media/${first}`] = PNG;
  entries[`xl/media/${second}`] = Uint8Array.from([...PNG, reversed ? 2 : 1]);
  if (broken) delete entries[`xl/media/${second}`];
  return zipSync(entries);
}
if (process.argv[1]?.endsWith('build-workbook-fixtures.js')) {
  for (const [name, options] of [['workbook-a.xlsx', {}], ['workbook-b.xlsx', { reversed: true }], ['workbook-broken.xlsx', { broken: true }]]) await writeFile(new URL(name, import.meta.url), await imageWorkbook(options));
}
