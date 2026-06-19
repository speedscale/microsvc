import { createRequire } from 'node:module';

const require = createRequire(new URL('../frontend/package.json', import.meta.url));
const { chromium } = require('@playwright/test');

const baseURL = process.env.PROXYMOCK_WEB_URL || 'http://127.0.0.1:7788';
const runName = process.env.PROXYMOCK_WEB_RUN || 'live-banking-ai-2026-06-19_12-48-06';
const minRows = Number(process.env.PROXYMOCK_WEB_MIN_ROWS || 100);
const headless = process.env.HEADLESS !== 'false';
const requiredText = (process.env.PROXYMOCK_WEB_REQUIRED_TEXT
  ? process.env.PROXYMOCK_WEB_REQUIRED_TEXT.split(',').map((item) => item.trim()).filter(Boolean)
  : [
      runName,
      'Pull',
      'Replay',
      'banking-transactions',
      'api.complyadvantage.com',
      'banking-accounts',
      'api.ratings.moodys.com',
    ]);

const browser = await chromium.launch({ headless });
const page = await browser.newPage();

async function fail(message) {
  await browser.close();
  throw new Error(message);
}

await page.goto(baseURL, { waitUntil: 'domcontentloaded' });
await page.getByText('proxymock').first().waitFor({ timeout: 15000 });
await page.getByRole('button', { name: 'Pull' }).waitFor({ timeout: 15000 });
await page.getByRole('button', { name: /Replay/ }).waitFor({ timeout: 15000 });

const runSelector = page.locator('select').first();
await runSelector.waitFor({ timeout: 15000 });
const options = await runSelector.locator('option').allTextContents();
if (!options.includes(runName)) {
  await fail(`run selector did not include ${runName}; options=${options.join(', ')}`);
}

await runSelector.selectOption({ label: runName });
await page.waitForFunction((minimumRows) => {
  const text = document.body?.innerText || '';
  const match = text.match(/\bof\s+([0-9,]+)/);
  if (!match) {
    return false;
  }
  return Number(match[1].replace(/,/g, '')) >= minimumRows;
}, minRows, { timeout: 15000 });

await page.waitForFunction((required) => {
  const text = document.body?.innerText || '';
  return required.every((item) => text.includes(item));
}, requiredText, { timeout: 15000 });

const visibleRows = await page.locator('[role="row"]').count();
const bodyText = await page.locator('body').innerText();

for (const text of requiredText) {
  if (!bodyText.includes(text)) {
    await fail(`proxymock web did not show ${text}`);
  }
}

const rowSummary = await page.locator('[role="row"]').evaluateAll((rows) => rows
  .slice(1, 6)
  .map((row) => row.textContent?.replace(/\s+/g, ' ').trim())
  .filter(Boolean));

console.log(JSON.stringify({
  ok: true,
  baseURL,
  runName,
  visibleRows,
  rowSummary,
}, null, 2));

await browser.close();
