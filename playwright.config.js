import { defineConfig } from '@playwright/test';
export default defineConfig({
  testDir: './tests/e2e', fullyParallel: false, workers: 1, retries: process.env.CI ? 1 : 0,
  timeout: 30000, expect: { timeout: 10000 },
  use: { baseURL: 'http://127.0.0.1:4317', browserName: 'chromium', screenshot: 'only-on-failure', trace: 'retain-on-failure' },
  webServer: { command: 'npm run build && node scripts/e2e-server.js', url: 'http://127.0.0.1:4317/api/health', reuseExistingServer: false, timeout: 30000 }
});
