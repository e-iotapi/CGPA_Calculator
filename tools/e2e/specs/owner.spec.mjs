import { test } from '@playwright/test';
import { signIn, visitAndCheck } from './helpers.mjs';

// Owner: an out-of-BITS address, let in by owners/{email} (PERF_TEST_PLAN.md
// T6). Everything admin can reach, plus owner-only pages.
test.describe('owner', () => {
  test.beforeEach(async ({ page }) => {
    await signIn(page, 'owner');
  });

  const pages = [
    '/admin',
    '/admin/people',
    '/admin/grant',
    '/admin/owners',
    '/admin/terms',
    '/admin/contact',
    '/admin/audit',
    '/admin/roster',
    '/admin/professors/merge',
    '/admin/open-as',
    '/admin/publish',
  ];
  for (const route of pages) {
    test(`${route} loads with no errors`, async ({ page }) => {
      await visitAndCheck(page, route);
    });
  }
});
