import { cp, mkdir, readFile, rm, writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const root = fileURLToPath(new URL('../', import.meta.url));
const vault = path.join(root, 'branding/mobile/assets/dytava');
const illustrations = path.join(root, 'branding/DYTAVA_Illustration_Library_v1/mobile/assets/dytava/illustrations/svg');

const MOBILE_BRAND_SVGS = ['dytava-app.svg', 'dytava-horizontal.svg'];
const MOBILE_FORMAT_SVGS = [
  'file-csv.svg',
  'file-jpg.svg',
  'file-json.svg',
  'file-png.svg',
  'file-tsv.svg',
  'file-xlsx.svg'
];
const MOBILE_GLYPH_ICONS = [
  'added.svg', 'back.svg', 'camera.svg', 'cancel.svg', 'cells.svg', 'check.svg',
  'close.svg', 'columns.svg', 'compare-files.svg', 'compare-progress.svg',
  'compare.svg', 'copy.svg', 'crop.svg', 'delete.svg', 'differences.svg',
  'different.svg', 'dtype-boolean.svg', 'dtype-decimal.svg', 'dtype-identifier.svg',
  'dtype-percentage.svg', 'dtype-string.svg', 'duplicate.svg', 'edit.svg',
  'empty.svg', 'equivalent.svg', 'error.svg', 'exact.svg', 'expand.svg',
  'export.svg', 'files.svg', 'filter.svg', 'forward.svg', 'help.svg',
  'history.svg', 'home.svg', 'import.svg', 'info.svg', 'key.svg', 'learn.svg',
  'link.svg', 'loading.svg', 'mapping.svg', 'normalize.svg', 'ocr.svg',
  'offline.svg', 'open-external.svg', 'partial.svg', 'pending.svg', 'play.svg',
  'plus.svg', 'policy.svg', 'preview.svg', 'privacy.svg', 'removed.svg',
  'report.svg', 'rotate.svg', 'rows.svg', 'save-rule.svg', 'search.svg',
  'settings.svg', 'shield.svg', 'sort.svg', 'success.svg', 'unresolved.svg',
  'upload.svg', 'warning.svg', 'workbook.svg'
];
const MOBILE_SQUARE_ILLUSTRATIONS = [
  'empty-comparisons.svg', 'empty-files.svg', 'empty-filter.svg',
  'empty-mapping.svg', 'empty-ocr.svg', 'security-local.svg',
  'status-cancelled.svg', 'status-different.svg', 'status-equivalent.svg',
  'status-error.svg', 'status-exact.svg', 'status-file-corrupt.svg',
  'status-memory-limit.svg', 'status-no-permission.svg', 'status-unresolved.svg',
  'status-unsupported-format.svg', 'status-warning.svg', 'success-compare.svg',
  'success-import.svg'
];
const MOBILE_WIDE_ILLUSTRATIONS = [
  'hero-empty-workspace.svg', 'hero-get-started.svg', 'onboarding-compare.svg',
  'onboarding-import.svg', 'onboarding-mapping.svg', 'onboarding-policy.svg',
  'onboarding-report.svg'
];

// Keep the approved vault as the source for both applications. Ship vectors only.
export async function syncBranding(targets = ['web', 'mobile']) {
  const tokens = JSON.parse(await readFile(path.join(vault, 'design_tokens.json'), 'utf8'));
  if (targets.includes('web')) {
    const destination = path.join(root, 'web/assets/dytava');
    await mkdir(destination, { recursive: true });
    for (const folder of ['brand/svg', 'icons/svg/color', 'icons/svg/outline', 'formats/svg']) {
      await cp(path.join(vault, folder), path.join(destination, folder), { recursive: true });
    }
    await cp(illustrations, path.join(destination, 'illustrations/svg'), { recursive: true });
    await cp(path.join(vault, 'design_tokens.json'), path.join(destination, 'design_tokens.json'));

    const cssLines = [
      '/* Generated from branding/mobile/assets/dytava/design_tokens.json (Precision Workspace v3.2). */',
      ':root {',
      ...Object.entries(tokens.palette).map(([name, value]) => `  --brand-${name.replaceAll('_', '-')}: ${value.hex};`),
      '  /* Semantic Aliases for UI & Theme Compatibility */',
      '  --brand-primary: var(--brand-lime-primary);',
      '  --brand-primary-hover: var(--brand-lime-600);',
      '  --brand-secondary: var(--brand-graphite);',
      '  --brand-text: var(--brand-graphite);',
      '  --brand-signal-lime: var(--brand-lime-primary);',
      '  --brand-warm-white: var(--brand-off-white);',
      '  --brand-warm-canvas: var(--brand-off-white);',
      '  --brand-border: var(--brand-border-subtle);',
      '  --brand-white: #FFFFFF;',
      '}'
    ].join('\n');
    await writeFile(path.join(root, 'web/css/brand-tokens.css'), cssLines + '\n');
    await cp(path.join(vault, 'design_tokens.json'), path.join(root, 'web/assets/design-tokens.json'));
  }

  if (targets.includes('mobile')) {
    const destination = path.join(root, 'mobile/assets/dytava');
    for (const subdir of ['adaptive', 'brand', 'formats', 'icons', 'illustrations', 'design_tokens.json']) {
      await rm(path.join(destination, subdir), { recursive: true, force: true });
    }
    for (const folder of [
      'brand/svg',
      'formats/svg',
      'icons/svg/glyph',
      'illustrations/svg/square',
      'illustrations/svg/wide'
    ]) {
      await mkdir(path.join(destination, folder), { recursive: true });
    }
    for (const file of MOBILE_BRAND_SVGS) {
      await cp(path.join(vault, 'brand/svg', file), path.join(destination, 'brand/svg', file));
    }
    for (const file of MOBILE_FORMAT_SVGS) {
      await cp(path.join(vault, 'formats/svg', file), path.join(destination, 'formats/svg', file));
    }
    for (const file of MOBILE_GLYPH_ICONS) {
      await cp(path.join(vault, 'icons/svg/glyph', file), path.join(destination, 'icons/svg/glyph', file));
    }
    for (const file of MOBILE_SQUARE_ILLUSTRATIONS) {
      await cp(path.join(illustrations, 'square', file), path.join(destination, 'illustrations/svg/square', file));
    }
    for (const file of MOBILE_WIDE_ILLUSTRATIONS) {
      await cp(path.join(illustrations, 'wide', file), path.join(destination, 'illustrations/svg/wide', file));
    }
  }
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  await syncBranding();
  console.log('Đã đồng bộ branding SVG cho web và mobile.');
}
