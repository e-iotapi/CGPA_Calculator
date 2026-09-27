// Shared helpers for the T6 specs.
import { readFile } from 'node:fs/promises';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { expect } from '@playwright/test';

const BUILD_WEB = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  '..',
  '..',
  '..',
  'build',
  'web',
);

/// CanvasKit normally loads from Google's CDN; a sandboxed CI runner with no
/// egress to it (or a slow one) would make every spec time out on "Loading"
/// before the app ever renders. Serve it from the build's own bundled copy
/// instead, so the specs need no internet access at all.
export async function installLocalCanvasKit(page) {
  await page.route('https://www.gstatic.com/flutter-canvaskit/**', async (route) => {
    const url = new URL(route.request().url());
    const rest = url.pathname.split('/').filter(Boolean).slice(2).join('/');
    try {
      const body = await readFile(path.join(BUILD_WEB, 'canvaskit', rest));
      const contentType = rest.endsWith('.wasm')
        ? 'application/wasm'
        : 'application/javascript';
      await route.fulfill({ status: 200, contentType, body });
    } catch {
      await route.continue();
    }
  });
}

/// Signs in as [key] from test_env/accounts.json via the ?as= test hook
/// (T1), without waiting for any particular screen — for accounts that
/// land on degree setup rather than Home (student_new, faculty).
export async function signInRaw(page, key) {
  await installLocalCanvasKit(page);
  await page.goto(`/?as=${key}`);
  await page.waitForLoadState('networkidle');
}

/// Signs in as [key] and waits for the home page's bottom nav to render.
export async function signIn(page, key) {
  await signInRaw(page, key);
  await expect(page.getByText('More', { exact: true })).toBeVisible({ timeout: 30_000 });
}

const ERROR_STRINGS = ['That did not work', 'Not allowed', 'No connection'];

/// Fails if any of home_page.dart's problem() strings are visible anywhere
/// on the page.
export async function assertNoErrors(page) {
  const body = await page.locator('body').innerText();
  for (const s of ERROR_STRINGS) {
    expect(body, `found error text "${s}"`).not.toContain(s);
  }
}

export async function goto(page, route) {
  await page.goto(route);
  await page.waitForLoadState('networkidle');
}

/// Visits [route] and checks it rendered something real, with no error text.
export async function visitAndCheck(page, route) {
  await goto(page, route);
  await page.waitForTimeout(500); // Flutter's post-navigate frame settles
  const body = await page.locator('body').innerText();
  expect(body.trim().length, `"${route}" rendered no visible text`).toBeGreaterThan(0);
  await assertNoErrors(page);
}

export function loadExpected(dataset) {
  const file = path.join(
    path.dirname(fileURLToPath(import.meta.url)),
    '..',
    '..',
    'test_env',
    'out',
    `${dataset}.expected.json`,
  );
  return JSON.parse(readFileSync(file, 'utf8'));
}
