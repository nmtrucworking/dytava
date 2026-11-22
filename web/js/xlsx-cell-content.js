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
const colLetters = colZeroBased => {
  let col = colZeroBased + 1, out = '';
  while (col > 0) { col--; out = String.fromCharCode(65 + (col % 26)) + out; col = Math.floor(col / 26); }
  return out;
};
const mimeFromExt = ext => ({
  png: 'image/png',
  jpg: 'image/jpeg',
  jpeg: 'image/jpeg',
  gif: 'image/gif',
  webp: 'image/webp',
  bmp: 'image/bmp',
  svg: 'image/svg+xml',
}[String(ext || '').toLowerCase()] || 'image/png');
const toDataUrl = (bytes, ext) => {
  let bin = '';
  for (let i = 0; i < bytes.length; i++) bin += String.fromCharCode(bytes[i]);
  return `data:${mimeFromExt(ext)};base64,${btoa(bin)}`;
};

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
  async function loadAsset(mediaPath) {
    const bytes = mediaPath ? entries[mediaPath] : null;
    if (!bytes?.length) return null;
    let asset = digestCache.get(mediaPath);
    if (!asset) {
      const hash = [...new Uint8Array(await crypto.subtle.digest('SHA-256', bytes))].map(v => v.toString(16).padStart(2, '0')).join('');
      const mediaType = mediaPath.split('.').pop().toLowerCase();
      asset = { bytes, digest: hash, mediaType, dataUrl: toDataUrl(bytes, mediaType) };
      digestCache.set(mediaPath, asset);
    }
    return asset;
  }
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
    const asset = rel?.Type?.endsWith('/image') && rel.path ? await loadAsset(rel.path) : null;
    if (!asset) return unresolved('Thiếu media hoặc ảnh là liên kết ngoài');
    return { kind: 'image', imagePlacement: 'placeInCell', ...asset, label: `[Ảnh trong ô · SHA-256 ${asset.digest}]` };
  }
  async function inspectSheetDrawings(sheetPath) {
    const sheetRels = relationships(entries, sheetPath);
    const summaries = [];
    const anchoredCells = new Map();
    for (const rel of sheetRels.values()) {
      if (!rel.Type?.endsWith('/drawing') || !rel.path) continue;
      const drawingDoc = xmlTree(entries[rel.path]);
      if (!drawingDoc) continue;
      const drawingRels = relationships(entries, rel.path);
      for (const anchorTag of ['twoCellAnchor', 'oneCellAnchor', 'absoluteAnchor']) {
        for (const anchor of descendants(drawingDoc, anchorTag)) {
          const fromElem = descendants(anchor, 'from')[0];
          let anchorCell = null;
          if (fromElem) {
            const col = nonnegative(descendants(fromElem, 'col')[0]?.text?.trim());
            const row = nonnegative(descendants(fromElem, 'row')[0]?.text?.trim());
            if (col >= 0 && row >= 0) anchorCell = `${colLetters(col)}${row + 1}`;
          }
          const blip = descendants(anchor, 'blip')[0];
          const embedId = blip?.attrs?.embed;
          const mediaRel = embedId ? drawingRels.get(embedId) : null;
          const asset = mediaRel?.path ? await loadAsset(mediaRel.path) : null;
          if (asset) {
            const shortHash = asset.digest.slice(0, 8);
            const cellValue = {
              kind: 'image',
              imagePlacement: 'drawingAnchor',
              ...asset,
              label: `[Ảnh đặt thủ công${anchorCell ? ` · neo ${anchorCell}` : ''} · SHA-256 ${asset.digest}]`,
            };
            if (anchorCell && !anchoredCells.has(anchorCell)) anchoredCells.set(anchorCell, cellValue);
            summaries.push(anchorCell ? `neo gần ${anchorCell} · SHA ${shortHash}` : `tọa độ tự do · SHA ${shortHash}`);
          } else if (anchorCell) {
            summaries.push(`neo gần ${anchorCell}`);
          }
        }
      }
    }
    return { summaries, anchoredCells };
  }
  const result = new Map();
  for (const sheet of descendants(wb, 'sheet')) {
    const rel = wbRels.get(sheet.attrs.id), cells = new Map(), warnings = [], pending = [];
    if (!sheet.attrs.name?.trim() || result.has(sheet.attrs.name)) throw new Error('Tên worksheet bị thiếu hoặc trùng.');
    if (!rel?.path) throw new Error(`Thiếu relationship của sheet ${sheet.attrs.name}.`);
    if (rel.Type && !rel.Type.endsWith('/worksheet')) throw new Error(`Sheet ${sheet.attrs.name}: loại ${rel.Type.split('/').pop()} chưa được hỗ trợ trong so sánh worksheet.`);
    const data = entries[rel.path]; if (!data) throw new Error(`Thiếu dữ liệu của sheet ${sheet.attrs.name}.`);
    const parser = new SaxesParser({ xmlns: true });
    let cell = null, formula = false, hasDrawing = false;
    parser.on('doctype', () => { throw new Error('Không hỗ trợ DTD trong workbook.'); });
    parser.on('opentag', tag => {
      const attrs = Object.fromEntries(Object.values(tag.attributes).map(a => [a.local, a.value]));
      if (tag.local === 'c') cell = { ...attrs, formula: '' };
      if (tag.local === 'f') formula = true;
      if (tag.local === 'drawing' || tag.local === 'legacyDrawing') hasDrawing = true;
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
    if (hasDrawing) {
      const { summaries, anchoredCells } = await inspectSheetDrawings(rel.path);
      for (const [addr, val] of anchoredCells) {
        if (!cells.has(addr)) cells.set(addr, val);
      }
      if (summaries.length) {
        warnings.push(`${sheet.attrs.name}: có ${summaries.length} ảnh/đối tượng nổi (${summaries.join(', ')}) đặt thủ công trên sheet (Place over Cells).`);
      } else {
        warnings.push(`${sheet.attrs.name}: ảnh/đối tượng nổi chưa được so sánh như ô.`);
      }
    }
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
    const placementA = a.imagePlacement, placementB = b.imagePlacement;
    const placementLabel = (placementA === 'drawingAnchor' || placementB === 'drawingAnchor')
      ? (placementA === placementB ? 'ảnh đặt thủ công (Place over Cells)' : `ảnh nhúng (${placementA === 'drawingAnchor' ? 'đặt thủ công' : 'trong ô'} ↔ ${placementB === 'drawingAnchor' ? 'đặt thủ công' : 'trong ô'})`)
      : 'ảnh nhúng';
    status = same ? 'EXACT' : 'DIFFERENT'; reason = same ? `Nội dung nhị phân ${placementLabel} giống nhau.` : `Nội dung nhị phân ${placementLabel} khác nhau; chưa kết luận tương đương hình ảnh.`;
  }
  return {
    status,
    type: 'image',
    rawA,
    rawB,
    normA: a?.digest ?? rawA,
    normB: b?.digest ?? rawB,
    imageDataUrlA: a?.dataUrl ?? null,
    imageDataUrlB: b?.dataUrl ?? null,
    imagePlacementA: a?.imagePlacement ?? null,
    imagePlacementB: b?.imagePlacement ?? null,
    imageDigestA: a?.digest ?? null,
    imageDigestB: b?.digest ?? null,
    ruleId: status === 'UNRESOLVED' ? 'content/unsupported' : 'image/bytes',
    reason,
  };
}
