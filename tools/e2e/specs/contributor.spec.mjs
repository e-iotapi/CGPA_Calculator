import { expect, test } from '@playwright/test';
import { goto, signIn } from './helpers.mjs';

// The seeded ELEC contributor. On the web a text field whose semantics are
// regrouped gets a fresh, empty input: the course search on Add links lost
// every letter that brought up matches below it (SearchBox now keeps its own
// semantics container).
test.describe('contributor', () => {
  test.beforeEach(async ({ page }) => {
    await signIn(page, 'contributor');
  });

  test('Add links: the course search keeps letters that bring up matches', async ({ page }) => {
    await goto(page, '/contribute/add');
    await page.getByText('A course', { exact: true }).click();
    const search = page.getByRole('textbox').first();
    await search.click();
    await page.keyboard.type('eee', { delay: 150 });
    await page.waitForTimeout(500);
    await expect(search).toHaveValue('eee');
    await expect(page.getByText(/^EEE F\d{3} · /).first()).toBeVisible();
  });
});
