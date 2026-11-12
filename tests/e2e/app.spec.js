import { test, expect } from '@playwright/test';
import ExcelJS from 'exceljs';
import { mkdir } from 'node:fs/promises';

const errors = [];
test.beforeEach(async ({ page }) => {
  errors.length = 0; page.on('pageerror', error => errors.push(error.message));
  page.on('console', msg => { if (msg.type() === 'error' && !msg.text().includes('401') && !msg.text().includes('403')) errors.push(msg.text()); });
  await page.goto('/'); await expect(page.locator('#btn-run-compare')).toBeEnabled();
});
test.afterEach(() => expect(errors).toEqual([]));
async function loginAdmin(page) {
  await page.locator('#btn-account').click();
  await page.locator('#auth-email').fill('admin@e2e.example'); await page.locator('#auth-password').fill('e2e-test-password-only');
  await page.locator('#auth-submit').click(); await expect(page.locator('#btn-account')).toHaveText('E2E Admin');
  await page.goto('/#/admin/overview'); await expect(page.locator('#tab-panel-overview h2')).toHaveText('Trung tâm quản trị');
}

test('guest comparison uses a worker; admin routes require login; no automatic history transmission', async ({ page }) => {
  const writes = []; page.on('request', req => { if (req.url().includes('/api/comparisons') && req.method() === 'POST') writes.push(req); });
  await expect(page.locator('#table-container-a tbody tr')).not.toHaveCount(0);
  await page.locator('[data-filter="UNRESOLVED"]').click();
  const rows = await page.locator('#table-container-a tbody tr').count(); expect(rows).toBeGreaterThan(0);
  await page.locator('[data-filter="ALL"]').first().click();
  await page.locator('#table-container-a td.cell-equiv').first().click(); await expect(page.locator('#cell-inspector-modal')).toHaveClass(/open/); await page.keyboard.press('Escape');
  await page.goto('/#/admin/overview'); await expect(page.locator('#view-access')).toBeVisible();
  expect(writes).toHaveLength(0);
});

test('register, save metadata only, reload, view and delete private history', async ({ page }) => {
  await page.locator('#btn-account').click(); await page.locator('#auth-mode-toggle').click();
  await page.locator('#auth-name').fill('Browser User'); await page.locator('#auth-email').fill(`browser-${Date.now()}@example.com`); await page.locator('#auth-password').fill('browser-test-password');
  await page.locator('#auth-submit').click(); await expect(page.locator('#btn-account')).toHaveText('Browser User');
  const saved = page.waitForRequest(req => req.url().endsWith('/api/comparisons') && req.method() === 'POST');
  await page.locator('#btn-save-session').click(); const payload = (await saved).postDataJSON();
  expect(payload).not.toHaveProperty('fileA'); expect(payload).not.toHaveProperty('name'); expect(JSON.stringify(payload)).not.toContain('Nguyễn');
  await expect(page.locator('#btn-save-session')).toHaveText('✓ Đã lưu thống kê');
  await page.reload(); await expect(page.locator('#btn-account')).toHaveText('Browser User');
  await page.goto('/#/history'); await expect(page.locator('#history-content tbody tr')).toHaveCount(1);
  await page.locator('[data-delete]').click(); await expect(page.locator('#history-content')).toContainText('Chưa lưu phiên nào');
  await page.locator('#btn-logout').click(); await expect(page.locator('#btn-account')).toHaveText('Đăng nhập');
});

