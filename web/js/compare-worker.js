import { CompareEngine } from './compare-engine.js';
import { parseFile } from './file-parser.js';
self.onmessage = async ({ data }) => {
  try {
    const result = data.type === 'parse' ? await parseFile(data.file, data.sheetName) : new CompareEngine(data.policy).compareTables(data.fileA, data.fileB, data.keyColumn);
    self.postMessage({ id: data.id, result });
  } catch (error) { self.postMessage({ id: data.id, error: error.message || 'Không xử lý được dữ liệu.' }); }
};
