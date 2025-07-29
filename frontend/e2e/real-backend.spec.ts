import { test, expect } from '@playwright/test';

test.describe('Real Backend Integration', () => {
  test('should register and login with real backend', async ({ page }) => {
    // Generate unique test data
    const timestamp = Date.now();
    const username = `testuser${timestamp}`;
    const email = `test${timestamp}@example.com`;
    const password = 'password123';

    // Step 1: Navigate to registration page
    await page.goto('/register');
    
    // Step 2: Fill registration form
    await page.getByPlaceholder('Choose a username').fill(username);
    await page.getByPlaceholder('Enter your email address').fill(email);
    await page.getByPlaceholder('Create a password').fill(password);
    await page.getByPlaceholder('Confirm your password').fill(password);
    
    // Step 3: Submit registration
    await page.getByRole('button', { name: 'Create account' }).click();
    
    // Step 4: Wait for registration success and navigate to login
    await expect(page.getByText('Account created successfully! Please sign in.')).toBeVisible();
    await page.getByRole('link', { name: 'sign in to your existing account' }).click();
    await expect(page).toHaveURL('/login');
    
    // Step 5: Login with the same credentials
    await page.getByPlaceholder('Enter your username or email').fill(username);
    await page.getByPlaceholder('Enter your password').fill(password);
    await page.getByRole('button', { name: 'Sign in' }).click();
    
    // Step 6: Verify successful login and redirect to dashboard
    await expect(page).toHaveURL('/dashboard');
    await expect(page.getByText(new RegExp(`Welcome back, ${username}!`))).toBeVisible();
  });

  test('should handle invalid login credentials', async ({ page }) => {
    await page.goto('/login');
    
    // Fill login form with invalid credentials
    await page.getByPlaceholder('Enter your username or email').fill('nonexistentuser');
    await page.getByPlaceholder('Enter your password').fill('wrongpassword');
    await page.getByRole('button', { name: 'Sign in' }).click();
    
    // Should display error message
    await expect(page.getByText(/Invalid username or password|Authentication failed/i)).toBeVisible();
    
    // Should remain on login page
    await expect(page).toHaveURL('/login');
  });

  test('should protect routes when not authenticated', async ({ page }) => {
    // Try to access protected route without authentication
    await page.goto('/dashboard');
    
    // Should redirect to login
    await expect(page).toHaveURL('/login');
  });

  test('should handle logout flow', async ({ page }) => {
    // First, register and login a user
    const timestamp = Date.now();
    const username = `logoutuser${timestamp}`;
    const email = `logout${timestamp}@example.com`;
    const password = 'password123';

    // Register
    await page.goto('/register');
    await page.getByPlaceholder('Choose a username').fill(username);
    await page.getByPlaceholder('Enter your email address').fill(email);
    await page.getByPlaceholder('Create a password').fill(password);
    await page.getByPlaceholder('Confirm your password').fill(password);
    await page.getByRole('button', { name: 'Create account' }).click();
    
    // Navigate to login
    await page.getByRole('link', { name: 'sign in to your existing account' }).click();
    
    // Login
    await page.getByPlaceholder('Enter your username or email').fill(username);
    await page.getByPlaceholder('Enter your password').fill(password);
    await page.getByRole('button', { name: 'Sign in' }).click();
    
    // Verify we're on dashboard
    await expect(page).toHaveURL('/dashboard');
    
    // Logout
    await page.getByRole('button', { name: 'Logout' }).click();
    
    // Should redirect to login
    await expect(page).toHaveURL('/login');
    
    // Should not be able to access protected routes after logout
    await page.goto('/dashboard');
    await expect(page).toHaveURL('/login');
  });

  test('should handle registration with existing username', async ({ page }) => {
    // First, register a user
    const timestamp = Date.now();
    const username = `existinguser${timestamp}`;
    const email = `existing${timestamp}@example.com`;
    const password = 'password123';

    await page.goto('/register');
    await page.getByPlaceholder('Choose a username').fill(username);
    await page.getByPlaceholder('Enter your email address').fill(email);
    await page.getByPlaceholder('Create a password').fill(password);
    await page.getByPlaceholder('Confirm your password').fill(password);
    await page.getByRole('button', { name: 'Create account' }).click();
    
    // Wait for registration success
    await expect(page.getByText('Account created successfully! Please sign in.')).toBeVisible();
    
    // Try to register again with the same username
    await page.goto('/register');
    await page.getByPlaceholder('Choose a username').fill(username);
    await page.getByPlaceholder('Enter your email address').fill('different@example.com');
    await page.getByPlaceholder('Create a password').fill(password);
    await page.getByPlaceholder('Confirm your password').fill(password);
    await page.getByRole('button', { name: 'Create account' }).click();
    
    // Should display error message about existing username
    await expect(page.getByText(/Username already exists|already taken/i)).toBeVisible();
    
    // Should remain on register page
    await expect(page).toHaveURL('/register');
  });

  test('should navigate to accounts page after login', async ({ page }) => {
    // Register and login
    const timestamp = Date.now();
    const username = `accountsuser${timestamp}`;
    const email = `accounts${timestamp}@example.com`;
    const password = 'password123';

    await page.goto('/register');
    await page.getByPlaceholder('Choose a username').fill(username);
    await page.getByPlaceholder('Enter your email address').fill(email);
    await page.getByPlaceholder('Create a password').fill(password);
    await page.getByPlaceholder('Confirm your password').fill(password);
    await page.getByRole('button', { name: 'Create account' }).click();
    
    await page.getByRole('link', { name: 'sign in to your existing account' }).click();
    await page.getByPlaceholder('Enter your username or email').fill(username);
    await page.getByPlaceholder('Enter your password').fill(password);
    await page.getByRole('button', { name: 'Sign in' }).click();
    
    // Navigate to accounts page
    await page.getByRole('link', { name: /accounts/i }).click();
    await expect(page).toHaveURL('/accounts');
    
    // Should show accounts page content
    await expect(page.getByText(/Accounts|My Accounts/i)).toBeVisible();
  });

  test('should navigate to transactions page after login', async ({ page }) => {
    // Register and login
    const timestamp = Date.now();
    const username = `transactionsuser${timestamp}`;
    const email = `transactions${timestamp}@example.com`;
    const password = 'password123';

    await page.goto('/register');
    await page.getByPlaceholder('Choose a username').fill(username);
    await page.getByPlaceholder('Enter your email address').fill(email);
    await page.getByPlaceholder('Create a password').fill(password);
    await page.getByPlaceholder('Confirm your password').fill(password);
    await page.getByRole('button', { name: 'Create account' }).click();
    
    await page.getByRole('link', { name: /sign in|login/i }).click();
    await page.getByPlaceholder('Enter your username or email').fill(username);
    await page.getByPlaceholder('Enter your password').fill(password);
    await page.getByRole('button', { name: 'Sign in' }).click();
    
    // Navigate to transactions page
    await page.getByRole('link', { name: /transactions/i }).click();
    await expect(page).toHaveURL('/transactions');
    
    // Should show transactions page content
    await expect(page.getByText(/Transactions|Transaction History/i)).toBeVisible();
  });
}); 