test('CSV and JSON import render untrusted content as text, export files safely', async ({ page }) => {
  const content = 'ID,Value\n001,"<img src=x onerror=alert(1)>"\n002,"line one\nline two"';
  await page.locator('#file-input-a').setInputFiles({ name: 'private.csv', mimeType: 'text/csv', buffer: Buffer.from(content) });
  await expect(page.locator('#file-badge-a')).toContainText('private.csv');
  await page.locator('#file-input-b').setInputFiles({ name: 'private.json', mimeType: 'application/json', buffer: Buffer.from(JSON.stringify([{ ID: '001', Value: '=1+1' }, { ID: '002', Value: 'other' }])) });
  await expect(page.locator('#file-badge-b')).toContainText('private.json'); await expect(page.locator('#btn-run-compare')).toBeEnabled();
  await expect(page.locator('#table-container-a')).toContainText('<img src=x onerror=alert(1)>'); expect(await page.locator('#table-container-a img').count()).toBe(0);
  const exported = page.waitForEvent('download'); await page.locator('#btn-export-csv').click(); expect((await exported).suggestedFilename()).toMatch(/differences.*csv/);
});

test('browser parses XLSX and switches visible sheets', async ({ page }) => {
  const workbook = new ExcelJS.Workbook(); workbook.addWorksheet('Primary').addRows([['ID', 'Value'], ['001', 'first']]); workbook.addWorksheet('Second').addRows([['ID', 'Value'], ['002', 'second']]);
  await page.locator('#file-input-a').setInputFiles({ name: 'multiple.xlsx', mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', buffer: Buffer.from(await workbook.xlsx.writeBuffer()) });
  await expect(page.locator('#sheet-a')).toBeVisible(); await expect(page.locator('#table-container-a')).toContainText('first');
  await page.locator('#sheet-a').selectOption('Second'); await expect(page.locator('#table-container-a')).toContainText('second'); await expect(page.locator('#label-table-a')).toHaveText('Second');
});

test('admin publishes and edits a real release; public download reflects persisted data', async ({ page }) => {
  await loginAdmin(page); await page.locator('[data-tab="releases"]').click(); await page.locator('#btn-open-add-release').click();
  await page.locator('#rel-product').fill('Browser Release'); await page.locator('#rel-version').fill('1.0.0'); await page.locator('#rel-size').fill('2 MB'); await page.locator('#rel-downloadUrl').fill('https://example.com/browser.apk'); await page.locator('#rel-sha256').fill('a'.repeat(64)); await page.locator('#rel-changelog').fill('<img src=x onerror=alert(1)>');
  await page.locator('#form-add-release [type=submit]').click(); await expect(page.locator('#tbody-releases')).toContainText('Browser Release');
  await page.locator('[data-edit-release]').first().click(); await page.locator('#rel-version').fill('1.0.1'); await page.locator('#form-add-release [type=submit]').click(); await expect(page.locator('#tbody-releases')).toContainText('1.0.1');
  await page.reload(); await expect(page.locator('#tbody-releases')).toContainText('1.0.1');
  await page.goto('/#downloads'); await expect(page.locator('#public-releases')).toContainText('<img src=x onerror=alert(1)>'); expect(await page.locator('#public-releases img').count()).toBe(0); await expect(page.locator('#public-releases a')).toHaveAttribute('href', 'https://example.com/browser.apk');
});

test('admin creates policy, applies it to comparison, runs golden fixtures and reviews audit', async ({ page }) => {
  await loginAdmin(page); await page.locator('[data-tab="policies"]').click(); await page.locator('#new-policy').click();
  await page.locator('[name=policyId]').fill('browser-policy-v1'); await page.locator('[name=policyName]').fill('Browser policy'); await page.locator('[name=tolerance_abs]').fill('2'); await page.locator('#form-policy [type=submit]').click(); await expect(page.locator('#policies-list')).toContainText('Browser policy');
  await page.goto('/#/'); await page.locator('#opt-policy').selectOption('browser-policy-v1'); await expect(page.locator('#opt-tolerance')).toHaveValue('2'); await expect(page.locator('#btn-run-compare')).toBeEnabled();
  await page.goto('/#/admin/acceptance'); await page.locator('#btn-run-acceptance-tests').click(); await expect(page.locator('#acceptance-progress')).toContainText('10/10 đạt (100%)');
  await page.goto('/#/admin/audit'); await expect(page.locator('#admin-audit-content')).toContainText('policy.created');
});

test('admin feature toggle persists and disables the actual client control', async ({ page }) => {
  await loginAdmin(page); await page.locator('[data-tab="flags"]').click();
  const flag = page.locator('[data-flag="FLAG_REPORT_EXPORT"]'); await flag.uncheck(); await expect(flag).toBeEnabled();
  await page.goto('/#/'); await expect(page.locator('#btn-export-csv')).toBeDisabled();
  await page.reload(); await expect(page.locator('#btn-export-json')).toBeDisabled();
  await page.goto('/#/admin/flags'); await page.locator('[data-flag="FLAG_REPORT_EXPORT"]').check(); await expect(page.locator('[data-flag="FLAG_REPORT_EXPORT"]')).toBeEnabled();
  await page.goto('/#/'); await expect(page.locator('#btn-export-csv')).toBeEnabled();
});

test('desktop and mobile layout remain usable', async ({ page }) => {
  await mkdir('test-results/screenshots', { recursive: true });
  await page.setViewportSize({ width: 1440, height: 1000 }); await page.screenshot({ path: 'test-results/screenshots/desktop.png', fullPage: true });
  await page.setViewportSize({ width: 390, height: 844 });
  await expect(page.locator('#btn-account')).toBeVisible(); await expect(page.locator('#btn-run-compare')).toBeVisible();
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 1)).toBe(true);
  await page.screenshot({ path: 'test-results/screenshots/mobile.png', fullPage: true });
});

