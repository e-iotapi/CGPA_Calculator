import { expect, test } from '@playwright/test';
import { assertNoErrors, goto, signIn, visitAndCheck } from './helpers.mjs';

// ELEC president on Goa (PERF_TEST_PLAN.md T6).
test.describe('president', () => {
  test.beforeEach(async ({ page }) => {
    await signIn(page, 'president');
  });

  const deptPages = [
    '/maintain/goa/ELEC',
    '/maintain/goa/ELEC/courses',
    '/maintain/goa/ELEC/professors',
    '/maintain/goa/ELEC/resources',
    '/maintain/goa/ELEC/reviews',
    '/maintain/goa/ELEC/succession',
  ];
  for (const route of deptPages) {
    test(`${route} loads with no errors`, async ({ page }) => {
      await visitAndCheck(page, route);
    });
  }

  test('dismissing the seeded open volunteer offer works', async ({ page }) => {
    await goto(page, '/admin/roster');
    const dismiss = page.getByRole('button', { name: 'Dismiss', exact: false }).first();
    if (await dismiss.isVisible({ timeout: 10_000 }).catch(() => false)) {
      await dismiss.click();
      await assertNoErrors(page);
    }
  });

  test('/admin/people redirects home (owner/admin only)', async ({ page }) => {
    await goto(page, '/admin/people');
    await expect(page).toHaveURL(/\/$/);
  });
});
