import { expect, test } from '@playwright/test';
import { assertNoErrors, goto, signInRaw } from './helpers.mjs';

// A dept president grant that expired 5 days ago: treated as a plain
// student, with no maintain access (PERF_TEST_PLAN.md T6). No dataset is
// seeded for this account, so it also takes the fresh-setup path.
test('an expired president has no maintain access', async ({ page }) => {
  await signInRaw(page, 'president_expired');
  await goto(page, '/maintain/goa/CS');
  await expect(page).toHaveURL(/\/$/);
  await assertNoErrors(page);
});
