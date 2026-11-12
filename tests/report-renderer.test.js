import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { renderReport } from '../web/js/report/renderer.js';
import { z } from 'zod';
import { reportSchema, validateReport } from '../web/js/report/model.js';
import { CompareEngine } from '../web/js/compare-engine.js';
import { SAMPLE_DATASETS } from '../web/js/sample-data.js';
const fixture = JSON.parse(readFileSync(new URL('../docs-dytava/examples/report-renderer/report.json', import.meta.url)));
const fresh = () => structuredClone(fixture);

test('template fixture hashes real source bytes and preserves all eight sections/statuses without mutation', () => {
  for (const side of ['A','B']) {
    const bytes = readFileSync(new URL(`../docs-dytava/examples/report-renderer/source-${side.toLowerCase()}.csv`, import.meta.url));
    assert.equal(createHash('sha256').update(bytes).digest('hex'), fixture.inputs[side].sha256);
    assert.equal(bytes.length, fixture.inputs[side].size_bytes);
  }
  const data = fresh(), original = structuredClone(data);
  const { html, manifest } = renderReport(data);
  assert.deepEqual(data, original);
  for (const section of ['cover','sources','summary','method','details','warnings','conclusion','audit']) assert.ok(html.includes(`data-section="${section}"`));
  for (const status of ['EXACT','EQUIVALENT','DIFFERENT','UNRESOLVED']) assert.ok(html.includes(status));
  assert.equal(manifest.exported_cell_details,4);
  assert.ok(html.includes('8,5')); assert.ok(html.includes('Nguyễn Ánh'));
  assert.ok(!html.includes('source-a.csv')); // Display names are opt-in.
});

test('rejects stale, partial, pending OCR, missing lineage and invalid template', () => {
  for (const mutate of [r=>r.current=false,r=>r.completion_state='CANCELLED',r=>r.ocr_review='PENDING',r=>r.inputs.A.sha256=null,r=>r.direction_confirmed=false,r=>r.differences[1].rule_id=null,r=>r.differences[0].left.reference=null]) {
    const r=fresh();mutate(r);assert.throws(()=>renderReport(r));
  }
  assert.throws(()=>renderReport(fresh(),{templateVersion:'unregistered'}));
});

test('reconciles cell/structural summary and never silently truncates or drops unresolved', () => {
  let r=fresh();r.summary.matched_cell_pairs++;assert.throws(()=>renderReport(r));
  r=fresh();r.differences.pop();assert.throws(()=>renderReport(r));
  r=fresh();r.details_scope='DIFFERENCES_ONLY';r.differences=r.differences.filter(d=>!['EXACT','UNRESOLVED'].includes(d.status));assert.throws(()=>renderReport(r));
  assert.throws(()=>validateReport(fresh(),{maxDetails:1}));
  assert.throws(()=>validateReport(fresh(),{maxTextBytes:10}));
});

test('escapes hostile report text, preserves null/empty/zero and rejects hidden access fields', () => {
  const r=fresh();r.differences[0].left.raw='<script>alert(1)</script><img src="https://evil.test">';
  let out=renderReport(r).html;assert.ok(!out.includes('<script>'));assert.ok(out.includes('&lt;script&gt;'));
  r.differences[0].left.raw=null;assert.ok(renderReport(r).html.includes('[NULL]'));
  r.differences[0].left.raw='';assert.ok(renderReport(r).html.includes('[EMPTY STRING'));
  r.differences[0].left.raw=0;assert.ok(renderReport(r).html.includes('<pre>0</pre>'));
  r.differences[0].left.raw_kind='BLANK';assert.ok(renderReport(r).html.includes('[BLANK'));
  r.inputs.A.access_ref='private-secret';assert.throws(()=>renderReport(r));
});

test('zero denominator is N/A and never makes a full-match claim', () => {
  const r=fresh();r.summary={...r.summary,matched_cell_pairs:0,exact:0,equivalent:0,different:0,unresolved:0};r.differences=r.differences.filter(d=>d.kind!=='CELL');
  const html=renderReport(r).html;assert.ok(html.includes('N/A'));assert.ok(html.includes('Không có matched cell pairs'));
});

test('legacy web adapter is explicit and visibly discloses missing evidence', () => {
  const sample=SAMPLE_DATASETS.academic;
  const {report}=new CompareEngine().compareTables(sample.fileA,sample.fileB,'Mã SV');
  assert.throws(()=>renderReport(report));
  const out=renderReport(report,{allowLegacy:true});
  assert.equal(out.manifest.metadata_complete,false);assert.equal(out.manifest.source_hashes.A,null);
  assert.ok(out.html.includes('Metadata chưa đầy đủ'));assert.ok(out.html.includes('SourceRef chưa cung cấp'));
});

test('published JSON Schema stays in sync with the runtime shape', () => {
  const { $id, ...schema } = JSON.parse(readFileSync(new URL('../docs-dytava/specs/report/schemas/dytava-report.schema.json', import.meta.url)));
  assert.ok($id.endsWith('/1.0.0/dytava-report.schema.json'));
  assert.deepEqual(schema, z.toJSONSchema(reportSchema));
});