test('approved branding assets load in light/dark themes and narrow layouts', async ({ page }) => {
  const assets = await page.locator('img[src*="assets/dytava/"]').evaluateAll(images => [...new Set(images.map(image => image.getAttribute('src')))]);
  for (const asset of assets) {
    const response = await page.request.get(`/${asset}`);
    expect(response.ok(), asset).toBe(true);
    expect(response.headers()['content-type'], asset).toContain('image/svg+xml');
  }
  await expect(page.locator('.hero-illustration')).toBeVisible();
  await expect(page.locator('#btn-run-compare img')).toHaveAttribute('src', /\/compare\.svg$/);
  await expect(page.locator('#btn-export-json')).toHaveCSS('background-color', 'rgb(139, 92, 246)');
  for (const width of [320, 390, 768, 1440]) {
    await page.setViewportSize({ width, height: 900 });
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 1), `viewport ${width}`).toBe(true);
  }
  await page.locator('#btn-theme-toggle').click();
  await expect(page.locator('.brand-logo-dark')).toBeVisible();
  await expect(page.locator('.brand-logo-light')).toBeHidden();
  await expect(page.locator('#btn-theme-toggle')).toHaveAttribute('aria-pressed', 'true');
  await page.reload();
  await expect(page.locator('.brand-logo-dark')).toBeVisible();
  await page.goto('/#/history');
  await expect(page.locator('#history-content img')).toHaveAttribute('src', /\/empty-history\.svg$/);
  await page.goto('/#/admin/overview');
  await expect(page.locator('#view-access img')).toHaveAttribute('src', /\/status-no-permission\.svg$/);
});

test('Dytava report preview stays local, renders branding and discloses legacy metadata', async ({ page }) => {
  const writes = [];
  page.on('request', req => { if (req.method() === 'POST') writes.push(req.url()); });
  const opened = page.waitForEvent('popup');
  await page.locator('#btn-export-pdf').click();
  const preview = await opened;
  await expect(preview.locator('#report-print')).toBeEnabled();
  await expect(preview.locator('.report-cover h1')).toContainText('đối chiếu dữ liệu');
  await expect(preview.locator('.cover-seal')).toHaveText('Metadata chưa đầy đủ');
  await expect(preview.locator('[data-section]')).toHaveCount(8);
  expect(await preview.locator('img').evaluateAll(images => images.every(img => img.complete && img.naturalWidth > 0))).toBe(true);
  expect(await preview.locator('script:not([src])').count()).toBe(0);
  await preview.setViewportSize({ width: 390, height: 844 });
  expect(await preview.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 1)).toBe(true);
  expect(writes).toHaveLength(0);
  await preview.close();
});
