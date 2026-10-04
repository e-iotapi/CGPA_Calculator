#!/usr/bin/env node
// Generates lib/core/env/test_accounts.g.dart from test_env/accounts.json
// (PERF_TEST_PLAN.md T3). Run: node tools/test_env/gen_accounts.mjs
import { readFileSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');

export function generate(config) {
  const entries = config.accounts
    .map((a) => `  '${a.key}': '${a.email}',`)
    .join('\n');
  return `// GENERATED FILE - do not edit by hand.
// Regenerate with: node tools/test_env/gen_accounts.mjs
// Source: test_env/accounts.json (PERF_TEST_PLAN.md T3).
library;

const testAccounts = <String, String>{
${entries}
};

const testAccountPassword = '${config.password}';
`;
}

function main() {
  const configPath = path.join(root, 'test_env', 'accounts.json');
  const config = JSON.parse(readFileSync(configPath, 'utf8'));
  const outPath = path.join(root, 'lib', 'core', 'env', 'test_accounts.g.dart');
  writeFileSync(outPath, generate(config));
  console.log(`Wrote ${path.relative(root, outPath)}`);
}

if (import.meta.url === `file://${process.argv[1]}`) {
  main();
}
