// Cold and warm timing budgets under throttling (PERF_TEST_PLAN.md T6).
// window.pointerPerf (P0) counts by store-method name (rule 3 keeps P0 out
// of lib/features/**, so there is no per-route counter): the read-count
// check compares window.pointerPerf.summary().reads before and after the
// second visit. "Second open" is real client-side navigation (a tap, then
// Back), not page.goto() — goto() is a fresh browser navigation, which
// would reload the whole app and reset every in-memory counter, defeating
// the point of testing a cache-first *second* open.
import { expect, test } from '@playwright/test';
import { installLocalCanvasKit, signIn, settled } from './helpers.mjs';

const MORE_ROWS = ['Representatives', 'Course reviews', 'Resources'];

async function throttle(page) {
  const client = await page.context().newCDPSession(page);
  await client.send('Network.enable');
  await client.send('Emulation.setCPUThrottlingRate', { rate: 4 });
  // 300 ms latency approximates India to a distant Firestore region.
  await client.send('Network.emulateNetworkConditions', {
    offline: false,
    latency: 300,
    downloadThroughput: 1.6e6 / 8,
    uploadThroughput: 750e3 / 8,
  });
}

test.describe('perf', () => {
  // Several full app loads per test; the budgets are asserted inside.
  test.describe.configure({ timeout: 180_000 });
  test('home renders cold in under 3s', async ({ page }) => {
    await installLocalCanvasKit(page);
    await throttle(page);
    const start = Date.now();
    await signIn(page, 'student_full');
    expect(Date.now() - start).toBeLessThan(3000);
  });

  for (const rowTitle of MORE_ROWS) {
    test(`${rowTitle}: first open under 1.5s, second under 300ms`, async ({ page }) => {
      await installLocalCanvasKit(page);
      await throttle(page);
      await signIn(page, 'student_full');
      await page.getByText('More', { exact: true }).click();
      const row = page.getByRole('button', { name: new RegExp(`^${rowTitle}`) }).first();
      await expect(row).toBeVisible({ timeout: 10_000 });

      const firstStart = Date.now();
      await row.click();
      await settled(page);
      const firstMs = Date.now() - firstStart;

      const before = await page.evaluate(() => window.pointerPerf?.summary?.()?.reads ?? null);
      await page.goBack(); // client-side, back to /more — not a reload
      await expect(row).toBeVisible({ timeout: 10_000 });

      const secondStart = Date.now();
      await row.click();
      await settled(page);
      const secondMs = Date.now() - secondStart;

      expect(firstMs, `${rowTitle} first open`).toBeLessThan(1500);
      expect(secondMs, `${rowTitle} second open`).toBeLessThan(300);

      test.skip(before == null, 'window.pointerPerf not built yet (P0)');
      const after = await page.evaluate(() => window.pointerPerf.summary().reads);
      expect(after - before, `${rowTitle} second open should be 0 blocking reads`).toBe(0);
    });
  }
});
