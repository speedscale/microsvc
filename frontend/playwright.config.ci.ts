import { defineConfig, devices } from '@playwright/test';

/**
 * Playwright configuration optimized for CI/CD pipelines
 * - Single browser (Chromium only)
 * - Shorter timeouts
 * - Circuit breaker for failures
 * - Simplified test execution
 * - Uses mocked APIs to avoid network dependencies
 */
export default defineConfig({
  testDir: './e2e',
  testMatch: /simple\.spec\.ts/,
  /* Run tests in files in parallel */
  fullyParallel: true,
  /* Fail the build on CI if you accidentally left test.only in the source code. */
  forbidOnly: !!process.env.CI,
  /* Retry on CI only */
  retries: process.env.CI ? 1 : 0,
  /* Single worker for CI to avoid resource conflicts */
  workers: 1,
  /* Reporter to use. See https://playwright.dev/docs/test-reporters */
  reporter: [
    ['html'],
    ['json', { outputFile: 'test-results/results.json' }],
    ['junit', { outputFile: 'test-results/results.xml' }]
  ],
  /* Shared settings for all the projects below. See https://playwright.dev/docs/api/class-testoptions. */
  use: {
    /* Base URL to use in actions like `await page.goto('/')`. */
    baseURL: 'http://localhost:3000',

    /* Collect trace when retrying the failed test. See https://playwright.dev/docs/trace-viewer */
    trace: 'on-first-retry',
    
    /* Take screenshot on failure */
    screenshot: 'only-on-failure',
    
    /* Record video on failure */
    video: 'retain-on-failure',
    
    /* Shorter timeouts for CI */
    actionTimeout: 10000,
    navigationTimeout: 30000,
  },

  /* Configure projects for CI - Chromium only */
  projects: [
    {
      name: 'chromium',
      use: { 
        ...devices['Desktop Chrome'],
        /* Disable GPU for CI */
        launchOptions: {
          args: ['--disable-gpu', '--no-sandbox', '--disable-dev-shm-usage']
        }
      },
    },
  ],

  /* Run your local dev server before starting the tests */
  webServer: {
    command: 'npm run build && npm run start',
    url: 'http://localhost:3000',
    reuseExistingServer: !process.env.CI,
    env: {
      NODE_ENV: 'production',
      PORT: '3000',
    },
    timeout: 30000, // 30 second timeout for server startup
  },
  
  /* Global timeout for the entire test run */
  globalTimeout: 5 * 60 * 1000, // 5 minutes
  
  /* Expect timeout for individual assertions */
  expect: {
    timeout: 5000,
  },
}); 