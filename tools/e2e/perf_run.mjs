// Repeatable perf script against staging (Tester's 8 steps), Chrome throttled
// like PERF_BASELINE.md (4x CPU, 300 ms, 1.6 Mbps). Prints one table.
//   node perf_run.mjs [runs=5] [role=student_full]
// Raw per-run JSON: tools/perf_out/chrome/ (gitignored).
import { chromium } from '@playwright/test';
import { mkdirSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { settled } from './specs/helpers.mjs';

const BASE = process.env.BASE_URL ?? 'https://pointer-staging.web.app';
const RUNS = Number(process.argv[2] ?? 5);
const ROLE = process.argv[3] ?? 'student_hyd';
const OUT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../perf_out/chrome');
const MISSED = 16.7 * 1.5; // a rAF gap this long means at least one vsync was missed

// Runs in the page before the app: rAF gaps and long tasks for the current step.
const COLLECTOR = () => {
  window.__pf = { frames: [], long: [] };
  window.addEventListener('flutter-first-frame', () => { window.__pfFirstFrame = performance.now(); }, { once: true });
  let last = 0;
  const tick = (t) => { if (last) window.__pf.frames.push(t - last); last = t; requestAnimationFrame(tick); };
  requestAnimationFrame(tick);
  new PerformanceObserver((l) => l.getEntries().forEach((e) => window.__pf.long.push(e.duration)))
    .observe({ type: 'longtask', buffered: true });
};

const btn = (page, name) => page.getByRole('button', { name }).first();
// Park the mouse after each tap: a hover tooltip renames the button (and costs frames).
const tap = async (page, name) => { await btn(page, name).click(); await page.mouse.move(2, 400); await settled(page); };

const STEPS = [
  ['2 scroll home', async (p) => {
    await p.mouse.move(400, 400);
    for (let i = 0; i < 6; i++) { await p.mouse.wheel(0, 600); await p.waitForTimeout(120); }
    for (let i = 0; i < 6; i++) { await p.mouse.wheel(0, -600); await p.waitForTimeout(120); }
  }],
  ['3 tabs', async (p) => { for (const t of ['Expected', 'Compare', 'Actual']) await tap(p, new RegExp(`^${t}$`)); }],
  ['4 semester x3', async (p) => { for (const s of ['2 - 1', '2 - 2', '3 - 1']) await tap(p, new RegExp(`^${s}$`)); }],
  ['5 theme x2', async (p) => {
    for (let i = 0; i < 2; i++) { await tap(p, /^Switch to (dark|light) mode$/); await p.waitForTimeout(800); }
  }],
  ['6 settings', async (p) => { await tap(p, /^Settings$/); await tap(p, /^(Close|Back)$/); }],
  ['7 reviews', async (p) => {
    await tap(p, /^More$/); await tap(p, /^Course reviews/);
    await tap(p, /[A-Z]{2,5} [A-Z]\d{3}/); // first course row
    await p.goBack(); await settled(p); await p.goBack(); await settled(p);
  }],
  ['8 resources', async (p) => {
    await tap(p, /^Resources/);
    const dept = btn(p, /^(?!Back|Close|Search)[A-Z][A-Z0-9]\b/); // first department row, if the campus has any
    if (await dept.isVisible()) { await dept.click(); await p.mouse.move(2, 400); await settled(p); }
  }],
];

const bucket = (u) =>
  /main\.dart\.(js|mjs|wasm)/.test(u) ? 'main.dart' :
  /\.wasm(\?|$)/.test(u) ? 'engine wasm' :
  /canvaskit|skwasm/.test(u) ? 'engine js' :
  /\.(ttf|otf|woff2?)(\?|$)|fonts\.g/.test(u) ? 'fonts' :
  /firestore\.googleapis/.test(u) ? 'firestore' :
  /catalog/i.test(u) ? 'catalogue' : 'other';
const pct = (xs, q) => { if (!xs.length) return 0; const s = [...xs].sort((a, b) => a - b); return s[Math.min(s.length - 1, Math.floor(q * s.length))]; };
const r1 = (x) => Math.round(x * 10) / 10;

async function sample(page, fn) {
  await page.evaluate(() => { if (window.__pf) { window.__pf.frames = []; window.__pf.long = []; } });
  const t0 = Date.now();
  let error;
  try { await fn(page); } catch (e) {
    const lines = e.message.split('\n');
    error = [lines[0], ...lines.filter((l) => /waiting for|intercepts|not visible|not stable/.test(l)).slice(-2)].join(' | ');
    await page.screenshot({ path: path.join(OUT, `fail-${Date.now()}.png`) }).catch(() => {});
  }
  const ms = Date.now() - t0;
  await page.waitForTimeout(300);
  const { frames, long, heap } = await page.evaluate(() => ({ ...window.__pf, heap: performance.memory?.usedJSHeapSize ?? 0 }));
  return { ms, frames, long, heapMB: r1(heap / 1e6), error };
}

async function run(browser, i) {
  const ctx = await browser.newContext({ viewport: { width: 390, height: 844 } });
  const page = await ctx.newPage();
  await page.addInitScript(COLLECTOR);
  const cdp = await ctx.newCDPSession(page);
  await cdp.send('Network.enable');
  await cdp.send('Network.clearBrowserCache');
  await cdp.send('Emulation.setCPUThrottlingRate', { rate: 4 });
  await cdp.send('Network.emulateNetworkConditions', { offline: false, latency: 300, downloadThroughput: 1.6e6 / 8, uploadThroughput: 750e3 / 8 });
  // Bytes on the wire per request (CDP sees cross-origin sizes that Resource Timing hides).
  const urls = new Map(), kb = {};
  cdp.on('Network.responseReceived', (e) => urls.set(e.requestId, e.response.url));
  cdp.on('Network.loadingFinished', (e) => {
    const k = bucket(urls.get(e.requestId) ?? '');
    kb[k] = (kb[k] ?? 0) + e.encodedDataLength / 1024;
  });

  let tti = null;
  const cold = await sample(page, async (p) => {
    await p.goto(`${BASE}/?as=${ROLE}`);
    await btn(p, /^More$/).waitFor({ timeout: 60_000 });
    tti = await p.evaluate(() => performance.now());
  });
  cold.load = await page.evaluate(() => ({
    fcp: performance.getEntriesByName('first-contentful-paint')[0]?.startTime ?? null,
    firstFrame: window.__pfFirstFrame ?? null,
  }));
  cold.load.tti = tti;
  cold.load.kb = Object.fromEntries(Object.entries(kb).map(([k, v]) => [k, Math.round(v)]));
  const steps = { '1 cold load': cold };
  if (!cold.error) for (const [name, fn] of STEPS) steps[name] = await sample(page, fn);
  await ctx.close();
  writeFileSync(path.join(OUT, `run-${Date.now()}-${i}.json`), JSON.stringify(steps));
  return steps;
}

mkdirSync(OUT, { recursive: true });
const browser = await chromium.launch({ channel: 'chrome' });
const runs = [];
for (let i = 1; i <= RUNS; i++) { runs.push(await run(browser, i)); process.stdout.write(`run ${i}/${RUNS} done\n`); }
await browser.close();

console.log(`\n${RUNS} runs, ${ROLE}, ${BASE}\nstep\twall med/p90 ms\tframe med/p90/worst ms\t%missed\tlong>50ms/run\theap MB\terrors`);
for (const name of ['1 cold load', ...STEPS.map((s) => s[0])]) {
  const rs = runs.map((r) => r[name]).filter(Boolean);
  const frames = rs.flatMap((r) => r.frames);
  const errs = rs.filter((r) => r.error);
  console.log([name,
    `${pct(rs.map((r) => r.ms), 0.5)}/${pct(rs.map((r) => r.ms), 0.9)}`,
    `${r1(pct(frames, 0.5))}/${r1(pct(frames, 0.9))}/${r1(Math.max(0, ...frames))}`,
    frames.length ? `${r1((100 * frames.filter((f) => f > MISSED).length) / frames.length)}%` : '-',
    r1(rs.reduce((a, r) => a + r.long.filter((d) => d > 50).length, 0) / (rs.length || 1)),
    pct(rs.map((r) => r.heapMB), 0.5),
    errs.length ? `${errs.length}x ${errs[0].error.slice(0, 240)}` : '',
  ].join('\t'));
}
const c = runs.map((r) => r['1 cold load'].load).filter(Boolean);
const med = (f) => Math.round(pct(c.map(f).filter((x) => x != null), 0.5));
console.log(`cold (med ms from navigation): splash FCP ${med((x) => x.fcp)}, first Flutter frame ${med((x) => x.firstFrame)}, first interaction ${med((x) => x.tti)}`);
const keys = [...new Set(c.flatMap((x) => Object.keys(x.kb)))].sort();
console.log(`cold KB (med): ${keys.map((k) => `${k} ${med((x) => x.kb[k] ?? 0)}`).join(', ')}, total ${med((x) => Object.values(x.kb).reduce((a, b) => a + b, 0))}`);
