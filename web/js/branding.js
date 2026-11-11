import { escapeHtml as e } from './api.js';

// All paths point to vectors synced from the approved branding vault.
export function brandIcon(name, size = 22) {
  return `<img class="brand-icon" src="assets/dytava/icons/svg/color/${e(name)}.svg" width="${size}" height="${size}" alt="" aria-hidden="true">`;
}
export function illustration(name, size = 160) {
  return `<img class="state-illustration" src="assets/dytava/illustrations/svg/square/${e(name)}.svg" width="${size}" height="${size}" alt="" aria-hidden="true" loading="lazy">`;
}
export function emptyState(name, text) {
  return `<div class="empty-state">${illustration(name)}<p>${e(text)}</p></div>`;
}
