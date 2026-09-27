// Cold and warm timing budgets under throttling (PERF_TEST_PLAN.md T6).
// window.pointerPerf (P0) isn't built yet, so the read-count assertions are
// skipped until then; the timing budgets run regardless.
import { expect, test } from '@playwright/test';
import { installLocalCanvasKit, signIn } from './helpers.mjs';

const MORE_ROWS = [
  { name: 'Representatives', path: '/representatives' },
  { name: 'Course reviews', path: '/reviews' },
  { name: 'Resources', path: '/resources' },
];

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
  test('home renders cold in under 3s', async ({ page }) => {
    await installLocalCanvasKit(page);
    await throttle(page);
    const start = Date.now();
    await signIn(page, 'student_full');
    expect(Date.now() - start).toBeLessThan(3000);
  });

  for (const row of MORE_ROWS) {
    test(`${row.name}: first open under 1.5s, second under 300ms`, async ({ page }) => {
      await installLocalCanvasKit(page);
      await throttle(page);
      await signIn(page, 'student_full');

      const firstStart = Date.now();
      await page.goto(row.path);
      await page.waitForLoadState('networkidle');
      const firstMs = Date.now() - firstStart;

      await page.goto('/more');
      const secondStart = Date.now();
      await page.goto(row.path);
      await page.waitForLoadState('networkidle');
      const secondMs = Date.now() - secondStart;

      expect(firstMs, `${row.name} first open`).toBeLessThan(1500);
      expect(secondMs, `${row.name} second open`).toBeLessThan(300);

      const reads = await page.evaluate((p) => window.pointerPerf?.reads?.(p) ?? null, row.path);
      test.skip(reads == null, 'window.pointerPerf not built yet (P0)');
      expect(reads, `${row.name} second open should be 0 blocking reads`).toBe(0);
    });
  }
});
