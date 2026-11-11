import { syncBranding } from './sync-branding.js';
import { build } from 'esbuild';
import { cp, mkdir, rm } from 'node:fs/promises';

await syncBranding(['web']);

await rm('dist', { recursive: true, force: true });
await mkdir('dist', { recursive: true });
for (const file of ['index.html', 'privacy.html', 'help.html', 'css', 'assets', '_headers', '_redirects']) await cp(`web/${file}`, `dist/${file}`, { recursive: true });
await build({ entryPoints: ['web/js/app.js', 'web/js/compare-worker.js'], outdir: 'dist/js', bundle: true, minify: true, splitting: true, format: 'esm', target: ['es2022'], chunkNames: 'chunks/[name]-[hash]' });
console.log('Frontend đã build vào dist/.');
