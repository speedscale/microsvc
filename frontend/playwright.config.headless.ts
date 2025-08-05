import { defineConfig, devices } from '@playwright/test';

/**
 * Minimal Playwright configuration for CI environments
 * - No web server startup (tests must run against external server)
 * - Minimal browser setup
 * - Fast timeouts for CI
 */
export default defineConfig({
  testDir: './e2e',
  testMatch: /simple\.spec\.ts/,
  fullyParallel: false,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 1 : 0,
  workers: 1,
  reporter: [
    ['html'],
    ['json', { outputFile: 'test-results/results.json' }],
    ['junit', { outputFile: 'test-results/results.xml' }]
  ],
  use: {
    baseURL: process.env.BASE_URL || 'http://localhost:3000',
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
    actionTimeout: 5000,
    navigationTimeout: 15000,
  },
  projects: [
    {
      name: 'chromium',
      use: { 
        ...devices['Desktop Chrome'],
        launchOptions: {
          args: ['--disable-gpu', '--no-sandbox', '--disable-dev-shm-usage', '--headless']
        }
      },
    },
  ],
  globalTimeout: 5 * 60 * 1000, // 5 minutes
  expect: {
    timeout: 5000,
  },
});