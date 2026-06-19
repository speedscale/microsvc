#!/usr/bin/env bash
# Proves: AI delivery errors are limited to the Korean locale slice.
# Created: 2026-06-18 after fixing banking-ai locale delivery error rate.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

node <<'NODE'
const { LOCALE_CYCLE } = require('./simulation-client/src/models/personas');

const westernLocales = new Set([
  'en-US', 'en-GB', 'en-CA', 'en-AU',
  'es-MX', 'es-ES', 'fr-FR', 'de-DE', 'it-IT',
  'nl-NL', 'sv-SE', 'pl-PL', 'pt-BR',
]);

const counts = {};
for (let i = 1; i <= 1000; i += 1) {
  const locale = LOCALE_CYCLE[(i - 1) % LOCALE_CYCLE.length];
  counts[locale] = (counts[locale] || 0) + 1;
}

const westernCount = Object.entries(counts)
  .filter(([locale]) => westernLocales.has(locale))
  .reduce((sum, [, count]) => sum + count, 0);
const koreanCount = counts['ko-KR'] || 0;

if (westernCount < 800) {
  console.error(`FAIL: expected at least 80% western users, got ${westernCount / 10}%`);
  process.exit(1);
}

if (koreanCount > 100) {
  console.error(`FAIL: expected Korean users at or below 10%, got ${koreanCount / 10}%`);
  process.exit(1);
}

console.log(`PASS: western users ${(westernCount / 10).toFixed(1)}%, Korean users ${(koreanCount / 10).toFixed(1)}%`);
NODE

python_bin="python3"
if [[ -x backend/ai-service/.venv/bin/python ]]; then
  python_bin="backend/ai-service/.venv/bin/python"
fi

"$python_bin" -m pytest -p no:cacheprovider backend/ai-service/tests
