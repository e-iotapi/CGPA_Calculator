import { existsSync } from 'node:fs';
import { defineConfig, devices } from '@playwright/test';

// Deprecated (cloud container): /opt/pw-browsers was pre-installed there.
// Locally Playwright's own download is used (`npx playwright install chromium`).
const CHROMIUM_PATH = '/opt/pw-browsers/chromium';
const executablePath = existsSync(CHROMIUM_PATH) ? CHROMIUM_PATH : undefined;

export default defineConfig({
  testDir: './specs',
  outputDir: './out/test-results',
  timeout: 30_000,
  fullyParallel: false,
  workers: 1,
  retries: 0,
  reporter: [
    ['list'],
    ['html', { outputFolder: './out/report', open: 'never' }],
  ],
  use: {
    baseURL: 'http://127.0.0.1:5050',
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
    launchOptions: executablePath ? { executablePath } : {},
  },
  projects: [{ name: 'chromium', use: { ...devices['Desktop Chrome'] } }],
  webServer: {
    command: 'node serve.mjs',
    url: 'http://127.0.0.1:5050',
    reuseExistingServer: !process.env.CI,
    timeout: 30_000,
  },
});
