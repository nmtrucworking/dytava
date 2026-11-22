import Papa from 'papaparse';
import { inspectCellContent } from './xlsx-cell-content.js';
import { unzipSync, zipSync, strFromU8, strToU8 } from 'fflate';

export const MAX_FILE_BYTES = 500 * 1024 * 1024;
export const MAX_ROWS = 1500000;
export const MAX_COLUMNS = 500;
export const MAX_CELLS = 25000000;

export function validateTable(headers, rows) {
  headers = headers.map(v => String(v ?? '').replace(/^\uFEFF/, '').trim());
  if (!headers.length || headers.some(h => !h) || new Set(headers).size !== headers.length) throw new Error('Tiêu đề cột phải có tên, duy nhất và không để trống.');
  if (headers.length > MAX_COLUMNS || rows.length > MAX_ROWS || rows.length * headers.length > MAX_CELLS) throw new Error('Tệp vượt giới hạn 1.500.000 dòng, 500 cột hoặc 25.000.000 ô.');
  
  const numCols = headers.length;
  for (let r = 0; r < rows.length; r++) {
    const row = rows[r];
    if (!Array.isArray(row) || row.length > numCols) throw new Error('Có dòng chứa nhiều ô hơn tiêu đề cột.');
    for (let c = 0; c < numCols; c++) {
      const value = row[c];
      if (value !== null && typeof value === 'object') throw new Error('Ô dữ liệu JSON chỉ được chứa chuỗi, số, boolean hoặc null.');
      if (typeof value !== 'string') {
        const text = String(value ?? '');
        if (text.length > 32767) throw new Error('Nội dung một ô vượt quá 32.767 ký tự.');
        row[c] = text;
      } else if (value.length > 32767) {
        throw new Error('Nội dung một ô vượt quá 32.767 ký tự.');
      }
    }
    while (row.length < numCols) {
      row.push('');
    }
  }
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
  try {
    unzipSync(new Uint8Array(buffer), { filter(entry) {
      entries++;
      total += entry.originalSize;
      if (entries > 20000 || total > 1500 * 1024 * 1024 || entry.originalSize > 500 * 1024 * 1024 || /(^|\/)\.\.(\/|$)/.test(entry.name)) {
        throw new Error('Workbook không an toàn hoặc vượt giới hạn giải nén 1.5 GB.');
      }
      return false;
    } });
  } catch (err) {
    if (err.message?.includes('giải nén')) throw err;
    const bytes = new Uint8Array(buffer.slice(0, 8));
    if (bytes[0] === 0xD0 && bytes[1] === 0xCF && bytes[2] === 0x11 && bytes[3] === 0xE0) {
      throw new Error('Tệp thuộc định dạng Excel cũ (.xls). Vui lòng mở và lưu lại (Save As) dạng .xlsx hoặc .csv trong Excel rồi thử lại.');
    }
    throw new Error('Tệp không đúng định dạng zip/xlsx hợp lệ. Vui lòng kiểm tra lại định dạng tệp.');
  }
}

function cleanOpenXml(buffer) {
  const zipEntries = unzipSync(new Uint8Array(buffer));
  let modified = false;
  for (const [name, data] of Object.entries(zipEntries)) {
    if (name.startsWith('xl/') && (name.endsWith('.xml') || name.endsWith('.rels'))) {
      const content = strFromU8(data);
      if (/<(\/)?([a-zA-Z0-9_-]+):([a-zA-Z0-9_-]+)/.test(content)) {
        const cleaned = content.replace(/<(\/?)[a-zA-Z0-9_-]+:([a-zA-Z0-9_-]+)/g, '<$1$2');
        zipEntries[name] = strToU8(cleaned);
        modified = true;
      }
    }
  }
  return modified ? zipSync(zipEntries) : buffer;
}

export async function parseFile(file, sheetName) {
  const format = file.name.split('.').pop().toLowerCase();
  if (!['csv', 'tsv', 'txt', 'json', 'xlsx'].includes(format)) throw new Error('Chỉ hỗ trợ XLSX, CSV, TSV, TXT và JSON.');
  if (!file.size || file.size > MAX_FILE_BYTES) throw new Error('Tệp phải có dữ liệu và không vượt quá 500 MB.');
  if (format !== 'xlsx') return { name: file.name, format, ...parseText(await file.text(), format) };
  const buffer = await file.arrayBuffer();
  inspectZip(buffer);
  const content = await inspectCellContent(unzipSync(new Uint8Array(buffer)));
  const { default: ExcelJS } = await import('exceljs');
  let workbook = new ExcelJS.Workbook();
  try {
    await workbook.xlsx.load(buffer);
  } catch {
    try {
      const cleaned = cleanOpenXml(buffer);
      workbook = new ExcelJS.Workbook();
      await workbook.xlsx.load(cleaned);
    } catch {
      throw new Error('Tệp Excel không đúng chuẩn OpenXML hoặc cấu trúc sheet không hợp lệ. Vui lòng mở và lưu lại tệp (Save As) dạng .xlsx hoặc .csv trong Excel / Google Sheets rồi thử lại.');
    }
  }
  const candidates = workbook.worksheets.filter(Boolean);
  if (!candidates.length) throw new Error('Workbook không có worksheet dữ liệu.');
  const tables = candidates.map(sheet => readWorksheet(sheet, content.get(sheet.name)));
  if (tables.reduce((n, t) => n + t.rows.length, 0) > MAX_ROWS || tables.reduce((n, t) => n + t.rows.length * t.headers.length, 0) > MAX_CELLS) throw new Error('Toàn workbook vượt giới hạn dòng hoặc số ô.');
  const sheet = sheetName ? tables.find(s => s.sheetName === sheetName) : tables[0];
  if (!sheet) throw new Error('Không tìm thấy sheet đã chọn.');
  const warnings = [...new Set(tables.flatMap(t => t.warnings))];
  return { name: file.name, format, ...sheet, sheets: tables.map(t => t.sheetName), tables, warnings };
}

