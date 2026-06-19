import { createRequire } from 'node:module';

const require = createRequire(new URL('../frontend/package.json', import.meta.url));
const { chromium } = require('@playwright/test');

const baseURL = process.env.BASE_URL || 'http://127.0.0.1:3000';
const headless = process.env.HEADLESS !== 'false';
const maxAttempts = Number(process.env.BROWSER_CHECK_ATTEMPTS || 20);
const retryDelayMs = Number(process.env.BROWSER_CHECK_RETRY_DELAY_MS || 1000);
const errors = [];

const browser = await chromium.launch({ headless });
const page = await browser.newPage();

page.on('console', (msg) => {
  if (msg.type() === 'error') errors.push(msg.text());
});
page.on('pageerror', (error) => {
  errors.push(error.stack || error.message);
});

async function fail(message) {
  await browser.close();
  throw new Error(message);
}

async function waitForFormValue(value) {
  await page.waitForFunction((expected) => {
    return Array.from(document.querySelectorAll('input, textarea'))
      .some((element) => element.value === expected);
  }, value, { timeout: 15000 });
}

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

async function gotoWithRetry(url) {
  let lastError = null;

  for (let attempt = 1; attempt <= maxAttempts; attempt += 1) {
    try {
      return await page.goto(url, { waitUntil: 'domcontentloaded' });
    } catch (error) {
      lastError = error;
      if (attempt === maxAttempts) {
        throw error;
      }
      await sleep(retryDelayMs);
    }
  }

  throw lastError || new Error(`failed to load ${url}`);
}

await gotoWithRetry(baseURL);
await page.getByText('Harper Clark').waitFor({ timeout: 15000 });
await page.getByText('harper.clark.001').waitFor({ timeout: 15000 });

await gotoWithRetry(`${baseURL}/login`);
await page.getByPlaceholder('Enter your username or email').waitFor({ timeout: 15000 });

const username = await page.getByPlaceholder('Enter your username or email').inputValue();
const password = await page.getByPlaceholder('Enter your password').inputValue();
if (username !== 'harper.clark.001') await fail(`login username was ${username}`);
if (password !== 'SimUser123!') await fail('login password was not prefilled');

await page.getByRole('button', { name: 'Sign in' }).click();
await page.waitForURL('**/dashboard', { timeout: 15000 });
await page.getByText('Checking and savings accounts are ready.').waitFor({ timeout: 15000 });

await page.getByRole('button', { name: 'Start Transfer Review' }).click();
await page.waitForLoadState('domcontentloaded');
await page.waitForTimeout(1000);

if ((await page.getByText('Application error: a client-side exception has occurred').count()) > 0) {
  await fail(`transfer page crashed: ${errors.join('\n')}`);
}

await page.getByRole('heading', { name: 'Transfer Money' }).waitFor({ timeout: 15000 });
await waitForFormValue('125.00');
await waitForFormValue('Emergency fund transfer');

console.log(JSON.stringify({
  ok: true,
  baseURL,
  path: new URL(page.url()).pathname + new URL(page.url()).search,
}, null, 2));

await browser.close();
