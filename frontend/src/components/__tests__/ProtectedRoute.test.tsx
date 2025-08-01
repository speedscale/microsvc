import React from 'react';
import { render, screen, waitFor } from '@testing-library/react';
import { useRouter } from 'next/navigation';
import { useAuth } from '@/lib/auth/context';
import ProtectedRoute from '@/components/auth/ProtectedRoute';

// Mock Next.js router
jest.mock('next/navigation', () => ({
  useRouter: jest.fn(),
}));

// Mock auth context
jest.mock('@/lib/auth/context', () => ({
  useAuth: jest.fn(),
}));

describe('ProtectedRoute', () => {
  const mockRouter = {
    push: jest.fn(),
  };

  const mockAuth = {
    isAuthenticated: false,
    isLoading: false,
  };

  beforeEach(() => {
    (useRouter as jest.Mock).mockReturnValue(mockRouter);
    (useAuth as jest.Mock).mockReturnValue(mockAuth);
    jest.clearAllMocks();
  });

  it('renders children when user is authenticated and auth is required', () => {
    (useAuth as jest.Mock).mockReturnValue({
      isAuthenticated: true,
      isLoading: false,
    });

    render(
      <ProtectedRoute>
        <div>Protected Content</div>
      </ProtectedRoute>
    );

    expect(screen.getByText('Protected Content')).toBeInTheDocument();
    expect(mockRouter.push).not.toHaveBeenCalled();
  });

  it('redirects to login when user is not authenticated and auth is required', async () => {
    (useAuth as jest.Mock).mockReturnValue({
      isAuthenticated: false,
      isLoading: false,
    });

    render(
      <ProtectedRoute>
        <div>Protected Content</div>
      </ProtectedRoute>
    );

    await waitFor(() => {
      expect(mockRouter.push).toHaveBeenCalledWith('/login');
    });

    expect(screen.queryByText('Protected Content')).not.toBeInTheDocument();
  });

  it('redirects to custom path when user is not authenticated', async () => {
    (useAuth as jest.Mock).mockReturnValue({
      isAuthenticated: false,
      isLoading: false,
    });

    render(
      <ProtectedRoute redirectTo="/custom-login">
        <div>Protected Content</div>
      </ProtectedRoute>
    );

    await waitFor(() => {
      expect(mockRouter.push).toHaveBeenCalledWith('/custom-login');
    });
  });

  it('shows loading spinner while authentication is being checked', () => {
    (useAuth as jest.Mock).mockReturnValue({
      isAuthenticated: false,
      isLoading: true,
    });

    render(
      <ProtectedRoute>
        <div>Protected Content</div>
      </ProtectedRoute>
    );

    expect(screen.getByText('Loading...')).toBeInTheDocument();
    expect(screen.queryByText('Protected Content')).not.toBeInTheDocument();
    expect(mockRouter.push).not.toHaveBeenCalled();
  });

  it('renders children when auth is not required and user is not authenticated', () => {
    (useAuth as jest.Mock).mockReturnValue({
      isAuthenticated: false,
      isLoading: false,
    });

    render(
      <ProtectedRoute requireAuth={false}>
        <div>Public Content</div>
      </ProtectedRoute>
    );

    expect(screen.getByText('Public Content')).toBeInTheDocument();
    expect(mockRouter.push).not.toHaveBeenCalled();
  });

  it('redirects authenticated users away from public pages', async () => {
    (useAuth as jest.Mock).mockReturnValue({
      isAuthenticated: true,
      isLoading: false,
    });

    render(
      <ProtectedRoute requireAuth={false}>
        <div>Public Content</div>
      </ProtectedRoute>
    );

    await waitFor(() => {
      expect(mockRouter.push).toHaveBeenCalledWith('/dashboard');
    });

    expect(screen.queryByText('Public Content')).not.toBeInTheDocument();
  });

  it('does not redirect while loading even if user is not authenticated', () => {
    (useAuth as jest.Mock).mockReturnValue({
      isAuthenticated: false,
      isLoading: true,
    });

    render(
      <ProtectedRoute>
        <div>Protected Content</div>
      </ProtectedRoute>
    );

    expect(screen.getByText('Loading...')).toBeInTheDocument();
    expect(mockRouter.push).not.toHaveBeenCalled();
  });

  it('does not redirect while loading even if user is authenticated on public page', () => {
    (useAuth as jest.Mock).mockReturnValue({
      isAuthenticated: true,
      isLoading: true,
    });

    render(
      <ProtectedRoute requireAuth={false}>
        <div>Public Content</div>
      </ProtectedRoute>
    );

    expect(screen.getByText('Loading...')).toBeInTheDocument();
    expect(mockRouter.push).not.toHaveBeenCalled();
  });

  it('handles multiple children correctly', () => {
    (useAuth as jest.Mock).mockReturnValue({
      isAuthenticated: true,
      isLoading: false,
    });

    render(
      <ProtectedRoute>
        <div>First Child</div>
        <div>Second Child</div>
        <span>Third Child</span>
      </ProtectedRoute>
    );

    expect(screen.getByText('First Child')).toBeInTheDocument();
    expect(screen.getByText('Second Child')).toBeInTheDocument();
    expect(screen.getByText('Third Child')).toBeInTheDocument();
  });

  it('updates redirect when auth state changes', async () => {
    const { rerender } = render(
      <ProtectedRoute>
        <div>Protected Content</div>
      </ProtectedRoute>
    );

    // Initially loading
    (useAuth as jest.Mock).mockReturnValue({
      isAuthenticated: false,
      isLoading: true,
    });

    rerender(
      <ProtectedRoute>
        <div>Protected Content</div>
      </ProtectedRoute>
    );

    expect(screen.getByText('Loading...')).toBeInTheDocument();

    // Then not authenticated
    (useAuth as jest.Mock).mockReturnValue({
      isAuthenticated: false,
      isLoading: false,
    });

    rerender(
      <ProtectedRoute>
        <div>Protected Content</div>
      </ProtectedRoute>
    );

    await waitFor(() => {
      expect(mockRouter.push).toHaveBeenCalledWith('/login');
    });
  });
}); 