// Keep this contract in parity with excelcompare_core/src/sheet_mapping.dart.
export const normalizeSheetLabel = value => String(value ?? '').trim().toLowerCase().replace(/\s+/g, ' ');
export const isGenericSheetName = value => !normalizeSheetLabel(value) || /^(sheet|trang(?: tính)?|worksheet|tabelle|feuille|hoja)[ _-]*\d*$/i.test(normalizeSheetLabel(value));
const genericHeader = h => !h || /^(cột|column|col)[ _-]*\d+(?: \(\d+\))?$/i.test(h);
export function describeSheet(table) {
  const headers = table.headers.map(normalizeSheetLabel);
  const types = headers.map((_, c) => {
    const counts = new Map();
    for (let r = 0; r < Math.min(table.rows.length, 64); r++) {
      const v = String(table.rows[r][c] ?? '').trim();
      if (!v) continue;
      const special = table.specialCells?.[`${r},${c}`];
      const type = special?.kind || (/^\d{4}-\d\d-\d\d/.test(v) ? 'date' : /^(true|false)$/i.test(v) ? 'boolean' : /^0\d+$/.test(v) ? 'identifier' : /^[+-]?\d+(?:[.,]\d+)?%?$/.test(v) ? 'number' : 'text');
      counts.set(type, (counts.get(type) || 0) + 1);
    }
    return [...counts].sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0]))[0]?.[0] || 'empty';
  });
  return { name: table.sheetName ?? table.name ?? '', headers, types };
}
export function sheetStructureScore(a, b) {
  const ha = new Set(a.headers.filter(h => !genericHeader(h))), hb = new Set(b.headers.filter(h => !genericHeader(h)));
  const overlap = [...ha].filter(h => hb.has(h));
  if (!ha.size || !hb.size || !overlap.length) return 0;
  const labels = 2 * overlap.length / (ha.size + hb.size);
  const width = Math.min(a.headers.length, b.headers.length) / Math.max(a.headers.length, b.headers.length, 1);
  let known = 0, same = 0;
  for (const h of overlap) {
    const x = a.types?.[a.headers.indexOf(h)], y = b.types?.[b.headers.indexOf(h)];
    if (x && y && x !== 'empty' && y !== 'empty') { known++; if (x === y) same++; }
  }
  return 0.75 * labels + 0.15 * width + 0.1 * (known ? same / known : 0.5);
}
export function mapSheets(a, b, overrides = []) {
  const remainingA = new Set(a.map((_, i) => i)), remainingB = new Set(b.map((_, i) => i));
  const pairs = [];
  const take = (i, j, method, score = 1) => {
    if ((i !== null && !remainingA.has(i)) || (j !== null && !remainingB.has(j))) throw new Error('Ánh xạ sheet phải một–một và trỏ tới sheet tồn tại.');
    if (i !== null) remainingA.delete(i); if (j !== null) remainingB.delete(j);
    pairs.push({ id: `sheet:${i ?? '-'}:${j ?? '-'}`, a: i, b: j, nameA: i === null ? null : a[i].name, nameB: j === null ? null : b[j].name, method, score });
  };
  for (const m of overrides) {
    const i = m.a === null ? null : a.findIndex(s => s.name === m.a), j = m.b === null ? null : b.findIndex(s => s.name === m.b);
    if ((i === null && j === null) || i === -1 || j === -1) throw new Error('Không tìm thấy sheet trong ánh xạ đã chọn.');
    take(i, j, 'manual');
  }
  // Exact names win; generic Excel labels carry no identity evidence.
  for (const normalize of [s => s, normalizeSheetLabel]) {
    for (const i of [...remainingA]) {
      if (isGenericSheetName(a[i].name)) continue;
      const label = normalize(a[i].name);
      const aa = [...remainingA].filter(k => !isGenericSheetName(a[k].name) && normalize(a[k].name) === label);
      const bb = [...remainingB].filter(k => !isGenericSheetName(b[k].name) && normalize(b[k].name) === label);
      if (aa.length === 1 && bb.length === 1) take(i, bb[0], 'name');
    }
  }
  // Conservative mutual best: compute all candidates before consuming any pair.
  const candidates = [];
  for (const i of remainingA) for (const j of remainingB) candidates.push({ i, j, score: sheetStructureScore(a[i], b[j]) });
  for (const c of candidates) {
    if (c.score < 0.8) continue;
    const rivalA = Math.max(0, ...candidates.filter(x => x.i === c.i && x.j !== c.j).map(x => x.score));
    const rivalB = Math.max(0, ...candidates.filter(x => x.j === c.j && x.i !== c.i).map(x => x.score));
    if (c.score - rivalA >= 0.08 && c.score - rivalB >= 0.08) take(c.i, c.j, 'structure', c.score);
  }
  const pending = remainingA.size && remainingB.size;
  const unresolvedA = pending ? [...remainingA] : [], unresolvedB = pending ? [...remainingB] : [];
  if (!pending) {
    for (const i of remainingA) take(i, null, 'only-a');
    for (const j of remainingB) take(null, j, 'only-b');
  }
  return { pairs, unresolvedA, unresolvedB, complete: !pending };
}
