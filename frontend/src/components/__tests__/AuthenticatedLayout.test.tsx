import React from 'react';
import { render, screen } from '@testing-library/react';
import AuthenticatedLayout from '@/components/layout/AuthenticatedLayout';

// Mock the Header component
jest.mock('@/components/layout/Header', () => {
  return function MockHeader() {
    return <div data-testid="mock-header">Header</div>;
  };
});

describe('AuthenticatedLayout', () => {
  it('renders header and children', () => {
    render(
      <AuthenticatedLayout>
        <div>Test Content</div>
      </AuthenticatedLayout>
    );

    expect(screen.getByTestId('mock-header')).toBeInTheDocument();
    expect(screen.getByText('Test Content')).toBeInTheDocument();
  });

  it('renders multiple children', () => {
    render(
      <AuthenticatedLayout>
        <div>First Child</div>
        <div>Second Child</div>
        <span>Third Child</span>
      </AuthenticatedLayout>
    );

    expect(screen.getByText('First Child')).toBeInTheDocument();
    expect(screen.getByText('Second Child')).toBeInTheDocument();
    expect(screen.getByText('Third Child')).toBeInTheDocument();
  });

  it('applies correct CSS classes', () => {
    const { container } = render(
      <AuthenticatedLayout>
        <div>Test Content</div>
      </AuthenticatedLayout>
    );

    const layoutDiv = container.firstChild as HTMLElement;
    expect(layoutDiv).toHaveClass('min-h-screen', 'bg-gray-50');

    const mainElement = layoutDiv.querySelector('main');
    expect(mainElement).toHaveClass('pt-0');
  });

  it('renders complex nested content', () => {
    render(
      <AuthenticatedLayout>
        <div className="container">
          <h1>Page Title</h1>
          <p>Page content with <strong>bold text</strong> and <em>italic text</em>.</p>
          <button>Click me</button>
        </div>
      </AuthenticatedLayout>
    );

    expect(screen.getByText('Page Title')).toBeInTheDocument();
    expect(screen.getByText(/page content with/i)).toBeInTheDocument();
    expect(screen.getByText('bold text')).toBeInTheDocument();
    expect(screen.getByText('italic text')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Click me' })).toBeInTheDocument();
  });
}); 