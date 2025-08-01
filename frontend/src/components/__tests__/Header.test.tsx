import React from 'react';
import { render, screen, fireEvent } from '@testing-library/react';
import { useRouter } from 'next/navigation';
import { useAuth } from '@/lib/auth/context';
import Header from '@/components/layout/Header';

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
  return function MockLink({ children, href, ...props }: any) {
    return <a href={href} {...props}>{children}</a>;
  };
});

describe('Header', () => {
  const mockRouter = {
    push: jest.fn(),
  };

  const mockAuth = {
    user: null,
    logout: jest.fn(),
  };

  beforeEach(() => {
    (useRouter as jest.Mock).mockReturnValue(mockRouter);
    (useAuth as jest.Mock).mockReturnValue(mockAuth);
    jest.clearAllMocks();
  });

  it('renders nothing when user is not authenticated', () => {
    (useAuth as jest.Mock).mockReturnValue({
      user: null,
      logout: jest.fn(),
    });

    const { container } = render(<Header />);
    expect(container.firstChild).toBeNull();
  });

  it('renders header with navigation when user is authenticated', () => {
    (useAuth as jest.Mock).mockReturnValue({
      user: { username: 'testuser', email: 'test@example.com' },
      logout: jest.fn(),
    });

    render(<Header />);

    expect(screen.getByText('Banking App')).toBeInTheDocument();
    expect(screen.getAllByText('Dashboard')).toHaveLength(2);
    expect(screen.getAllByText('Accounts')).toHaveLength(2);
    expect(screen.getAllByText('Transactions')).toHaveLength(2);
    expect(screen.getAllByText('Profile')).toHaveLength(2);
    expect(screen.getByText('Logout')).toBeInTheDocument();
  });

  it('displays user welcome message', () => {
    (useAuth as jest.Mock).mockReturnValue({
      user: { username: 'john_doe', email: 'john@example.com' },
      logout: jest.fn(),
    });

    render(<Header />);

    expect(screen.getByText('john_doe')).toBeInTheDocument();
  });

  it('handles logout when logout button is clicked', () => {
    const mockLogout = jest.fn();
    (useAuth as jest.Mock).mockReturnValue({
      user: { username: 'testuser', email: 'test@example.com' },
      logout: mockLogout,
    });

    render(<Header />);

    const logoutButton = screen.getByRole('button', { name: /logout/i });
    fireEvent.click(logoutButton);

    expect(mockLogout).toHaveBeenCalled();
    expect(mockRouter.push).toHaveBeenCalledWith('/login');
  });

  it('renders logo with correct link', () => {
    (useAuth as jest.Mock).mockReturnValue({
      user: { username: 'testuser', email: 'test@example.com' },
      logout: jest.fn(),
    });

    render(<Header />);

    const logoLink = screen.getByRole('link', { name: /banking app/i });
    expect(logoLink).toHaveAttribute('href', '/dashboard');
  });

  it('renders all navigation links with correct hrefs', () => {
    (useAuth as jest.Mock).mockReturnValue({
      user: { username: 'testuser', email: 'test@example.com' },
      logout: jest.fn(),
    });

    render(<Header />);

    const dashboardLinks = screen.getAllByRole('link', { name: /dashboard/i });
    const accountsLinks = screen.getAllByRole('link', { name: /accounts/i });
    const transactionsLinks = screen.getAllByRole('link', { name: /transactions/i });
    const profileLinks = screen.getAllByRole('link', { name: /profile/i });

    expect(dashboardLinks[0]).toHaveAttribute('href', '/dashboard');
    expect(accountsLinks[0]).toHaveAttribute('href', '/accounts');
    expect(transactionsLinks[0]).toHaveAttribute('href', '/transactions');
    expect(profileLinks[0]).toHaveAttribute('href', '/profile');
  });

  it('renders mobile navigation menu', () => {
    (useAuth as jest.Mock).mockReturnValue({
      user: { username: 'testuser', email: 'test@example.com' },
      logout: jest.fn(),
    });

    render(<Header />);

    // Mobile navigation should be present but hidden on desktop
    const mobileNav = screen.getAllByText('Dashboard')[1].closest('.md\\:hidden');
    expect(mobileNav).toBeInTheDocument();
  });

  it('renders logo icon', () => {
    (useAuth as jest.Mock).mockReturnValue({
      user: { username: 'testuser', email: 'test@example.com' },
      logout: jest.fn(),
    });

    render(<Header />);

    expect(screen.getByText('B')).toBeInTheDocument();
  });

  it('handles user with different username formats', () => {
    (useAuth as jest.Mock).mockReturnValue({
      user: { username: 'user123', email: 'user123@example.com' },
      logout: jest.fn(),
    });

    render(<Header />);

    expect(screen.getByText('user123')).toBeInTheDocument();
  });

  it('handles user with special characters in username', () => {
    (useAuth as jest.Mock).mockReturnValue({
      user: { username: 'user-name_123', email: 'user@example.com' },
      logout: jest.fn(),
    });

    render(<Header />);

    expect(screen.getByText('user-name_123')).toBeInTheDocument();
  });

  it('calls logout and navigation in correct order', () => {
    const mockLogout = jest.fn();
    (useAuth as jest.Mock).mockReturnValue({
      user: { username: 'testuser', email: 'test@example.com' },
      logout: mockLogout,
    });

    render(<Header />);

    const logoutButton = screen.getByRole('button', { name: /logout/i });
    fireEvent.click(logoutButton);

    // Verify both functions were called
    expect(mockLogout).toHaveBeenCalled();
    expect(mockRouter.push).toHaveBeenCalledWith('/login');
  });
}); 