import { cp, mkdir, readFile, writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const root = fileURLToPath(new URL('../', import.meta.url));
const vault = path.join(root, 'branding/mobile/assets/dytava');
const illustrations = path.join(root, 'branding/DYTAVA_Illustration_Library_v1/mobile/assets/dytava/illustrations/svg');

// Keep the approved vault as the source for both applications. Ship vectors only.
export async function syncBranding(targets = ['web', 'mobile']) {
  const tokens = JSON.parse(await readFile(path.join(vault, 'design_tokens.json'), 'utf8'));
  for (const target of targets) {
    const destination = path.join(root, target, 'assets/dytava');
    await mkdir(destination, { recursive: true });
    for (const folder of ['brand/svg', 'icons/svg/color', 'icons/svg/outline', 'formats/svg']) {
      await cp(path.join(vault, folder), path.join(destination, folder), { recursive: true });
    }
    await cp(illustrations, path.join(destination, 'illustrations/svg'), { recursive: true });
    await cp(path.join(vault, 'design_tokens.json'), path.join(destination, 'design_tokens.json'));
  }
  if (targets.includes('web')) {
    await writeFile(path.join(root, 'web/css/brand-tokens.css'),
      '/* Generated from branding/mobile/assets/dytava/design_tokens.json. */\n:root {\n' +
      Object.entries(tokens.palette).map(([name, value]) => `  --brand-${name.replaceAll('_', '-')}: ${value.hex};`).join('\n') + '\n}\n');
    await cp(path.join(vault, 'design_tokens.json'), path.join(root, 'web/assets/design-tokens.json'));
  }
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  await syncBranding();
  console.log('Đã đồng bộ branding SVG cho web và mobile.');
}
