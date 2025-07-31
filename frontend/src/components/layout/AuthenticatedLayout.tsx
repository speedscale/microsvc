'use client';

import React from 'react';
import Header from './Header';

interface AuthenticatedLayoutProps {
  children: React.ReactNode;
}

const AuthenticatedLayout: React.FC<AuthenticatedLayoutProps> = ({ children }) => {
  return (
    <div className="min-h-screen bg-gray-50">
      <Header />
      <main className="pt-0">
        {children}
      </main>
    </div>
  );
};

export default AuthenticatedLayout; 