function readWorksheet(sheet, content = { cells: new Map(), warnings: [] }) {
  for (const [address, special] of content.cells) {
    if (!/^[A-Z]{1,3}[1-9]\d*$/.test(address || '')) throw new Error('Địa chỉ ô ảnh không hợp lệ.');
    sheet.getCell(address).value = special.label;
  }
  const colCount = Math.max(sheet.columnCount || 0, sheet.actualColumnCount || 0, 1);
  const rowCount = Math.max(sheet.rowCount || 0, sheet.actualRowCount || 0);
  if (rowCount > MAX_ROWS + 1 || colCount > MAX_COLUMNS || rowCount * colCount > MAX_CELLS + MAX_COLUMNS) throw new Error('Sheet vượt giới hạn 1.500.000 dòng, 500 cột hoặc 25.000.000 ô.');
  const getText = cell => {
    if (cell.isMerged && cell.master.address !== cell.address) return '';
    const special = content.cells.get(cell.address);
    if (special) return special.label;
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

  // Find the actual table header row (skipping banners, title legends or empty rows like row 1-2 in Gantt templates)
  const maxSearchRow = Math.min(15, rowCount);
  let headerRow = 1;
  let headers = [];

  for (let r = 1; r <= maxSearchRow; r++) {
    const row = sheet.getRow(r);
    const cellCount = Math.max(row.cellCount || 0, row.actualCellCount || 0);
    if (cellCount === 0) continue;

    const rawCells = [];
    const limit = Math.max(cellCount, colCount);
    for (let c = 1; c <= limit; c++) {
      rawCells.push(getText(row.getCell(c)).trim());
    }
    while (rawCells.length && !rawCells.at(-1)) rawCells.pop();
    if (!rawCells.length) continue;

    const hasNoBlanks = !rawCells.some(h => !h);
    const isUnique = new Set(rawCells).size === rawCells.length;
    const hasDateOrPureNumber = rawCells.filter(v => /^\d{4}-\d{2}-\d{2}/.test(v) || /^-?\d+(\.\d+)?$/.test(v)).length;
    const looksLikeData = hasDateOrPureNumber >= Math.ceil(rawCells.length / 2);

    if (hasNoBlanks && isUnique && !looksLikeData && !rawCells.some((_, c) => content.cells.has(row.getCell(c + 1).address))) {
      const nextRow = sheet.getRow(r + 1);
      if (nextRow && nextRow.actualCellCount > 0) {
        headerRow = r;
        headers = rawCells;
        break;
      }
    }
  }

  if (!headers.length) {
    const row1 = sheet.getRow(1);
    const firstRowColCount = Math.max(colCount, row1.cellCount || 0);
    headers = Array.from({ length: firstRowColCount }, (_, i) => getText(row1.getCell(i + 1)).trim());
    while (headers.length && !headers.at(-1)) headers.pop();
  }
  if ([...content.cells.keys()].some(address => /^[A-Z]+1$/.test(address))) {
    headerRow = 0; headers = Array.from({ length: colCount }, () => '');
  }
  // Preserve data-only/image columns beyond the header labels.
  let dataWidth = headers.length;
  sheet.eachRow((row, number) => { if (number > headerRow) row.eachCell((cell, col) => { if (getText(cell) !== '') dataWidth = Math.max(dataWidth, col); }); });
  while (headers.length < dataWidth) headers.push('');

  // Ensure header names are valid, non-empty, and unique so validateTable succeeds
  const seenHeaders = new Set();
  headers = headers.map((h, i) => {
    const base = h || `Cột ${i + 1}`;
    let name = base, n = 1;
    while (seenHeaders.has(name)) name = `${base} (${++n})`;
    seenHeaders.add(name); return name;
  });

  const rows = [], specialCells = Object.create(null), sourceRows = [];
  sheet.eachRow((row, number) => {
    if (number > headerRow) {
      const rData = Array.from({ length: headers.length }, (_, i) => getText(row.getCell(i + 1)));
      if (rData.some(c => c !== '')) {
        for (let c = 0; c < headers.length; c++) {
          const special = content.cells.get(row.getCell(c + 1).address);
          if (special) specialCells[`${rows.length},${c}`] = special;
        }
        sourceRows.push(number); rows.push(rData);
      }
    }
  });
  const warnings = [...content.warnings];
  if (sheet.state === 'hidden' || sheet.state === 'veryHidden') warnings.push(`${sheet.name}: sheet ẩn được đưa vào phạm vi toàn workbook.`);
  if (Object.values(specialCells).some(c => c.kind === 'unsupported')) warnings.push(`${sheet.name}: có nội dung ô chưa đọc được; kết quả được giữ ở trạng thái chưa kết luận.`);
  const table = !headers.length && !rows.length ? { headers: [], rows: [] } : validateTable(headers, rows);
  return { sheetName: sheet.name, state: sheet.state || 'visible', headerRow, sourceRows, specialCells, warnings, ...table };
}
