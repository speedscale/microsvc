'use client';

import React, { useState, useEffect } from 'react';
import { useParams, useRouter } from 'next/navigation';
import ProtectedRoute from '@/components/auth/ProtectedRoute';
import AuthenticatedLayout from '@/components/layout/AuthenticatedLayout';
import { useAuth } from '@/lib/auth/context';
import Button from '@/components/ui/Button';
import Input from '@/components/ui/Input';
import Link from 'next/link';
import { TransactionsAPI } from '@/lib/api/transactions';

interface Account {
  id: number;
  accountNumber: string;
  accountType: string;
  balance: number;
  currency: string;
  status: string;
}

const DepositPage: React.FC = () => {
  const params = useParams();
  const router = useRouter();
  const { user } = useAuth();
  const [account, setAccount] = useState<Account | null>(null);
  const [amount, setAmount] = useState('');
  const [description, setDescription] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState(false);

  const accountId = params.id as string;

  useEffect(() => {
    const fetchAccountDetails = async () => {
      try {
        // TODO: Replace with actual API call
        // Simulate API call with mock data
        await new Promise(resolve => setTimeout(resolve, 500));
        
        const mockAccount: Account = {
          id: parseInt(accountId),
          accountNumber: accountId === '1' ? '1234567890' : '0987654321',
          accountType: accountId === '1' ? 'CHECKING' : 'SAVINGS',
          balance: accountId === '1' ? 2500.50 : 10000.00,
          currency: 'USD',
          status: 'ACTIVE',
        };
        
        setAccount(mockAccount);
      } catch {
        setError('Failed to load account details');
      } finally {
        setIsLoading(false);
      }
    };

    if (accountId) {
      fetchAccountDetails();
    }
  }, [accountId]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    
    if (!amount || parseFloat(amount) <= 0) {
      setError('Please enter a valid amount');
      return;
    }

    if (!description.trim()) {
      setError('Please enter a description');
      return;
    }

    setIsSubmitting(true);
    setError(null);

    try {
      const response = await TransactionsAPI.createDeposit(
        parseInt(accountId),
        parseFloat(amount),
        description.trim(),
        account?.currency || 'USD'
      );

      if (response.success) {
        setSuccess(true);
        setTimeout(() => {
          router.push(`/accounts/${accountId}`);
        }, 2000);
      } else {
        setError(response.message || 'Failed to process deposit');
      }
    } catch (err) {
      setError('An unexpected error occurred');
      console.error('Deposit error:', err);
    } finally {
      setIsSubmitting(false);
    }
  };

  const formatCurrency = (amount: number, currency: string) => {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: currency,
    }).format(amount);
  };

  if (isLoading) {
    return (
      <ProtectedRoute requireAuth={true}>
        <AuthenticatedLayout>
          <div className="min-h-screen bg-gray-50 flex items-center justify-center">
            <div className="text-center">
              <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600 mx-auto"></div>
              <p className="mt-4 text-gray-600">Loading account details...</p>
            </div>
          </div>
        </AuthenticatedLayout>
      </ProtectedRoute>
    );
  }

  if (error && !account) {
    return (
      <ProtectedRoute requireAuth={true}>
        <AuthenticatedLayout>
          <div className="min-h-screen bg-gray-50 flex items-center justify-center">
            <div className="text-center">
              <div className="w-24 h-24 mx-auto mb-4 text-gray-400">
                <svg fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
              </div>
              <h3 className="text-lg font-medium text-gray-900 mb-2">Account not found</h3>
              <p className="text-gray-600 mb-4">
                The account you&apos;re looking for doesn&apos;t exist or you don&apos;t have permission to view it.
              </p>
              <Link href="/accounts">
                <Button variant="primary">
                  Back to Accounts
                </Button>
              </Link>
            </div>
          </div>
        </AuthenticatedLayout>
      </ProtectedRoute>
    );
  }

  return (
    <ProtectedRoute requireAuth={true}>
      <AuthenticatedLayout>
        <div className="max-w-2xl mx-auto py-6 sm:px-6 lg:px-8">
          <div className="px-4 py-6 sm:px-0">
            {/* Header */}
            <div className="mb-6">
              <div className="flex items-center justify-between">
                <div>
                  <h1 className="text-3xl font-bold text-gray-900">Make a Deposit</h1>
                  <p className="mt-1 text-sm text-gray-600">
                    Deposit funds into your {account?.accountType.toLowerCase()} account
                  </p>
                </div>
                <Link href={`/accounts/${accountId}`}>
                  <Button variant="outline">
                    Back to Account
                  </Button>
                </Link>
              </div>
            </div>

            {/* Account Summary */}
            {account && (
              <div className="bg-white shadow rounded-lg p-6 mb-6">
                <h3 className="text-lg font-medium text-gray-900 mb-4">Account Information</h3>
                <div className="grid grid-cols-2 gap-4">
                  <div>
                    <p className="text-sm font-medium text-gray-600">Account Number</p>
                    <p className="text-lg font-semibold text-gray-900">{account.accountNumber}</p>
                  </div>
                  <div>
                    <p className="text-sm font-medium text-gray-600">Current Balance</p>
                    <p className="text-xl font-bold text-green-600">
                      {formatCurrency(account.balance, account.currency)}
                    </p>
                  </div>
                </div>
              </div>
            )}

            {/* Success Message */}
            {success && (
              <div className="bg-green-50 border border-green-200 rounded-lg p-4 mb-6">
                <div className="flex">
                  <div className="flex-shrink-0">
                    <svg className="h-5 w-5 text-green-400" fill="currentColor" viewBox="0 0 20 20">
                      <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clipRule="evenodd" />
                    </svg>
                  </div>
                  <div className="ml-3">
                    <h3 className="text-sm font-medium text-green-800">
                      Deposit Successful!
                    </h3>
                    <p className="mt-1 text-sm text-green-700">
                      Your deposit has been processed successfully. Redirecting to account details...
                    </p>
                  </div>
                </div>
              </div>
            )}

            {/* Deposit Form */}
            <div className="bg-white shadow rounded-lg">
              <div className="px-6 py-4 border-b border-gray-200">
                <h3 className="text-lg font-medium text-gray-900">Deposit Details</h3>
              </div>
              <form onSubmit={handleSubmit} className="p-6 space-y-6">
                {error && (
                  <div className="bg-red-50 border border-red-200 rounded-lg p-4">
                    <div className="flex">
                      <div className="flex-shrink-0">
                        <svg className="h-5 w-5 text-red-400" fill="currentColor" viewBox="0 0 20 20">
                          <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clipRule="evenodd" />
                        </svg>
                      </div>
                      <div className="ml-3">
                        <p className="text-sm text-red-800">{error}</p>
                      </div>
                    </div>
                  </div>
                )}

                <div>
                  <label htmlFor="amount" className="block text-sm font-medium text-gray-700 mb-2">
                    Amount ({account?.currency || 'USD'})
                  </label>
                  <Input
                    id="amount"
                    type="number"
                    step="0.01"
                    min="0.01"
                    value={amount}
                    onChange={(e) => setAmount(e.target.value)}
                    placeholder="0.00"
                    required
                    className="w-full"
                  />
                  <p className="mt-1 text-sm text-gray-500">
                    Enter the amount you want to deposit
                  </p>
                </div>

                <div>
                  <label htmlFor="description" className="block text-sm font-medium text-gray-700 mb-2">
                    Description
                  </label>
                  <Input
                    id="description"
                    type="text"
                    value={description}
                    onChange={(e) => setDescription(e.target.value)}
                    placeholder="e.g., Salary deposit, Cash deposit"
                    required
                    className="w-full"
                  />
                  <p className="mt-1 text-sm text-gray-500">
                    Brief description of the deposit
                  </p>
                </div>

                <div className="flex justify-end space-x-3 pt-4">
                  <Link href={`/accounts/${accountId}`}>
                    <Button variant="outline" type="button">
                      Cancel
                    </Button>
                  </Link>
                  <Button
                    variant="primary"
                    type="submit"
                    disabled={isSubmitting}
                    className="min-w-[120px]"
                  >
                    {isSubmitting ? (
                      <>
                        <div className="animate-spin rounded-full h-4 w-4 border-b-2 border-white mr-2"></div>
                        Processing...
                      </>
                    ) : (
                      'Process Deposit'
                    )}
                  </Button>
                </div>
              </form>
            </div>
          </div>
        </div>
      </AuthenticatedLayout>
    </ProtectedRoute>
  );
};

export default DepositPage; 