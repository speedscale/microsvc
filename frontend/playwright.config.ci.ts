import { defineConfig } from '@playwright/test';
import headless from './playwright.config.headless';

const baseURL = 'http://127.0.0.1:3100';

export default defineConfig(headless, {
  use: { baseURL },
  webServer: {
    command: 'npm run build && npm run start -- --hostname 127.0.0.1 --port 3100',
    url: `${baseURL}/login`,
    env: { API_GATEWAY_URL: 'http://127.0.0.1:9', AI_SERVICE_URL: 'http://127.0.0.1:9' },
    reuseExistingServer: false,
    timeout: 180_000,
  },
});
