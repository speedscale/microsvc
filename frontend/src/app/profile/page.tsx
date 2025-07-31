'use client';

import React from 'react';
import ProtectedRoute from '@/components/auth/ProtectedRoute';
import AuthenticatedLayout from '@/components/layout/AuthenticatedLayout';
import { useAuth } from '@/lib/auth/context';
import Button from '@/components/ui/Button';

const ProfilePage: React.FC = () => {
  const { user } = useAuth();

  return (
    <ProtectedRoute requireAuth={true}>
      <AuthenticatedLayout>
        <div className="max-w-7xl mx-auto py-6 sm:px-6 lg:px-8">
          <div className="px-4 py-6 sm:px-0">
            <div className="bg-white shadow rounded-lg">
              <div className="px-4 py-5 sm:p-6">
                <h1 className="text-2xl font-bold text-gray-900 mb-6">
                  User Profile
                </h1>
                
                {user && (
                  <div className="space-y-6">
                    <div className="bg-gray-50 rounded-lg p-6">
                      <h2 className="text-lg font-medium text-gray-900 mb-4">
                        Account Information
                      </h2>
                      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                        <div>
                          <label className="block text-sm font-medium text-gray-700">User ID</label>
                          <p className="mt-1 text-sm text-gray-900">{user.id}</p>
                        </div>
                        <div>
                          <label className="block text-sm font-medium text-gray-700">Username</label>
                          <p className="mt-1 text-sm text-gray-900">{user.username}</p>
                        </div>
                        <div>
                          <label className="block text-sm font-medium text-gray-700">Email</label>
                          <p className="mt-1 text-sm text-gray-900">{user.email}</p>
                        </div>
                        <div>
                          <label className="block text-sm font-medium text-gray-700">Roles</label>
                          <p className="mt-1 text-sm text-gray-900">{user.roles}</p>
                        </div>
                        <div>
                          <label className="block text-sm font-medium text-gray-700">Account Created</label>
                          <p className="mt-1 text-sm text-gray-900">
                            {new Date(user.createdAt).toLocaleDateString()}
                          </p>
                        </div>
                        <div>
                          <label className="block text-sm font-medium text-gray-700">Last Updated</label>
                          <p className="mt-1 text-sm text-gray-900">
                            {new Date(user.updatedAt).toLocaleDateString()}
                          </p>
                        </div>
                      </div>
                    </div>

                    <div className="border-t border-gray-200 pt-6">
                      <h3 className="text-lg font-medium text-gray-900 mb-4">
                        Account Actions
                      </h3>
                      <div className="flex space-x-3">
                        <Button variant="outline">
                          Change Password
                        </Button>
                        <Button variant="outline">
                          Update Profile
                        </Button>
                        <Button variant="outline">
                          Security Settings
                        </Button>
                      </div>
                    </div>
                  </div>
                )}
              </div>
            </div>
          </div>
        </div>
      </AuthenticatedLayout>
    </ProtectedRoute>
  );
};

export default ProfilePage; 