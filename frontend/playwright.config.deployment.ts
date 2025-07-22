import { defineConfig, devices } from '@playwright/test';

/**
 * Configuration for running tests against deployed application
 */
export default defineConfig({
  testDir: './e2e',
  testMatch: /.*\.spec\.ts/,
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: 'html',
  use: {
    baseURL: process.env.DEPLOYMENT_URL || process.env.PLAYWRIGHT_BASE_URL || 'http://143.244.214.142',
    trace: 'on-first-retry',
    actionTimeout: 30000, // Increase timeout for K8s deployment
  },
  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
  ],
  // No webServer - we're testing against deployed app
});