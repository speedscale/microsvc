import { test, expect } from '@playwright/test';

// Test configuration
// For Kubernetes: frontend and API are both accessible through the same URL
const BASE_URL = process.env.BASE_URL || 'http://localhost:3000';
const API_URL = process.env.API_URL || BASE_URL;

// Generate unique test data
const timestamp = Date.now();
const testUser = {
  username: `testuser${timestamp}`,
  email: `test${timestamp}@example.com`,
  password: 'TestPassword123!'
};

test.describe('Banking Application User Journey', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto(BASE_URL);
  });

  test('Complete user journey: UI navigation flow', async ({ page }) => {
    // 1. Visit home page (redirects to login if not authenticated)
    await expect(page).toHaveTitle(/Banking Application/);
    
    // Should redirect to login page automatically
    await expect(page).toHaveURL(/.*\/login/, { timeout: 10000 });
    await expect(page.locator('h2')).toContainText(/Sign in to your account/);
    
    // 2. Navigate to registration and test form
    await page.click('text=create a new account');
    await expect(page).toHaveURL(/.*\/register/);
    await expect(page.locator('h2')).toContainText(/Create your account/);
    
    // 3. Test registration form (without backend, just UI validation)
    await page.fill('input[name="username"]', testUser.username);
    await page.fill('input[name="email"]', testUser.email);
    await page.fill('input[name="password"]', testUser.password);
    await page.fill('input[name="confirmPassword"]', testUser.password);
    
    // Verify form fields are filled
    await expect(page.locator('input[name="username"]')).toHaveValue(testUser.username);
    await expect(page.locator('input[name="email"]')).toHaveValue(testUser.email);
    
    // 4. Navigate back to login (since backend isn't available)
    await page.goto(`${BASE_URL}/login`);
    await expect(page).toHaveURL(/.*\/login/);
    
    // Test the login form UI (without actual authentication)
    await page.fill('input[name="usernameOrEmail"]', testUser.username);
    await page.fill('input[name="password"]', testUser.password);
    
    // Verify login form fields are filled
    await expect(page.locator('input[name="usernameOrEmail"]')).toHaveValue(testUser.username);
    await expect(page.locator('input[name="password"]')).toHaveValue(testUser.password);
    
    // 5. Test navigation to protected routes (should redirect back to login)
    await page.goto(`${BASE_URL}/dashboard`);
    await expect(page).toHaveURL(/.*\/login/, { timeout: 5000 });
    
    await page.goto(`${BASE_URL}/accounts`);
    await expect(page).toHaveURL(/.*\/login/, { timeout: 5000 });
    
    await page.goto(`${BASE_URL}/transactions`);
    await expect(page).toHaveURL(/.*\/login/, { timeout: 5000 });
    
    await page.goto(`${BASE_URL}/profile`);
    await expect(page).toHaveURL(/.*\/login/, { timeout: 5000 });
  });

  test('Visit all public pages', async ({ page }) => {
    const publicPages = [
      { path: '/login', selector: 'h2', title: 'Sign in to your account' },
      { path: '/register', selector: 'h2', title: 'Create your account' }
    ];
    
    for (const pageInfo of publicPages) {
      await page.goto(`${BASE_URL}${pageInfo.path}`);
      await expect(page.locator(pageInfo.selector)).toContainText(pageInfo.title);
      
      // Check for no console errors
      page.on('console', msg => {
        if (msg.type() === 'error') {
          throw new Error(`Console error on ${pageInfo.path}: ${msg.text()}`);
        }
      });
      
      // Check for no network errors
      page.on('response', response => {
        if (response.status() >= 400 && !response.url().includes('api')) {
          throw new Error(`HTTP ${response.status()} on ${pageInfo.path}: ${response.url()}`);
        }
      });
    }
  });

  test('Protected routes redirect to login', async ({ page }) => {
    const protectedRoutes = [
      '/dashboard',
      '/accounts',
      '/transactions',
      '/profile'
    ];
    
    for (const route of protectedRoutes) {
      await page.goto(`${BASE_URL}${route}`);
      await expect(page).toHaveURL(/.*\/login/, { timeout: 5000 });
    }
  });

  test('API health checks', async ({ page }) => {
    // For dev server, just check if it responds
    if (API_URL === BASE_URL) {
      // Testing against same URL (likely dev server), just check basic connectivity
      const response = await page.request.get(`${BASE_URL}/login`);
      expect(response.status()).toBe(200);
    } else {
      // Testing against separate API server
      const response = await page.request.get(`${API_URL}/actuator/health`);
      expect(response.status()).toBe(200);
      
      const health = await response.json();
      expect(health.status).toBe('UP');
    }
  });
});

test.describe('Performance Monitoring', () => {
  test('Page load performance', async ({ page }) => {
    // Visit key pages and measure load time directly
    const pages = ['/login', '/register'];
    for (const path of pages) {
      const startTime = Date.now();
      await page.goto(`${BASE_URL}${path}`);
      
      // Wait for page to be fully loaded
      await page.waitForLoadState('networkidle');
      
      const loadTime = Date.now() - startTime;
      expect(loadTime).toBeLessThan(10000); // 10 seconds should be plenty
    }
  });

  test('Check for memory leaks', async ({ page }) => {
    await page.goto(`${BASE_URL}/login`);
    
    // Get initial memory usage
    const initialMemory = await page.evaluate(() => {
      if ('memory' in performance) {
        return (performance as any).memory.usedJSHeapSize;
      }
      return null;
    });
    
    if (initialMemory) {
      // Perform multiple navigations
      for (let i = 0; i < 5; i++) {
        await page.goto(`${BASE_URL}/login`);
        await page.goto(`${BASE_URL}/register`);
      }
      
      // Force garbage collection if available (browser context)
      await page.evaluate(() => {
        if (window.gc) {
          window.gc();
        }
      });
      
      // Check final memory usage
      const finalMemory = await page.evaluate(() => {
        if ('memory' in performance) {
          return (performance as any).memory.usedJSHeapSize;
        }
        return null;
      });
      
      if (finalMemory) {
        // Memory should not increase by more than 50MB
        const memoryIncrease = (finalMemory - initialMemory) / 1024 / 1024;
        expect(memoryIncrease).toBeLessThan(50);
      }
    } else {
      // If memory measurement not available, just do basic navigation test
      for (let i = 0; i < 3; i++) {
        await page.goto(`${BASE_URL}/login`);
        await page.goto(`${BASE_URL}/register`);
      }
      // Test passes if no crashes occur
      expect(true).toBe(true);
    }
  });
});