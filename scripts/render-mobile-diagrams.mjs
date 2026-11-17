// Documentation tooling only. Does not change app code, contracts or source baselines.
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { chromium } from 'playwright';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const diagramRoot = path.join(root, 'docs-dytava/diagrams');
const mode = process.argv[2];
assert(['--check', '--render'].includes(mode) && process.argv.length === 3,
  'Usage: node scripts/render-mobile-diagrams.mjs --check|--render');
const baseline = JSON.parse(await fs.readFile(path.join(diagramRoot, 'mobile-diagrams.baseline.json'), 'utf8'));
const hash = value => createHash('sha256').update(value).digest('hex');
const read = relative => fs.readFile(path.resolve(root, relative));
const exists = async filename => fs.access(filename).then(() => true, () => false);
assert.equal(baseline.renderer.version, '11.12.2');
assert.equal(baseline.renderer.sha256, 'd0830a6c05546e9edb8fe20a8f545f3e0dc7c4c3134d584bad9c13a99d7a71e0');

for (const source of baseline.sources) {
  assert.equal(hash(await read(source.path)), source.sha256,
    `Owner source changed: ${source.path}. Review affected diagrams before updating the baseline.`);
}

const documents = [];
const diagrams = [];
for (const definition of baseline.documents) {
  const markdown = await read(definition.path).then(buffer => buffer.toString('utf8'));
  assert.equal((markdown.match(/^```/gm) ?? []).length % 2, 0, `${definition.path}: unclosed fence`);
  const blocks = [...markdown.matchAll(/^```mermaid\r?\n([\s\S]*?)\r?\n```/gm)];
  const headings = [...markdown.matchAll(/^## ((?:ACT|SEQ|ST|MOD)-\d{2})\s+[^\n]+/gm)];
  assert.equal(blocks.length, definition.diagrams.length, `${definition.path}: diagram count`);
  assert.equal(headings.length, blocks.length, `${definition.path}: one diagram per ID heading`);
  documents.push({ path: definition.path, markdown });
  blocks.forEach((block, index) => {
    const item = definition.diagrams[index];
    assert.equal(headings[index][1], item.id, `${definition.path}: unexpected diagram ID/order`);
    assert(headings[index].index < block.index, `${item.id}: heading must precede source`);
    assert(!headings[index + 1] || block.index < headings[index + 1].index, `${item.id}: wrong section`);
    diagrams.push({ ...item, code: block[1], title: headings[index][0].slice(3), sourceHash: hash(block[1]) });
  });
}
assert.equal(new Set(diagrams.map(diagram => diagram.id)).size, diagrams.length, 'Duplicate diagram ID');

const coveragePath = 'docs-dytava/diagrams/MOBILE_DIAGRAM_COVERAGE.md';
const coverage = await read(coveragePath).then(buffer => buffer.toString('utf8'));
documents.push({ path: coveragePath, markdown: coverage });
for (const [sourcePath, pattern] of [
  ['docs-dytava/requirements/SRS.md', /\bFR-\d{3}\b/g],
  ['docs-dytava/requirements/NFR.md', /\bNFR-[A-Z]+-\d{2}\b/g],
  ['docs-dytava/specs/input/README.md', /\bINP-REQ-\d{3}\b/g],
  ['docs-dytava/testing/UDG_CONTRACT_ACCEPTANCE.md', /\bUDG-L\d+-\d{2}\b/g],
]) {
  const source = await read(sourcePath).then(buffer => buffer.toString('utf8'));
  const ids = [...new Set(source.match(pattern))];
  for (const id of ids) assert(coverage.includes(`| ${id} |`), `Missing coverage row: ${id}`);
  console.log(`Coverage references: ${ids.length} IDs from ${sourcePath}`);
}
const knownDiagramIds = new Set(diagrams.map(diagram => diagram.id));
// Coverage cells may compact adjacent references as SEQ-01/02/03.
for (const match of coverage.matchAll(/\b(ACT|SEQ|ST|MOD)-(\d{2}(?:\/\d{2})*)\b/g)) {
  for (const number of match[2].split('/')) assert(knownDiagramIds.has(`${match[1]}-${number}`), `Unknown diagram reference: ${match[0]}`);
}

const cacheDir = path.join(os.tmpdir(), 'dytava-diagram-tooling');
await fs.mkdir(cacheDir, { recursive: true });
const bundlePath = path.join(cacheDir, `mermaid-${baseline.renderer.version}.min.js`);
if (!await exists(bundlePath)) {
  const response = await fetch(`https://cdn.jsdelivr.net/npm/mermaid@${baseline.renderer.version}/dist/mermaid.min.js`,
    { signal: AbortSignal.timeout(30000) });
  assert(response.ok, `Mermaid download failed: ${response.status}`);
  const bundle = Buffer.from(await response.arrayBuffer());
  assert.equal(hash(bundle), baseline.renderer.sha256, 'Downloaded Mermaid integrity mismatch');
  await fs.writeFile(bundlePath, bundle);
}
assert.equal(hash(await fs.readFile(bundlePath)), baseline.renderer.sha256, 'Cached Mermaid integrity mismatch');

const browser = await chromium.launch({ headless: true });
try {
  const page = await browser.newPage({ viewport: { width: 1800, height: 1000 }, deviceScaleFactor: 1.5 });
  page.setDefaultTimeout(30000);
  await page.setContent('<html lang="vi"><body style="margin:0;background:white"></body></html>');
  await page.addScriptTag({ path: bundlePath });
  await page.evaluate(() => mermaid.initialize({
    startOnLoad: false, securityLevel: 'strict', theme: 'base', fontFamily: 'Arial, sans-serif',
    themeVariables: {
      fontSize: '16px', primaryColor: '#eff6ff', primaryTextColor: '#17324d',
      primaryBorderColor: '#93c5fd', lineColor: '#64748b', secondaryColor: '#f0fdf4',
      tertiaryColor: '#f8fafc', edgeLabelBackground: '#ffffff',
    },
    flowchart: { htmlLabels: true, useMaxWidth: false, curve: 'linear', nodeSpacing: 32, rankSpacing: 42, padding: 14 },
    sequence: { wrap: true, width: 145, wrapPadding: 8, actorMargin: 45, messageMargin: 32, mirrorActors: false, useMaxWidth: false },
    class: { useMaxWidth: false }, er: { useMaxWidth: false }, state: { useMaxWidth: false },
  }));
  for (const [index, diagram] of diagrams.entries()) {
    const rendered = await page.evaluate(async ({ diagram, index, version }) => {
      await mermaid.parse(diagram.code);
      const { svg } = await mermaid.render(`dytava-diagram-${index + 1}`, diagram.code);
      document.body.innerHTML = svg;
      const element = document.querySelector('svg');
      element.style.background = '#ffffff';
      element.setAttribute('aria-label', diagram.title);
      element.setAttribute('data-source-sha256', diagram.sourceHash);
      element.setAttribute('data-renderer-version', version);
      const xml = new XMLSerializer().serializeToString(element);
      const parsed = new DOMParser().parseFromString(xml, 'image/svg+xml');
      if (parsed.querySelector('parsererror')) throw new Error('Generated SVG is not standalone XML');
      const clipped = [...element.querySelectorAll('g.node')].filter(node => {
        const label = node.querySelector('.label');
        if (!label) return false;
        const nodeBox = node.getBoundingClientRect(), labelBox = label.getBoundingClientRect();
        return labelBox.left < nodeBox.left - 1 || labelBox.right > nodeBox.right + 1
          || labelBox.top < nodeBox.top - 1 || labelBox.bottom > nodeBox.bottom + 1;
      });
      const edgeLabels = [...element.querySelectorAll('g.edgeLabel')]
        .filter(label => label.textContent.trim() && !label.parentElement.closest('g.edgeLabel'))
        .map(label => label.getBoundingClientRect());
      let labelCollisions = 0;
      for (let i = 0; i < edgeLabels.length; i++) for (let j = i + 1; j < edgeLabels.length; j++) {
        const a = edgeLabels[i], b = edgeLabels[j];
        if (Math.min(a.right, b.right) - Math.max(a.left, b.left) > 4
          && Math.min(a.bottom, b.bottom) - Math.max(a.top, b.top) > 4) labelCollisions++;
      }
      return { xml, clipped: clipped.length, labelCollisions, width: element.getBoundingClientRect().width, height: element.getBoundingClientRect().height };
    }, { diagram, index, version: baseline.renderer.version });
    assert.equal(rendered.clipped, 0, `${diagram.id}: label overflows its node`);
    assert.equal(rendered.labelCollisions, 0, `${diagram.id}: overlapping edge labels`);
    assert(rendered.width > 0 && rendered.height > 0, `${diagram.id}: empty layout`);
    const svgPath = path.resolve(root, diagram.svg);
    if (mode === '--render') {
      await fs.mkdir(path.dirname(svgPath), { recursive: true });
      await fs.writeFile(svgPath, `${rendered.xml}\n`);
      if (diagram.png) await page.locator('svg').screenshot({ path: path.resolve(root, diagram.png) });
      await page.locator('svg').screenshot({ path: path.join(cacheDir, `${diagram.id}.png`) });
    } else {
      const saved = await fs.readFile(svgPath, 'utf8');
      const metadata = await page.evaluate(saved => {
        const parsed = new DOMParser().parseFromString(saved, 'image/svg+xml');
        return {
          invalid: !!parsed.querySelector('parsererror'),
          hash: parsed.documentElement.getAttribute('data-source-sha256'),
          version: parsed.documentElement.getAttribute('data-renderer-version'),
        };
      }, saved);
      assert(!metadata.invalid, `${diagram.id}: saved SVG XML invalid`);
      assert.equal(metadata.hash, diagram.sourceHash, `${diagram.id}: saved SVG stale, run --render`);
      assert.equal(metadata.version, baseline.renderer.version, `${diagram.id}: renderer version mismatch`);
    }
    console.log(`${diagram.id}: ${mode === '--render' ? 'rendered' : 'checked'} (${Math.round(rendered.width)} x ${Math.round(rendered.height)})`);
  }
} finally {
  await browser.close();
}

const slug = heading => heading.toLowerCase().replace(/[^\p{L}\p{N}\p{M} _-]/gu, '').replace(/ /g, '-');
let links = 0;
for (const relative of ['docs-dytava/README.md', 'docs-dytava/diagrams/README.md']) {
  documents.push({ path: relative, markdown: await read(relative).then(buffer => buffer.toString('utf8')) });
}
for (const document of documents) {
  assert(!document.markdown.split('\n').some(line => /[\t ]+$/.test(line)), `${document.path}: trailing whitespace`);
  for (const [, rawTarget] of document.markdown.matchAll(/\]\(([^)]+)\)/g)) {
    if (/^[a-z][a-z\d+.-]*:/i.test(rawTarget)) continue;
    const [local, anchor] = decodeURIComponent(rawTarget).split('#');
    const filename = local ? path.resolve(path.dirname(path.resolve(root, document.path)), local) : path.resolve(root, document.path);
    assert(await exists(filename), `${document.path}: missing link ${rawTarget}`);
    if (anchor && filename.endsWith('.md')) {
      const target = await fs.readFile(filename, 'utf8');
      const anchors = [...target.matchAll(/^#{1,6} +(.+)$/gm)].map(match => slug(match[1]));
      assert(anchors.includes(anchor), `${document.path}: missing anchor ${rawTarget}`);
    }
    links++;
  }
}
console.log(`PASS documentation QA: ${diagrams.length} diagrams, ${baseline.sources.length} source fingerprints, ${links} local links/anchors.`);
console.log('No runtime, device, benchmark or acceptance-test compliance is asserted.');
