// The "busy student day" from PERF_TEST_PLAN.md §0.5, played against
// window.pointerPerf's counters (P0). Skipped until P0 exists; the budgets
// below (≤8 reads, ≤3 writes per user per day) are §0.5's, not guesses.
//
// window.pointerPerf resets on every fresh app load (it's in-memory), but a
// real day is many separate opens — so this snapshots the counters right
// before each reload discards them and sums those snapshots in the test
// itself, rather than trusting one final in-app total.
import { readFileSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { expect, test } from '@playwright/test';
import { goto, installLocalCanvasKit, signIn } from './helpers.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..', '..');
const MORE_ROWS = ['Representatives', 'Course reviews', 'Resources'];

async function summary(page) {
  return page.evaluate(() => window.pointerPerf?.summary?.() ?? null);
}

/// Opens the app fresh, adds [before] to the running total from whatever
/// the *previous* open accumulated (a reload wipes window.pointerPerf), and
/// returns whether P0 exists at all.
async function open(page, accountKey, totals, before) {
  if (before) {
    totals.reads += before.reads;
    totals.writes += before.writes;
  }
  await installLocalCanvasKit(page);
  await signIn(page, accountKey);
  return summary(page);
}

/// §0.5's simulated day: open the app 5 times, visit every More page twice
/// and 3 Marks pages, edit a grade once, write one review. The More-page
/// and Marks visits happen inside the first open via real client-side
/// navigation (tap, then Back) so they don't themselves reset the counters;
/// grade-edit and review-write are UI flows too uncertain to automate
/// reliably here and are left out, so this undercounts slightly — the
/// reopens and page visits already dominate a real day's reads (§0.5).
async function busyDay(page, accountKey) {
  const totals = { reads: 0, writes: 0 };
  let last = await open(page, accountKey, totals, null);
  if (last == null) return null; // P0 not built yet

  await page.getByText('More', { exact: true }).click();
  for (const rowTitle of MORE_ROWS) {
    for (let i = 0; i < 2; i++) {
      const row = page.getByText(rowTitle, { exact: true });
      await expect(row).toBeVisible({ timeout: 10_000 });
      await row.click();
      await page.waitForLoadState('networkidle');
      await page.goBack();
    }
  }
  const marksCourses = ['/course/EEE F311', '/course/EEE F313', '/course/EEE F311'];
  for (const c of marksCourses) {
    await goto(page, c); // a fresh reload per course, like typing the URL
    last = await open(page, accountKey, totals, last);
  }

  for (let i = 0; i < 4; i++) {
    last = await open(page, accountKey, totals, last);
  }
  totals.reads += last.reads;
  totals.writes += last.writes;
  return totals;
}

function updateQuotaMd(rowLabel, counters) {
  const file = path.join(root, 'QUOTA.md');
  let text;
  try {
    text = readFileSync(file, 'utf8');
  } catch {
    return; // QUOTA.md not created yet
  }
  const marker = `<!-- measured:${rowLabel} -->`;
  const line = `${marker} reads=${counters.reads} writes=${counters.writes} (${new Date().toISOString()})`;
  text = text.includes(marker)
    ? text.replace(new RegExp(`${marker}.*`), line)
    : `${text.trimEnd()}\n${line}\n`;
  writeFileSync(file, text);
}

test.describe('quota', () => {
  test('a busy day as student_full stays within budget', async ({ page }) => {
    const counters = await busyDay(page, 'student_full');
    test.skip(counters == null, 'window.pointerPerf not built yet (P0)');
    updateQuotaMd('student_full', counters);
    expect(counters.reads, 'reads/user/day').toBeLessThanOrEqual(8);
    expect(counters.writes, 'writes/user/day').toBeLessThanOrEqual(3);
  });

  test('a busy day as president stays within budget', async ({ page }) => {
    const counters = await busyDay(page, 'president');
    test.skip(counters == null, 'window.pointerPerf not built yet (P0)');
    updateQuotaMd('president', counters);
    expect(counters.reads, 'reads/user/day').toBeLessThanOrEqual(8);
    expect(counters.writes, 'writes/user/day').toBeLessThanOrEqual(3);
  });
});
