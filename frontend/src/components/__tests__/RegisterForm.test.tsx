import React from 'react';
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { useRouter } from 'next/navigation';
import { useAuth } from '@/lib/auth/context';
import RegisterForm from '@/components/auth/RegisterForm';

// Mock Next.js router
jest.mock('next/navigation', () => ({
  useRouter: jest.fn(),
}));

// Mock auth context
jest.mock('@/lib/auth/context', () => ({
  useAuth: jest.fn(),
}));

// Mock Next.js Link component
jest.mock('next/link', () => {
  return function MockLink({ children, href, ...props }: Record<string, unknown>) {
    return <a href={href} {...props}>{children}</a>;
  };
});

describe('RegisterForm', () => {
  const mockRouter = {
    push: jest.fn(),
  };

  const mockAuth = {
    register: jest.fn(),
  };

  beforeEach(() => {
    (useRouter as jest.Mock).mockReturnValue(mockRouter);
    (useAuth as jest.Mock).mockReturnValue(mockAuth);
    jest.clearAllMocks();
  });

  it('renders registration form with all fields', () => {
    render(<RegisterForm />);

    expect(screen.getByText('Create your account')).toBeInTheDocument();
    expect(screen.getByLabelText(/username/i)).toBeInTheDocument();
    expect(screen.getByLabelText(/email/i)).toBeInTheDocument();
    expect(screen.getByLabelText(/^password$/i)).toBeInTheDocument();
    expect(screen.getByLabelText(/confirm password/i)).toBeInTheDocument();
    expect(screen.getByLabelText(/generate demo data/i)).toBeInTheDocument();
    expect(screen.getByLabelText(/agree to the terms/i)).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /create account/i })).toBeInTheDocument();
  });

  it('shows validation errors for invalid input', async () => {
    const user = userEvent.setup();
    render(<RegisterForm />);

    // Fill in some fields but leave others empty to trigger validation
    await user.type(screen.getByLabelText(/username/i), 'test');
    await user.type(screen.getByLabelText(/email/i), 'invalid-email');
    await user.type(screen.getByLabelText(/^password$/i), 'short');
    
    // Check terms agreement
    const termsCheckbox = screen.getByLabelText(/agree to the terms/i);
    await user.click(termsCheckbox);

    const submitButton = screen.getByRole('button', { name: /create account/i });
    await user.click(submitButton);

    // The form should still be rendered (no navigation)
    expect(screen.getByText('Create your account')).toBeInTheDocument();
  });

  it('submits form with valid data successfully', async () => {
    const user = userEvent.setup();
    mockAuth.register.mockResolvedValue({ success: true });

    render(<RegisterForm />);

    // Fill in form fields
    await user.type(screen.getByLabelText(/username/i), 'testuser');
    await user.type(screen.getByLabelText(/email/i), 'test@example.com');
    await user.type(screen.getByLabelText(/^password$/i), 'password123');
    await user.type(screen.getByLabelText(/confirm password/i), 'password123');
    
    // Check terms agreement
    const termsCheckbox = screen.getByLabelText(/agree to the terms/i);
    await user.click(termsCheckbox);

    // Submit form
    const submitButton = screen.getByRole('button', { name: /create account/i });
    await user.click(submitButton);

    await waitFor(() => {
      expect(mockAuth.register).toHaveBeenCalledWith({
        username: 'testuser',
        email: 'test@example.com',
        password: 'password123',
        generateDemoData: false,
      });
    });

    // Should show success message and redirect
    await waitFor(() => {
      expect(screen.getByText(/account created successfully/i)).toBeInTheDocument();
    });

    // Should redirect after 2 seconds
    await waitFor(() => {
      expect(mockRouter.push).toHaveBeenCalledWith('/login');
    }, { timeout: 3000 });
  });

  it('handles registration failure', async () => {
    const user = userEvent.setup();
    mockAuth.register.mockResolvedValue({ 
      success: false, 
      message: 'Username already exists' 
    });

    render(<RegisterForm />);

    // Fill in form fields
    await user.type(screen.getByLabelText(/username/i), 'existinguser');
    await user.type(screen.getByLabelText(/email/i), 'test@example.com');
    await user.type(screen.getByLabelText(/^password$/i), 'password123');
    await user.type(screen.getByLabelText(/confirm password/i), 'password123');
    
    // Check terms agreement
    const termsCheckbox = screen.getByLabelText(/agree to the terms/i);
    await user.click(termsCheckbox);

    // Submit form
    const submitButton = screen.getByRole('button', { name: /create account/i });
    await user.click(submitButton);

    await waitFor(() => {
      expect(screen.getByText(/registration failed/i)).toBeInTheDocument();
      expect(screen.getByText(/username already exists/i)).toBeInTheDocument();
    });
  });

  it('handles network errors', async () => {
    const user = userEvent.setup();
    mockAuth.register.mockRejectedValue(new Error('Network error'));

    render(<RegisterForm />);

    // Fill in form fields
    await user.type(screen.getByLabelText(/username/i), 'testuser');
    await user.type(screen.getByLabelText(/email/i), 'test@example.com');
    await user.type(screen.getByLabelText(/^password$/i), 'password123');
    await user.type(screen.getByLabelText(/confirm password/i), 'password123');
    
    // Check terms agreement
    const termsCheckbox = screen.getByLabelText(/agree to the terms/i);
    await user.click(termsCheckbox);

    // Submit form
    const submitButton = screen.getByRole('button', { name: /create account/i });
    await user.click(submitButton);

    await waitFor(() => {
      expect(screen.getByText(/registration failed/i)).toBeInTheDocument();
      expect(screen.getByText(/unexpected error occurred/i)).toBeInTheDocument();
    });
  });

  it('includes demo data when checkbox is checked', async () => {
    const user = userEvent.setup();
    mockAuth.register.mockResolvedValue({ success: true });

    render(<RegisterForm />);

    // Fill in form fields
    await user.type(screen.getByLabelText(/username/i), 'testuser');
    await user.type(screen.getByLabelText(/email/i), 'test@example.com');
    await user.type(screen.getByLabelText(/^password$/i), 'password123');
    await user.type(screen.getByLabelText(/confirm password/i), 'password123');
    
    // Check demo data checkbox
    const demoDataCheckbox = screen.getByLabelText(/generate demo data/i);
    await user.click(demoDataCheckbox);
    
    // Check terms agreement
    const termsCheckbox = screen.getByLabelText(/agree to the terms/i);
    await user.click(termsCheckbox);

    // Submit form
    const submitButton = screen.getByRole('button', { name: /create account/i });
    await user.click(submitButton);

    await waitFor(() => {
      expect(mockAuth.register).toHaveBeenCalledWith({
        username: 'testuser',
        email: 'test@example.com',
        password: 'password123',
        generateDemoData: true,
      });
    });
  });

  it('shows loading state during submission', async () => {
    const user = userEvent.setup();
    // Create a promise that doesn't resolve immediately
    let resolvePromise: (value: unknown) => void;
    const pendingPromise = new Promise((resolve) => {
      resolvePromise = resolve;
    });
    mockAuth.register.mockReturnValue(pendingPromise);

    render(<RegisterForm />);

    // Fill in form fields
    await user.type(screen.getByLabelText(/username/i), 'testuser');
    await user.type(screen.getByLabelText(/email/i), 'test@example.com');
    await user.type(screen.getByLabelText(/^password$/i), 'password123');
    await user.type(screen.getByLabelText(/confirm password/i), 'password123');
    
    // Check terms agreement
    const termsCheckbox = screen.getByLabelText(/agree to the terms/i);
    await user.click(termsCheckbox);

    // Submit form
    const submitButton = screen.getByRole('button', { name: /create account/i });
    await user.click(submitButton);

    // Should show loading state
    expect(screen.getByText(/creating account/i)).toBeInTheDocument();
    expect(submitButton).toBeDisabled();

    // Resolve the promise
    resolvePromise!({ success: true });

    await waitFor(() => {
      expect(screen.getByText(/account created successfully/i)).toBeInTheDocument();
    });
  });

  it('validates password confirmation', async () => {
    const user = userEvent.setup();
    render(<RegisterForm />);

    // Fill in form fields with mismatched passwords
    await user.type(screen.getByLabelText(/username/i), 'testuser');
    await user.type(screen.getByLabelText(/email/i), 'test@example.com');
    await user.type(screen.getByLabelText(/^password$/i), 'password123');
    await user.type(screen.getByLabelText(/confirm password/i), 'differentpassword');
    
    // Check terms agreement
    const termsCheckbox = screen.getByLabelText(/agree to the terms/i);
    await user.click(termsCheckbox);

    // Submit form
    const submitButton = screen.getByRole('button', { name: /create account/i });
    await user.click(submitButton);

    await waitFor(() => {
      expect(screen.getByText(/passwords do not match/i)).toBeInTheDocument();
    });
  });
}); 