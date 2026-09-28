import { test } from '@playwright/test';
import { signIn, visitAndCheck } from './helpers.mjs';

// --A7, batch 24, Hyderabad campus (PERF_TEST_PLAN.md T6): the campus
// sandbox — reviews and representatives are scoped to their own campus, so
// these pages must still load cleanly even though the seeded review/rep
// data lives on Goa. A deeper "never sees Goa data" check needs a running
// UI to compare against and isn't asserted here.
test.describe('student_hyd', () => {
  test.beforeEach(async ({ page }) => {
    await signIn(page, 'student_hyd');
  });

  for (const route of ['/stats', '/representatives', '/reviews', '/resources', '/more']) {
    test(`${route} loads with no errors`, async ({ page }) => {
      await visitAndCheck(page, route);
    });
  }
});
