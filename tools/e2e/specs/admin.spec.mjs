import { test } from '@playwright/test';
import { signIn, visitAndCheck } from './helpers.mjs';

// Full admin, all campuses (PERF_TEST_PLAN.md T6).
test.describe('admin', () => {
  test.beforeEach(async ({ page }) => {
    await signIn(page, 'admin');
  });

  const pages = [
    '/admin',
    '/admin/people',
    '/admin/grant',
    '/admin/terms',
    '/admin/contact',
    '/admin/audit',
    '/admin/roster',
    '/admin/professors/merge',
  ];
  for (const route of pages) {
    test(`${route} loads with no errors`, async ({ page }) => {
      await visitAndCheck(page, route);
    });
  }
});
