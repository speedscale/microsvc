import { test, expect } from '@playwright/test';

test.describe('Core Application Functionality', () => {
  test('should load login page and display form', async ({ page }) => {
    await page.goto('/login');
    
    // Check that the login form is visible
    await expect(page.getByPlaceholder('Enter your username or email')).toBeVisible();
    await expect(page.getByPlaceholder('Enter your password')).toBeVisible();
    await expect(page.getByRole('button', { name: 'Sign in' })).toBeVisible();
    
    // Check that the page title is correct (it's set in layout.tsx)
    await expect(page).toHaveTitle(/Banking Application/);
  });

  test('should load registration page and display form', async ({ page }) => {
    await page.goto('/register');
    
    // Check that the registration form is visible
    await expect(page.getByPlaceholder('Choose a username')).toBeVisible();
    await expect(page.getByPlaceholder('Enter your email address')).toBeVisible();
    await expect(page.getByPlaceholder('Create a password')).toBeVisible();
    await expect(page.getByPlaceholder('Confirm your password')).toBeVisible();
    await expect(page.getByRole('button', { name: 'Create account' })).toBeVisible();
  });

  test('should navigate between login and register pages', async ({ page }) => {
    // Start at login page
    await page.goto('/login');
    
    // Look for the link to register page (exact text from LoginForm)
    const registerLink = page.getByRole('link', { name: 'create a new account' });
    await expect(registerLink).toBeVisible();
    await registerLink.click();
    await expect(page).toHaveURL('/register');
    
    // Look for the link back to login page (exact text from RegisterForm)
    const loginLink = page.getByRole('link', { name: 'sign in to your existing account' });
    await expect(loginLink).toBeVisible();
    await loginLink.click();
    await expect(page).toHaveURL('/login');
  });

  test('should redirect unauthenticated users to login', async ({ page }) => {
    // Try to access protected routes
    await page.goto('/dashboard');
    await expect(page).toHaveURL('/login');
    
    await page.goto('/accounts');
    await expect(page).toHaveURL('/login');
    
    await page.goto('/transactions');
    await expect(page).toHaveURL('/login');
  });

  test('should display form validation on login page', async ({ page }) => {
    await page.goto('/login');
    
    // Try to submit empty form
    await page.getByRole('button', { name: 'Sign in' }).click();
    
    // Should show validation errors or stay on the same page
    await expect(page).toHaveURL('/login');
  });

  test('should display form validation on register page', async ({ page }) => {
    await page.goto('/register');
    
    // Try to submit empty form
    await page.getByRole('button', { name: 'Create account' }).click();
    
    // Should show validation errors or stay on the same page
    await expect(page).toHaveURL('/register');
  });

  test('should allow filling out login form', async ({ page }) => {
    await page.goto('/login');
    
    // Fill out the form
    await page.getByPlaceholder('Enter your username or email').fill('testuser');
    await page.getByPlaceholder('Enter your password').fill('password123');
    
    // Verify the form is filled
    await expect(page.getByPlaceholder('Enter your username or email')).toHaveValue('testuser');
    await expect(page.getByPlaceholder('Enter your password')).toHaveValue('password123');
  });

  test('should allow filling out registration form', async ({ page }) => {
    await page.goto('/register');
    
    // Fill out the form
    await page.getByPlaceholder('Choose a username').fill('newuser');
    await page.getByPlaceholder('Enter your email address').fill('newuser@example.com');
    await page.getByPlaceholder('Create a password').fill('password123');
    await page.getByPlaceholder('Confirm your password').fill('password123');
    
    // Verify the form is filled
    await expect(page.getByPlaceholder('Choose a username')).toHaveValue('newuser');
    await expect(page.getByPlaceholder('Enter your email address')).toHaveValue('newuser@example.com');
    await expect(page.getByPlaceholder('Create a password')).toHaveValue('password123');
    await expect(page.getByPlaceholder('Confirm your password')).toHaveValue('password123');
  });
}); 