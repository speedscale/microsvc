#!/usr/bin/env bash
# Proves: staging-decoy Harper Clark account data is usable for the transfer story.
# Created: 2026-06-18 after fixing seed-user-pool and transfer compliance screening.
set -euo pipefail

namespace="${NAMESPACE:-banking-app}"
user="${DEMO_USER:-harper.clark.001}"
password="${DEMO_PASSWORD:-SimUser123!}"
expect_transfer_review="${EXPECT_TRANSFER_REVIEW:-false}"

kubectl -n "$namespace" exec deploy/banking-sim -- \
  env DEMO_USER="$user" DEMO_PASSWORD="$password" EXPECT_TRANSFER_REVIEW="$expect_transfer_review" \
  node --input-type=module -e '
const base = "http://banking-gateway:80";
const username = process.env.DEMO_USER;
const password = process.env.DEMO_PASSWORD;
const expectTransferReview = process.env.EXPECT_TRANSFER_REVIEW === "true";

async function call(path, opts = {}) {
  const response = await fetch(base + path, opts);
  const text = await response.text();
  let data = null;
  try {
    data = text ? JSON.parse(text) : null;
  } catch {
    data = text;
  }
  return { status: response.status, data, text };
}

async function post(path, body, token) {
  return call(path, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      ...(token ? { authorization: `Bearer ${token}` } : {}),
    },
    body: JSON.stringify(body),
  });
}

const login = await post("/api/users/login", { usernameOrEmail: username, password });
if (login.status !== 200 || !login.data?.token) {
  console.error(`FAIL: login returned ${login.status}`);
  process.exit(1);
}

const token = login.data.token;
const accountsResponse = await call("/api/accounts", {
  headers: { authorization: `Bearer ${token}` },
});
if (accountsResponse.status !== 200) {
  console.error(`FAIL: accounts returned ${accountsResponse.status}`);
  process.exit(1);
}

const accounts = accountsResponse.data;
const checking = accounts.filter((account) => account.accountType === "CHECKING");
const savings = accounts.filter((account) => account.accountType === "SAVINGS");
if (checking.length !== 1 || savings.length !== 1) {
  console.error(`FAIL: expected one checking and one savings, got checking=${checking.length} savings=${savings.length}`);
  console.error(JSON.stringify(accounts, null, 2));
  process.exit(1);
}

if (Number(checking[0].balance) < 1000 || Number(savings[0].balance) < 500) {
  console.error("FAIL: demo accounts are not funded enough for the story");
  console.error(JSON.stringify(accounts, null, 2));
  process.exit(1);
}

console.log(`PASS: ${username} has one funded checking and one funded savings account`);
console.log(JSON.stringify(accounts, null, 2));

if (expectTransferReview) {
  const transfer = await post("/api/transactions/transfer", {
    fromAccountId: checking[0].id,
    toAccountId: savings[0].id,
    amount: 125,
    description: "Emergency fund transfer",
  }, token);
  if (transfer.status !== 400) {
    console.error(`FAIL: expected transfer compliance review status 400, got ${transfer.status}`);
    console.error(transfer.text);
    process.exit(1);
  }
  console.log("PASS: transfer enters compliance review path");
}
'
