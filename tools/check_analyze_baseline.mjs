#!/usr/bin/env node
// Fails if `flutter analyze`'s output (piped in on stdin) contains an issue
// that isn't in tools/analyze_baseline.txt (PERF_TEST_PLAN.md T7). An issue
// the baseline lists but analyze no longer reports is fine — that's a fix.
// Usage: flutter analyze --no-fatal-infos | node tools/check_analyze_baseline.mjs
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const baselineFile = path.join(root, 'tools', 'analyze_baseline.txt');

const baseline = new Set(
  readFileSync(baselineFile, 'utf8')
    .split('\n')
    .map((l) => l.trim())
    .filter(Boolean),
);

const input = readFileSync(0, 'utf8');
const issueLine = /^\s*(?:info|warning|error)\s+•\s+.+\s+•\s+(\S+)\s+•\s+(\S+)\s*$/;

const newIssues = [];
for (const line of input.split('\n')) {
  const m = line.match(issueLine);
  if (!m) continue;
  const [, location, rule] = m;
  const key = `${rule} ${location}`;
  if (!baseline.has(key)) newIssues.push(line.trim());
}

if (newIssues.length > 0) {
  console.error('New analyzer issues not in tools/analyze_baseline.txt:');
  for (const line of newIssues) console.error('  ' + line);
  process.exit(1);
}
console.log('flutter analyze: no issues beyond the baseline.');
