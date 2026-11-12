import { readFile, writeFile, mkdir, rename, rm, mkdtemp } from 'node:fs/promises';
import { parseArgs } from 'node:util';
import { fileURLToPath } from 'node:url';
import { resolve, dirname, basename, join } from 'node:path';
import { createHash } from 'node:crypto';
import { chromium } from '@playwright/test';
import { renderReport, escape } from '../web/js/report/renderer.js';

const root = fileURLToPath(new URL('../', import.meta.url));
const { values } = parseArgs({ options: { input: { type: 'string' }, output: { type: 'string' }, timezone: { type: 'string', default: 'Asia/Ho_Chi_Minh' }, 'allow-legacy': { type: 'boolean', default: false } } });
const source = resolve(values.input || join(root, 'docs-dytava/examples/report-renderer/report.json'));
const output = resolve(values.output || join(root, 'output/pdf/dytava-report.pdf'));
if (!output.endsWith('.pdf') || output === source) throw new Error('Output phải là PDF mới, khác file input.');
const inputBytes = await readFile(source);
if (inputBytes.length > 2_000_000) throw new Error('Report JSON vượt budget 2 MB; không tự cắt dữ liệu.');
const report = JSON.parse(inputBytes);
const paths = ['brand/svg/dytava-horizontal.svg', 'illustrations/svg/wide/onboarding-report.svg', ...['exact', 'equivalent', 'different', 'unresolved', 'added', 'removed'].map(s => `icons/svg/color/${s}.svg`)];
const assets = Object.fromEntries(await Promise.all(paths.map(async path => [path, `data:image/svg+xml;base64,${(await readFile(join(root, 'branding/mobile/assets/dytava', path))).toString('base64')}`])));
const { html, manifest } = renderReport(report, { allowLegacy: values['allow-legacy'], timezone: values.timezone, asset: path => assets[path] });
const [fontCss, tokenCss, reportCss] = await Promise.all(['web/css/fonts.css', 'web/css/brand-tokens.css', 'web/css/report.css'].map(p => readFile(join(root, p), 'utf8')));
const fontPaths = [...new Set([...fontCss.matchAll(/url\('\.\.\/assets\/fonts\/([^']+)'\)/g)].map(m => m[1]))];
let fonts = fontCss;
for (const font of fontPaths) fonts = fonts.replaceAll(`../assets/fonts/${font}`, `data:font/woff2;base64,${(await readFile(join(root, 'web/assets/fonts', font))).toString('base64')}`);
const document = `<!doctype html><html lang="vi"><head><meta charset="utf-8"><meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; img-src data:; font-src data:; script-src 'none'; connect-src 'none'; object-src 'none'; base-uri 'none'"><title>Báo cáo Dytava</title><style>${fonts}\n${tokenCss}\n${reportCss}</style></head><body>${html}</body></html>`;
await mkdir(dirname(output), { recursive: true });
const temp = await mkdtemp(join(dirname(output), '.dytava-report-'));
let browser;
try {
  browser = await chromium.launch();
  const context = await browser.newContext({ javaScriptEnabled: false });
  const page = await context.newPage();
  await page.route(/^https?:/, route => route.abort());
  await page.setContent(document, { waitUntil: 'load' });
  await page.evaluate(async () => { await document.fonts.ready; await Promise.all([...document.images].map(img => img.decode())); });
  await page.emulateMedia({ media: 'print' });
  const pdf = await page.pdf({ format: 'A4', preferCSSPageSize: true, printBackground: true, tagged: true, outline: true, displayHeaderFooter: true,
    headerTemplate: '<div></div>', footerTemplate: `<div style="width:100%;font-size:8px;color:#64748B;padding:0 56px;display:flex;justify-content:space-between"><span>Dytava · ${escape(manifest.report_id)}</span><span>Trang <span class="pageNumber"></span>/<span class="totalPages"></span></span></div>` });
  if (!pdf.subarray(0, 5).equals(Buffer.from('%PDF-'))) throw new Error('PDF render thất bại.');
  const completed = { ...manifest, created_at: new Date().toISOString(), exporter_version: '1.0.0-chromium', output_byte_size: pdf.length, output_sha256: createHash('sha256').update(pdf).digest('hex'), completion_state: 'COMPLETE' };
  await writeFile(join(temp, 'report.pdf'), pdf);
  await writeFile(join(temp, 'report.html'), document);
  await writeFile(join(temp, 'manifest.json'), JSON.stringify(completed, null, 2) + '\n');
  // Temp lives on the destination filesystem. No partial PDF is published.
  await rename(join(temp, 'report.pdf'), output);
  await rename(join(temp, 'report.html'), output.replace(/\.pdf$/, '.html'));
  await rename(join(temp, 'manifest.json'), output.replace(/\.pdf$/, '.manifest.json'));
  console.log(`Đã tạo ${basename(output)} (${pdf.length} byte), HTML và manifest SHA-256.`);
} finally {
  await browser?.close();
  await rm(temp, { recursive: true, force: true });
}
