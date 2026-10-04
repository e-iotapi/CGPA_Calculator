import { test } from '@playwright/test';
import { assertNoErrors, signInRaw } from './helpers.mjs';

// A faculty BITS address: not a student address (isStudentAddress is false
// for it), so the app must not crash, even though volunteering and the
// student-shaped setup flow don't apply to it (PERF_TEST_PLAN.md T6).
test('faculty can sign in without errors', async ({ page }) => {
  await signInRaw(page, 'faculty');
  await page.waitForTimeout(3000);
  await assertNoErrors(page);
});
