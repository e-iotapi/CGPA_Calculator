import { expect, test } from '@playwright/test';
import { assertNoErrors, goto, signIn, visitAndCheck } from './helpers.mjs';

// --A3 (EEE), batch 24, 3rd year, currently in 3-1: EEE F311 and EEE F313
// (PERF_TEST_PLAN.md T6). Seed data: student_full already has an open
// volunteer offer and a review on EEE F311, and nothing yet on EEE F313.
test.describe('student_full', () => {
  test.beforeEach(async ({ page }) => {
    await signIn(page, 'student_full');
  });

  test('home shows no errors', async ({ page }) => {
    await assertNoErrors(page);
    // profile1n/profile2n default to Actual/Expected (script.dart).
    await expect(page.getByText('Actual', { exact: true })).toBeVisible();
  });

  const pages = [
    '/stats',
    '/calendar',
    '/more',
    '/representatives',
    '/reviews',
    '/resources',
    '/settings',
  ];
  for (const route of pages) {
    test(`${route} shows seeded data with no errors`, async ({ page }) => {
      await visitAndCheck(page, route);
    });
  }

  test('a current course opens Marks', async ({ page }) => {
    await visitAndCheck(page, '/course/EEE F311');
  });

  test('a course review page opens, and shows the student\'s own review as editable', async ({ page }) => {
    await visitAndCheck(page, '/reviews/EEE F311');
    await expect(page.getByText('Edit your review', { exact: true })).toBeVisible({
      timeout: 10_000,
    });
  });

  test('the other current course offers a fresh review', async ({ page }) => {
    await visitAndCheck(page, '/reviews/EEE F313');
    await expect(page.getByText('Review EEE F313', { exact: false })).toBeVisible({
      timeout: 10_000,
    });
  });

  test('withdraw, then volunteer again, on EEE F313 (no CR, no prior offer)', async ({ page }) => {
    await goto(page, '/representatives');
    const volunteer = page.getByRole('button', { name: 'Volunteer', exact: true });
    await expect(volunteer.first()).toBeVisible({ timeout: 10_000 });
    await volunteer.first().click();
    await expect(page.getByRole('button', { name: 'Withdraw', exact: true }).first()).toBeVisible();
    await page.getByRole('button', { name: 'Withdraw', exact: true }).first().click();
    await assertNoErrors(page);
  });
});
