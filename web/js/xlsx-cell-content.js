import { SaxesParser } from 'saxes';
import { strFromU8 } from 'fflate';

const children = (n, name) => (n?.children || []).filter(x => x.name === name);
const descendants = (n, name) => (n?.children || []).flatMap(x => [...(x.name === name ? [x] : []), ...descendants(x, name)]);
function xmlTree(data) {
  if (!data) return null;
  const root = { children: [] }, stack = [root], parser = new SaxesParser({ xmlns: true });
  parser.on('doctype', () => { throw new Error('Không hỗ trợ DTD trong workbook.'); });
  parser.on('opentag', tag => {
    const node = { name: tag.local, attrs: Object.fromEntries(Object.values(tag.attributes).map(a => [a.local, a.value])), children: [], text: '' };
    stack.at(-1).children.push(node); stack.push(node);
  });
  parser.on('text', t => { stack.at(-1).text += t; });
  parser.on('closetag', () => { stack.pop(); });
  parser.write(strFromU8(data)).close();
  return root;
}
export function resolvePart(owner, target) {
  if (!target || /^[a-z][a-z\d+.-]*:/i.test(target) || /[\\?#]/.test(target)) return null;
  const parts = target.startsWith('/') ? [] : owner.split('/').slice(0, -1);
  for (const part of target.split('/')) {
    if (!part || part === '.') continue;
    if (part === '..') { if (!parts.length) return null; parts.pop(); } else parts.push(part);
  }
  return parts.join('/');
}
function relationships(entries, owner) {
  const parts = owner.split('/'), file = parts.pop(), path = [...parts, '_rels', `${file}.rels`].join('/');
  return new Map(descendants(xmlTree(entries[path]), 'Relationship').map(n => [n.attrs.Id, { ...n.attrs, path: n.attrs.TargetMode === 'External' ? null : resolvePart(owner, n.attrs.Target) }]));
}
const nonnegative = value => /^\d+$/.test(value ?? '') ? Number(value) : -1;

// Read the original package, before ExcelJS can flatten rich values into #VALUE!.
export async function inspectCellContent(entries) {
  const workbookPath = 'xl/workbook.xml', wb = xmlTree(entries[workbookPath]), wbRels = relationships(entries, workbookPath);
  const related = (suffix, fallback, owners = [workbookPath]) => {
    for (const owner of owners) for (const r of relationships(entries, owner).values()) if (r.Type?.endsWith(`/${suffix}`)) return r.path;
    return entries[fallback] ? fallback : null;
  };
  const metadataPath = related('sheetMetadata', 'xl/metadata.xml'), metadata = xmlTree(entries[metadataPath]);
  const owners = [workbookPath, ...(metadataPath ? [metadataPath] : [])];
  const values = descendants(xmlTree(entries[related('rdRichValue', 'xl/richData/rdrichvalue.xml', owners)]), 'rv');
  const structures = descendants(xmlTree(entries[related('rdRichValueStructure', 'xl/richData/rdrichvaluestructure.xml', owners)]), 's');
  const richRelPath = related('richValueRel', 'xl/richData/richValueRel.xml', owners);
  const richIds = descendants(xmlTree(entries[richRelPath]), 'rel').map(n => n.attrs.id);
  const mediaRels = richRelPath ? relationships(entries, richRelPath) : new Map();
  const metadataTypes = descendants(metadata, 'metadataType');
  const valueBlocks = children(descendants(metadata, 'valueMetadata')[0], 'bk');
  const futures = descendants(metadata, 'futureMetadata');
  const digestCache = new Map();
  const unresolved = reason => ({ kind: 'unsupported', reason, label: `[Chưa đọc được nội dung ô: ${reason}]` });
  async function richCell(vm) {
    const index = nonnegative(vm), block = valueBlocks[index - 1];
    if (index < 1 || !block) return unresolved('Metadata ô không hợp lệ');
    const rc = children(block, 'rc').find(n => metadataTypes[nonnegative(n.attrs.t) - 1]?.attrs.name === 'XLRICHVALUE');
    if (!rc) return unresolved('Kiểu dữ liệu liên kết chưa hỗ trợ');
    const future = futures.find(n => n.attrs.name === 'XLRICHVALUE');
    const rvb = descendants(children(future, 'bk')[nonnegative(rc.attrs.v)], 'rvb')[0];
    const rv = values[nonnegative(rvb?.attrs.i)], structure = structures[nonnegative(rv?.attrs.s)];
    if (structure?.attrs.t !== '_localImage') return unresolved('Rich value chưa hỗ trợ hoặc thiếu cấu trúc ảnh');
    const keys = children(structure, 'k'), vals = children(rv, 'v');
    const field = keys.findIndex(k => k.attrs.n === '_rvRel:LocalImageIdentifier');
    const relId = richIds[nonnegative(vals[field]?.text)], rel = mediaRels.get(relId);
    const bytes = rel?.Type?.endsWith('/image') && rel.path ? entries[rel.path] : null;
    if (!bytes?.length) return unresolved('Thiếu media hoặc ảnh là liên kết ngoài');
    let asset = digestCache.get(rel.path);
    if (!asset) {
      const hash = [...new Uint8Array(await crypto.subtle.digest('SHA-256', bytes))].map(v => v.toString(16).padStart(2, '0')).join('');
      asset = { bytes, digest: hash, mediaType: rel.path.split('.').pop().toLowerCase() };
      digestCache.set(rel.path, asset);
    }
    return { kind: 'image', ...asset, label: `[Ảnh nhúng · SHA-256 ${asset.digest}]` };
  }
  const result = new Map();
  for (const sheet of descendants(wb, 'sheet')) {
    const rel = wbRels.get(sheet.attrs.id), cells = new Map(), warnings = [], pending = [];
    if (!sheet.attrs.name?.trim() || result.has(sheet.attrs.name)) throw new Error('Tên worksheet bị thiếu hoặc trùng.');
    if (!rel?.path) throw new Error(`Thiếu relationship của sheet ${sheet.attrs.name}.`);
    if (rel.Type && !rel.Type.endsWith('/worksheet')) throw new Error(`Sheet ${sheet.attrs.name}: loại ${rel.Type.split('/').pop()} chưa được hỗ trợ trong so sánh worksheet.`);
    const data = entries[rel.path]; if (!data) throw new Error(`Thiếu dữ liệu của sheet ${sheet.attrs.name}.`);
    const parser = new SaxesParser({ xmlns: true });
    let cell = null, formula = false;
    parser.on('doctype', () => { throw new Error('Không hỗ trợ DTD trong workbook.'); });
    parser.on('opentag', tag => {
      const attrs = Object.fromEntries(Object.values(tag.attributes).map(a => [a.local, a.value]));
      if (tag.local === 'c') cell = { ...attrs, formula: '' };
      if (tag.local === 'f') formula = true;
      if (tag.local === 'drawing' || tag.local === 'legacyDrawing') warnings.push(`${sheet.attrs.name}: ảnh/đối tượng nổi chưa được so sánh như ô.`);
      if (tag.local === 'oleObject') warnings.push(`${sheet.attrs.name}: đối tượng OLE nhúng chưa được so sánh.`);
      if (tag.local === 'mergeCell') warnings.push(`${sheet.attrs.name}: ô gộp giữ giá trị tại ô neo; không tự điền xuống.`);
    });
    parser.on('text', t => { if (cell && formula) cell.formula += t; });
    parser.on('closetag', tag => {
      if (tag.local === 'f') formula = false;
      if (tag.local !== 'c' || !cell) return;
      const c = cell; cell = null;
      if (c.vm !== undefined) pending.push(richCell(c.vm).then(value => cells.set(c.r, value)));
      else if (/(?:^|[^\w.])(?:_xlfn\.)?(?:_xlws\.)?(?:IMAGE|DISPIMG)\s*\(/i.test(c.formula)) cells.set(c.r, unresolved('Công thức ảnh/ảnh từ URL chưa có dữ liệu ảnh nhúng được xác thực'));
    });
    parser.write(strFromU8(data)).close();
    await Promise.all(pending);
    result.set(sheet.attrs.name, { cells, warnings: [...new Set(warnings)], state: sheet.attrs.state ?? 'visible' });
  }
  return result;
}
export function compareSpecialCells(a, b, rawA, rawB) {
  if (!a && !b) return null;
  let status, reason;
  if (a?.kind === 'unsupported' || b?.kind === 'unsupported') {
    status = 'UNRESOLVED'; reason = a?.reason || b?.reason;
  } else if (a?.kind !== 'image' || b?.kind !== 'image') {
    status = 'DIFFERENT'; reason = 'Một ô là ảnh, ô còn lại có kiểu dữ liệu khác.';
  } else {
    const same = a.digest === b.digest && a.bytes.length === b.bytes.length && a.bytes.every((v, i) => v === b.bytes[i]);
    status = same ? 'EXACT' : 'DIFFERENT'; reason = same ? 'Nội dung nhị phân ảnh nhúng giống nhau.' : 'Nội dung nhị phân ảnh nhúng khác nhau; chưa kết luận tương đương hình ảnh.';
  }
  return { status, type: 'image', rawA, rawB, normA: a?.digest ?? rawA, normB: b?.digest ?? rawB, ruleId: status === 'UNRESOLVED' ? 'content/unsupported' : 'image/bytes', reason };
}
