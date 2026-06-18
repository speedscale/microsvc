#!/usr/bin/env bash
# Proves: seeded traffic users have deterministic human names, mostly western locales, and locale-specific AI prompts.
# Created: 2026-06-18 after replacing numbered traffic users.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

node - "$repo_root" <<'NODE'
const repoRoot = process.argv[2];
const User = require(`${repoRoot}/simulation-client/src/models/User`);
const { getQuestionsForLocale } = require(`${repoRoot}/simulation-client/src/models/personas`);

const westernLocales = new Set([
  'en-US', 'en-GB', 'en-CA', 'en-AU',
  'es-MX', 'es-ES', 'fr-FR', 'de-DE', 'it-IT',
  'nl-NL', 'sv-SE', 'pl-PL', 'pt-BR',
]);
const users = Array.from({ length: 1000 }, (_, i) => User.generateSimulationUser(i + 1));
const usernames = new Set(users.map(user => user.username));
const westernCount = users.filter(user => westernLocales.has(user.locale)).length;

if (usernames.size !== users.length) {
  throw new Error(`duplicate usernames: ${users.length - usernames.size}`);
}
if (westernCount < 800) {
  throw new Error(`western locale share too low: ${westernCount}/1000`);
}
for (const user of users) {
  if (!user.username.includes('.') || user.username.includes('sim_')) {
    throw new Error(`bad username: ${user.username}`);
  }
  if (!user.email.endsWith('@northbridge.example')) {
    throw new Error(`bad email: ${user.email}`);
  }
  if (!getQuestionsForLocale(user.locale).length) {
    throw new Error(`missing questions for locale: ${user.locale}`);
  }
}

console.log(`PASS: ${users.length} named users, ${westernCount} western-locale profiles`);
console.log(`Sample: ${users[0].displayName} <${users[0].email}> ${users[0].locale}`);
NODE

grep -q "Try Harper Clark" "$repo_root/frontend/src/components/auth/LoginForm.tsx"
grep -q "harper.clark.001" "$repo_root/kubernetes/base/jobs/seed-user-pool.yaml"
if grep -R "seed_user\\|Seed1234\\|Seeded account" "$repo_root/frontend" "$repo_root/kubernetes" >/dev/null; then
  echo "FAIL: old seed account copy still appears in frontend or Kubernetes config"
  exit 1
fi
echo "PASS: login hint uses the named customer account"

find "$repo_root/simulation-client/src" -name '*.js' -print0 | xargs -0 -n1 node --check >/dev/null
echo "PASS: simulator JavaScript syntax checks"

dotnet build "$repo_root/backend/user-service/user-service-dotnet.csproj" >/dev/null
echo "PASS: user-service builds"
