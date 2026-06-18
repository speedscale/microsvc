'use client';

import { useEffect } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { useAuth } from '@/lib/auth/context';
import { demoUser } from '@/lib/demo';

export default function Home() {
  const { isAuthenticated, isLoading } = useAuth();
  const router = useRouter();

  useEffect(() => {
    if (!isLoading && isAuthenticated) {
      router.push('/dashboard');
    }
  }, [isAuthenticated, isLoading, router]);

  if (isLoading || isAuthenticated) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gray-50">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600 mx-auto"></div>
          <p className="mt-4 text-gray-600">Loading...</p>
        </div>
      </div>
    );
  }

  return (
    <main className="min-h-screen bg-gray-50">
      <div className="mx-auto flex min-h-screen max-w-6xl items-center px-4 py-10 sm:px-6 lg:px-8">
        <div className="grid w-full gap-8 lg:grid-cols-[1.1fr_0.9fr] lg:items-center">
          <section>
            <div className="mb-6 flex h-12 w-12 items-center justify-center rounded-lg bg-blue-600">
              <span className="text-lg font-bold text-white">A</span>
            </div>
            <h1 className="text-4xl font-bold tracking-normal text-gray-900 sm:text-5xl">
              Apex Banking
            </h1>
            <p className="mt-4 max-w-2xl text-lg text-gray-600">
              Customer accounts, transfers, and assistant workflows in one banking experience.
            </p>
            <div className="mt-8 flex flex-col gap-3 sm:flex-row">
              <Link
                href="/login"
                className="inline-flex items-center justify-center rounded-md bg-blue-600 px-5 py-3 text-base font-medium text-white hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2"
              >
                Sign in
              </Link>
              <Link
                href="/register"
                className="inline-flex items-center justify-center rounded-md border border-gray-300 bg-white px-5 py-3 text-base font-medium text-gray-700 hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2"
              >
                Open account
              </Link>
            </div>
          </section>

          <aside className="rounded-lg border border-gray-200 bg-white p-6 shadow">
            <p className="text-sm font-medium uppercase tracking-wide text-blue-600">
              Demo customer
            </p>
            <h2 className="mt-2 text-2xl font-semibold text-gray-900">{demoUser.name}</h2>
            <dl className="mt-5 space-y-4 text-sm">
              <div>
                <dt className="font-medium text-gray-500">Username</dt>
                <dd className="mt-1 font-mono text-gray-900">{demoUser.username}</dd>
              </div>
              <div>
                <dt className="font-medium text-gray-500">Password</dt>
                <dd className="mt-1 font-mono text-gray-900">{demoUser.password}</dd>
              </div>
              <div>
                <dt className="font-medium text-gray-500">Accounts</dt>
                <dd className="mt-1 text-gray-900">Checking and savings</dd>
              </div>
            </dl>
          </aside>
        </div>
      </div>
    </main>
  );
}
