import { test } from '@playwright/test';
import { signIn, visitAndCheck } from './helpers.mjs';

// B3A7 (Economics/CS dual), batch 22, in Practice School-II at 5-1, with the
// second PS II scheduled at 5-2 (PERF_TEST_PLAN.md T6, D3's target shape).
test.describe('student_dual', () => {
  test.beforeEach(async ({ page }) => {
    await signIn(page, 'student_dual');
  });

  for (const route of ['/stats', '/resources', '/calendar', '/more', '/settings']) {
    test(`${route} shows both programmes with no errors`, async ({ page }) => {
      await visitAndCheck(page, route);
    });
  }

  test('the ongoing Practice School-II opens Marks', async ({ page }) => {
    // Both PS II rows share the code BITS F412; the route matches by code,
    // so this opens whichever row allCourses().where(id) finds first (D3).
    await visitAndCheck(page, '/course/BITS F412');
  });
});
