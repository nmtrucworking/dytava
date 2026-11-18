// Exploratory browser benchmark of the current working tree. No production edits.
// node scripts/benchmark-web.mjs [output.json]
import { build } from 'esbuild';
import { chromium } from '@playwright/test';
import { createServer } from 'node:http';
import { mkdtemp, readFile, writeFile, rm } from 'node:fs/promises';
import { tmpdir, cpus, totalmem, platform, release } from 'node:os';
import { join, resolve, extname } from 'node:path';
import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import ExcelJS from 'exceljs';
import { CompareEngine } from '../web/js/compare-engine.js';

const root = resolve('.');
const temp = await mkdtemp(join(tmpdir(), 'dytava-perf-'));
let browser, server;
try {
  await build({ entryPoints: ['web/js/app.js', 'web/js/compare-worker.js'], outdir: join(temp, 'js'), bundle: true, splitting: true, format: 'esm', minify: true, target: 'es2022' });
  // Wrap the production worker handler; workMs excludes postMessage serialization.
  await writeFile(join(temp, 'js/measured-worker.js'), `import './compare-worker.js';
    let started; const handler = self.onmessage; const post = self.postMessage.bind(self);
    self.onmessage = event => { started = performance.now(); return handler(event); };
    self.postMessage = message => post({ ...message, workMs: performance.now() - started });
    post({ ready: true });`);
  server = createServer(async (req, res) => {
    if (req.url.startsWith('/api/')) { res.writeHead(503, { 'Content-Type': 'application/json' }); res.end('{}'); return; }
    try {
      const path = new URL(req.url, 'http://localhost').pathname;
      if (path.includes('..')) throw new Error('path');
      const file = path === '/' ? 'index.html' : path.slice(1);
      const data = await readFile(join(file.startsWith('js/') ? temp : join(root, 'web'), file));
      res.setHeader('Content-Type', ({ '.js': 'text/javascript', '.html': 'text/html', '.css': 'text/css', '.svg': 'image/svg+xml' })[extname(file)] || 'application/octet-stream');
      res.end(data);
    } catch { res.writeHead(404); res.end(); }
  });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  browser = await chromium.launch({ headless: true });
  const output = {
    timestamp: new Date().toISOString(), commit: execFileSync('git', ['rev-parse', 'HEAD'], { encoding: 'utf8' }).trim(),
    workingTree: execFileSync('git', ['status', '--short'], { encoding: 'utf8' }).trim(),
    environment: { cpu: cpus()[0].model, ramBytes: totalmem(), os: `${platform()} ${release()}`, browser: browser.version(), node: process.version },
    method: 'Synthetic deterministic fixtures; 1 small worker warmup + 1 case warmup; 5 sequential samples per fresh page/worker. No CPU throttling. UI/API runs offline. workMs is production handler time before postMessage; roundtrip includes both clones; renderMs is synchronous renderDualGrid only. Long tasks >=50ms on main thread cover roundtrip + render. Not peak memory or RP-1 calibration.',
    cases: []
  };
  output.sourceSha256 = Object.fromEntries(await Promise.all(['compare-engine.js', 'compare-worker.js', 'worker-client.js', 'file-parser.js', 'app.js'].map(async name => [name, createHash('sha256').update(await readFile(join(root, 'web/js', name))).digest('hex')])));
  const cases = [
    { name: 'positional-exact-10k', rows: 10000, cols: 10, mode: 'POSITIONAL' },
    { name: 'positional-exact-100k', rows: 100000, cols: 10, mode: 'POSITIONAL' },
    { name: 'key-reversed-100k', rows: 100000, cols: 10, mode: 'KEY', reverse: true },
    { name: 'sequence-anchors-100k', rows: 100000, cols: 10, mode: 'ORDERED_SEQUENCE', insert: true },
    { name: 'sequence-no-anchors-1000', rows: 1000, cols: 10, mode: 'ORDERED_SEQUENCE', mutate: true },
    { name: 'sequence-no-anchors-2000', rows: 2000, cols: 10, mode: 'ORDERED_SEQUENCE', mutate: true },
    { name: 'sequence-no-anchors-2001', rows: 2001, cols: 10, mode: 'ORDERED_SEQUENCE', mutate: true },
    { name: 'positional-wide-100-columns', rows: 10000, cols: 100, mode: 'POSITIONAL' },
    { name: 'positional-text-1000-chars', rows: 1000, cols: 2, mode: 'POSITIONAL', longText: true },
    { name: 'parse-csv-100k', rows: 100000, cols: 10, parse: 'csv' },
    { name: 'parse-xlsx-10k', rows: 10000, cols: 10, parse: 'xlsx' }
  ];
  for (const spec of cases) {
    const page = await browser.newPage();
    await page.goto(`http://127.0.0.1:${server.address().port}/`);
    await page.waitForFunction(() => window.dytavaApp?.ready);
    let xlsx;
    if (spec.parse === 'xlsx') {
      const wb = new ExcelJS.Workbook(); const sheet = wb.addWorksheet('Data');
      sheet.addRow(Array.from({ length: spec.cols }, (_, c) => c === 0 ? 'ID' : `Field${c}`));
      for (let i = 0; i < spec.rows; i++) sheet.addRow(Array.from({ length: spec.cols }, (_, c) => c === 0 ? `ID_${i}` : `Value ${i} col ${c}`));
      xlsx = Buffer.from(await wb.xlsx.writeBuffer()).toString('base64');
    }
    const result = await page.evaluate(async ({ spec, xlsx }) => {
      const headers = Array.from({ length: spec.cols }, (_, c) => c === 0 ? 'ID' : `Field${c}`);
      const rowsA = Array.from({ length: spec.rows }, (_, i) => headers.map((_, c) => c === 0 ? `ID_${i}` : spec.longText ? 'a'.repeat(999) + 'x' : `Value ${i} col ${c}`));
      let rowsB = rowsA.map(row => row.map((v, c) => spec.longText && c > 0 ? 'a'.repeat(999) + 'y' : spec.mutate && c === 1 ? `${v} updated` : v));
      if (spec.reverse) rowsB.reverse();
      if (spec.insert) rowsB.splice(Math.floor(spec.rows / 2), 0, headers.map((_, c) => `Inserted ${c}`));
      const fileA = { name: 'A.csv', format: 'csv', headers, rows: rowsA };
      const fileB = { name: 'B.csv', format: 'csv', headers, rows: rowsB };
      let file;
      if (spec.parse) file = spec.parse === 'csv'
        ? new File([[headers, ...rowsA].map(row => row.join(',')).join('\n')], 'data.csv')
        : new File([Uint8Array.from(atob(xlsx), ch => ch.charCodeAt(0))], 'data.xlsx');
      const worker = new Worker('/js/measured-worker.js', { type: 'module' });
      await new Promise((resolve, reject) => { worker.onmessage = resolve; worker.onerror = reject; });
      const call = data => new Promise((resolve, reject) => {
        const started = performance.now();
        const timer = setTimeout(() => { worker.terminate(); reject(new Error('30s timeout')); }, 30000);
        worker.onmessage = ({ data }) => { clearTimeout(timer); data.error ? reject(new Error(data.error)) : resolve({ data, roundtripMs: performance.now() - started, sendMs }); };
        worker.postMessage(data);
        const sendMs = performance.now() - started;
      });
      const tasks = [];
      const observer = new PerformanceObserver(list => tasks.push(...list.getEntries().map(e => ({ start: e.startTime, ms: e.duration }))));
      observer.observe({ type: 'longtask', buffered: false });
      const request = spec.parse ? { type: 'parse', file } : { type: 'compare', fileA, fileB, keyColumn: spec.mode === 'KEY' ? 'ID' : null, alignmentMode: spec.mode };
      const tiny = { headers: ['ID'], rows: [['warmup']] };
      await call({ type: 'compare', fileA: tiny, fileB: tiny });
      await call(request);
      const samples = [];
      for (let i = 0; i < 5; i++) {
        await new Promise(resolve => setTimeout(resolve, 50));
        const started = performance.now();
        const { data, roundtripMs, sendMs } = await call(request);
        let renderMs = null;
        if (!spec.parse) {
          const app = window.dytavaApp;
          app.fileA = fileA; app.fileB = fileB; app.currentComparisonResult = data.result; app.gridPage = 0;
          const renderStart = performance.now(); app.renderDualGrid(); renderMs = performance.now() - renderStart;
          const expected = spec.rows * spec.cols;
          if (data.result.summary.total_cells_checked !== expected) throw new Error('Unexpected compared cell count');
          if (spec.insert && data.result.summary.added_rows !== 1) throw new Error('Insertion oracle failed');
          if (spec.mutate && data.result.summary.different !== spec.rows) throw new Error('Mutation oracle failed');
          if (!spec.mutate && !spec.longText && data.result.summary.different !== 0) throw new Error('Exact oracle failed');
          if (spec.longText && data.result.summary.different !== spec.rows) throw new Error('Text oracle failed');
        } else if (data.result.rows.length !== spec.rows) throw new Error('Parse count oracle failed');
        const ended = performance.now();
        await new Promise(resolve => setTimeout(resolve, 50));
        samples.push({ workMs: data.workMs, roundtripMs, sendMs, renderMs, mainLongTasksMs: tasks.filter(t => t.start + t.ms >= started && t.start <= ended).map(t => t.ms), summary: data.result.summary });
      }
      worker.terminate(); observer.disconnect();
      return { ...spec, fileBytes: file?.size, samples };
    }, { spec, xlsx });
    output.cases.push(result);
    console.log(`${spec.name}: work=${result.samples.map(s => s.workMs.toFixed(1)).join(',')}ms roundtrip=${result.samples.map(s => s.roundtripMs.toFixed(1)).join(',')}ms`);
    await page.close();
    await writeFile(resolve(process.argv[2] || 'web-performance.json'), JSON.stringify(output, null, 2) + '\n');
  }
  output.diagnostics = diagnose();
  await writeFile(resolve(process.argv[2] || 'web-performance.json'), JSON.stringify(output, null, 2) + '\n');
} finally {
  await browser?.close();
  if (server) await new Promise(resolve => server.close(resolve));
  await rm(temp, { recursive: true, force: true });
}

function diagnose() {
  const engine = new CompareEngine();
  const alignment = [1999, 2000].map(rows => {
    const headers = ['ID', 'Value'];
    const fileA = { headers, rows: Array.from({ length: rows }, (_, i) => [`ID_${i}`, `old ${i}`]) };
    const fileB = { headers, rows: [['NEW', 'new'], ...fileA.rows.map(([id], i) => [id, `new ${i}`])] };
    const result = engine.compareTables(fileA, fileB, null, { alignmentMode: 'ORDERED_SEQUENCE' });
    return { rows, expected: { added_rows: 1, different: rows, exact: rows }, observed: result.summary, firstRationale: result.alignedRows[0].matchRationale };
  });
  const similarity = [1000, 1001].map(length => {
    const result = engine.compareCells('a'.repeat(length), 'b'.repeat(length));
    return { length, expectedSimilarity: 0, observedSimilarity: result.similarity, status: result.status };
  });
  return { alignment, similarity };
}
