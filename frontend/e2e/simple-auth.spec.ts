import { test, expect } from '@playwright/test';

test.describe('Simple Authentication Tests', () => {
  test('should show registration form and handle form validation', async ({ page }) => {
    // Navigate to registration page
    await page.goto('/register');
    
    // Verify the form is visible
    await expect(page.getByText('Create your account')).toBeVisible();
    await expect(page.getByPlaceholder('Choose a username')).toBeVisible();
    await expect(page.getByPlaceholder('Enter your email address')).toBeVisible();
    await expect(page.getByPlaceholder('Create a password')).toBeVisible();
    await expect(page.getByPlaceholder('Confirm your password')).toBeVisible();
    
    // Try to submit empty form
    await page.getByRole('button', { name: 'Create account' }).click();
    
    // Should show validation errors (check for any validation error)
    await expect(page.locator('p.text-red-600')).toBeVisible();
  });

  test('should show login form and handle form validation', async ({ page }) => {
    // Navigate to login page
    await page.goto('/login');
    
    // Verify the form is visible
    await expect(page.getByText('Sign in to your account')).toBeVisible();
    await expect(page.getByPlaceholder('Enter your username or email')).toBeVisible();
    await expect(page.getByPlaceholder('Enter your password')).toBeVisible();
    
    // Try to submit empty form
    await page.getByRole('button', { name: 'Sign in' }).click();
    
    // Should show validation errors (check for any validation error)
    await expect(page.locator('p.text-red-600')).toBeVisible();
  });

  test('should navigate between login and register pages', async ({ page }) => {
    // Start at login page
    await page.goto('/login');
    await expect(page.getByText('Sign in to your account')).toBeVisible();
    
    // Click link to register
    await page.getByRole('link', { name: 'create a new account' }).click();
    await expect(page).toHaveURL('/register');
    await expect(page.getByText('Create your account')).toBeVisible();
    
    // Click link back to login
    await page.getByRole('link', { name: 'sign in to your existing account' }).click();
    await expect(page).toHaveURL('/login');
    await expect(page.getByText('Sign in to your account')).toBeVisible();
  });

  test('should protect dashboard route when not authenticated', async ({ page }) => {
    // Try to access dashboard without authentication
    await page.goto('/dashboard');
    
    // Should redirect to login
    await expect(page).toHaveURL('/login');
    await expect(page.getByText('Sign in to your account')).toBeVisible();
  });

  test('should protect accounts route when not authenticated', async ({ page }) => {
    // Try to access accounts without authentication
    await page.goto('/accounts');
    
    // Should redirect to login
    await expect(page).toHaveURL('/login');
    await expect(page.getByText('Sign in to your account')).toBeVisible();
  });

  test('should protect transactions route when not authenticated', async ({ page }) => {
    // Try to access transactions without authentication
    await page.goto('/transactions');
    
    // Should redirect to login
    await expect(page).toHaveURL('/login');
    await expect(page.getByText('Sign in to your account')).toBeVisible();
  });
}); 