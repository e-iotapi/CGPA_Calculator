import { test } from '@playwright/test';
import { signIn, visitAndCheck } from './helpers.mjs';

// CR of EEE F211 on Goa (PERF_TEST_PLAN.md T6).
test.describe('cr', () => {
  test.beforeEach(async ({ page }) => {
    await signIn(page, 'cr');
  });

  test('their course maintain page loads with no errors', async ({ page }) => {
    await visitAndCheck(page, '/maintain/goa/course/EEE F211');
  });
});
