import Papa from 'papaparse';
import { unzipSync } from 'fflate';

export const MAX_FILE_BYTES = 10 * 1024 * 1024;
export const MAX_ROWS = 20000;
export const MAX_COLUMNS = 200;
export const MAX_CELLS = 200000;

export function validateTable(headers, rows) {
  headers = headers.map(v => String(v ?? '').replace(/^\uFEFF/, '').trim());
  if (!headers.length || headers.some(h => !h) || new Set(headers).size !== headers.length) throw new Error('Tiêu đề cột phải có tên, duy nhất và không để trống.');
  if (headers.length > MAX_COLUMNS || rows.length > MAX_ROWS || rows.length * headers.length > MAX_CELLS) throw new Error('Tệp vượt giới hạn 20.000 dòng, 200 cột hoặc 200.000 ô.');
  if (rows.some(row => !Array.isArray(row) || row.length > headers.length)) throw new Error('Có dòng chứa nhiều ô hơn tiêu đề cột.');
  rows = rows.map(row => headers.map((_, i) => {
    const value = row[i];
    if (value !== null && typeof value === 'object') throw new Error('Ô dữ liệu JSON chỉ được chứa chuỗi, số, boolean hoặc null.');
    const text = String(value ?? '');
    if (text.length > 32767) throw new Error('Nội dung một ô vượt quá 32.767 ký tự.');
    return text;
  }));
  return { headers, rows };
}

export function parseText(text, format) {
  if (format === 'json') {
    const data = JSON.parse(text.replace(/^\uFEFF/, ''));
    if (Array.isArray(data)) {
      if (!data.length || data.some(row => !row || Array.isArray(row) || typeof row !== 'object')) throw new Error('JSON cần là mảng các bản ghi hoặc {headers, rows}.');
      const headers = [...new Set(data.flatMap(row => Object.keys(row)))];
      return validateTable(headers, data.map(row => headers.map(h => row[h] ?? '')));
    }
    if (data && Array.isArray(data.headers) && Array.isArray(data.rows)) return validateTable(data.headers, data.rows);
    throw new Error('JSON cần là mảng các bản ghi hoặc {headers, rows}.');
  }
  const result = Papa.parse(text, { delimiter: format === 'tsv' ? '\t' : '', skipEmptyLines: 'greedy', dynamicTyping: false });
  if (result.errors.some(error => error.type === 'Quotes')) throw new Error('Tệp CSV có dấu ngoặc kép không hợp lệ.');
  return validateTable(result.data[0] || [], result.data.slice(1));
}

function inspectZip(buffer) {
  let total = 0;
  let entries = 0;
  // Filter inspects the central directory without inflating any entry.
  unzipSync(new Uint8Array(buffer), { filter(entry) {
    entries++;
    total += entry.originalSize;
    if (entries > 2000 || total > 50 * 1024 * 1024 || entry.originalSize > 25 * 1024 * 1024 || /(^|\/)\.\.(\/|$)/.test(entry.name)) throw new Error('Workbook không an toàn hoặc vượt giới hạn giải nén 50 MB.');
    return false;
  } });
}

export async function parseFile(file, sheetName) {
  const format = file.name.split('.').pop().toLowerCase();
  if (!['csv', 'tsv', 'txt', 'json', 'xlsx'].includes(format)) throw new Error('Chỉ hỗ trợ XLSX, CSV, TSV, TXT và JSON.');
  if (!file.size || file.size > MAX_FILE_BYTES) throw new Error('Tệp phải có dữ liệu và không vượt quá 10 MB.');
  if (format !== 'xlsx') return { name: file.name, format, ...parseText(await file.text(), format) };
  const buffer = await file.arrayBuffer();
  inspectZip(buffer);
  const { default: ExcelJS } = await import('exceljs');
  const workbook = new ExcelJS.Workbook();
  await workbook.xlsx.load(buffer);
  const sheets = workbook.worksheets.filter(s => s.state === 'visible' && s.actualRowCount);
  const sheet = sheetName ? sheets.find(s => s.name === sheetName) : sheets[0];
  if (!sheet) throw new Error('Workbook không có sheet dữ liệu hiển thị.');
  if (sheet.rowCount > MAX_ROWS + 1 || sheet.columnCount > MAX_COLUMNS || sheet.rowCount * sheet.columnCount > MAX_CELLS + MAX_COLUMNS) throw new Error('Sheet vượt giới hạn 20.000 dòng, 200 cột hoặc 200.000 ô.');
  const getText = cell => {
    if (cell.value instanceof Date) return cell.value.toISOString().slice(0, 10);
    if (cell.value && typeof cell.value === 'object') {
      if ('formula' in cell.value || 'sharedFormula' in cell.value) return cell.result === undefined ? `=${cell.formula}` : String(cell.result instanceof Date ? cell.result.toISOString() : cell.result);
      if (cell.value.richText) return cell.value.richText.map(t => t.text).join('');
      if (cell.value.error) return cell.value.error;
    }
    // Preserve formatted IDs (e.g. 00123) and percentage representations.
    if (typeof cell.value === 'number' && /^0+$/.test(cell.numFmt || '')) return String(cell.value).padStart(cell.numFmt.length, '0');
    if (typeof cell.value === 'number' && (cell.numFmt || '').includes('%')) return `${cell.value * 100}%`;
    return cell.text || '';
  };
  const headers = Array.from({ length: sheet.columnCount }, (_, i) => getText(sheet.getRow(1).getCell(i + 1)));
  while (headers.length && !headers.at(-1)) headers.pop();
  const rows = [];
  sheet.eachRow((row, number) => {
    if (number > 1) rows.push(Array.from({ length: headers.length }, (_, i) => getText(row.getCell(i + 1))));
  });
  return { name: file.name, format, sheetName: sheet.name, sheets: sheets.map(s => s.name), ...validateTable(headers, rows) };
}
