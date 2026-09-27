import { expect, test } from '@playwright/test';
import { assertNoErrors, signInRaw } from './helpers.mjs';

// first_login: no users/{uid} doc at all, batch 2026 (PERF_TEST_PLAN.md T6).
// Degree setup should appear, not a course list from a doc that shouldn't
// exist yet — the first push then creates users/{uid} for real.
test('a brand-new user sees degree setup, not a crash', async ({ page }) => {
  await signInRaw(page, 'student_new');
  await expect(page.getByText('ONE-TIME SETUP', { exact: true })).toBeVisible({
    timeout: 30_000,
  });
  await assertNoErrors(page);
});
