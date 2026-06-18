'use client';

import React, { useEffect, useMemo, useState } from 'react';
import ProtectedRoute from '@/components/auth/ProtectedRoute';
import AuthenticatedLayout from '@/components/layout/AuthenticatedLayout';
import { useAuth } from '@/lib/auth/context';
import Button from '@/components/ui/Button';
import { AccountsAPI, Account } from '@/lib/api/accounts';
import { demoTransfer, demoUser } from '@/lib/demo';

const DashboardPage: React.FC = () => {
  const { user } = useAuth();
  const [accounts, setAccounts] = useState<Account[]>([]);

  useEffect(() => {
    const fetchAccounts = async () => {
      const response = await AccountsAPI.getAccounts();
      if (response.success && response.data) {
        setAccounts(response.data);
      }
    };

    fetchAccounts();
  }, []);

  const checkingAccount = useMemo(
    () => accounts.find((account) => account.accountType === 'CHECKING'),
    [accounts]
  );

  const savingsAccount = useMemo(
    () => accounts.find((account) => account.accountType === 'SAVINGS'),
    [accounts]
  );

  const openTransferReview = () => {
    if (checkingAccount) {
      window.location.href = `/accounts/${checkingAccount.id}/transfer?demo=${demoTransfer.queryValue}`;
      return;
    }

    window.location.href = '/accounts';
  };

  return (
    <ProtectedRoute requireAuth={true}>
      <AuthenticatedLayout>
        <div className="max-w-7xl mx-auto py-6 sm:px-6 lg:px-8">
          <div className="px-4 py-6 sm:px-0">
            <div className="bg-white shadow rounded-lg">
              <div className="px-4 py-5 sm:p-6">
                <h1 className="text-2xl font-bold text-gray-900 mb-4">
                  Welcome to Apex Banking
                </h1>

                <div className="mb-6 rounded-md border border-blue-200 bg-blue-50 p-4">
                  <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
                    <div>
                      <h2 className="text-lg font-medium text-blue-900">
                        {user?.username === demoUser.username ? demoUser.name : user?.username}
                      </h2>
                      <p className="mt-1 text-sm text-blue-700">
                        {checkingAccount && savingsAccount
                          ? 'Checking and savings accounts are ready.'
                          : 'Waiting for seeded checking and savings accounts.'}
                      </p>
                    </div>
                    <Button
                      variant="primary"
                      onClick={openTransferReview}
                      disabled={!checkingAccount}
                    >
                      Start Transfer Review
                    </Button>
                  </div>
                </div>
                
                {user && (
                  <div className="mb-6 p-4 bg-blue-50 rounded-md">
                    <h2 className="text-lg font-medium text-blue-900 mb-2">
                      User Information
                    </h2>
                    <div className="text-sm text-blue-700 space-y-1">
                      <p><strong>ID:</strong> {user.id}</p>
                      <p><strong>Username:</strong> {user.username}</p>
                      <p><strong>Email:</strong> {user.email}</p>
                      <p><strong>Roles:</strong> {user.roles}</p>
                    </div>
                  </div>
                )}

                <div className="border-t border-gray-200 pt-6">
                  <div className="flex justify-between items-center">
                    <div>
                      <h3 className="text-lg font-medium text-gray-900">
                        Banking Features
                      </h3>
                      <p className="text-sm text-gray-600">
                        Manage your accounts and transactions
                      </p>
                    </div>
                    <div className="flex space-x-3">
                      <Button
                        variant="outline"
                        onClick={() => window.location.href = '/accounts'}
                      >
                        View Accounts
                      </Button>
                      <Button
                        variant="outline"
                        onClick={() => window.location.href = '/transactions'}
                      >
                        View Transactions
                      </Button>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </AuthenticatedLayout>
    </ProtectedRoute>
  );
};

export default DashboardPage;
