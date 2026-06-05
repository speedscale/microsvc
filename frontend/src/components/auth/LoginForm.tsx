'use client';

import React, { useState } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { useRouter } from 'next/navigation';
import Link from 'next/link';
import { loginSchema, LoginFormData } from '@/lib/utils/validation';
import { useAuth } from '@/lib/auth/context';
import Button from '@/components/ui/Button';
import Input from '@/components/ui/Input';
import ToastContainer, { useToasts } from '@/components/ui/ToastContainer';

const LoginForm: React.FC = () => {
  const router = useRouter();
  const { login } = useAuth();
  const [isSubmitting, setIsSubmitting] = useState(false);
  const { toasts, removeToast, showError } = useToasts();

  const {
    register,
    handleSubmit,
    formState: { errors },
  } = useForm<LoginFormData>({
    resolver: zodResolver(loginSchema),
  });

  const onSubmit = async (data: LoginFormData) => {
    setIsSubmitting(true);
    
    // Clear any existing error toasts when starting a new submission
    toasts.forEach(toast => {
      if (toast.type === 'error') {
        removeToast(toast.id);
      }
    });

    try {
      const response = await login(data);
      
      if (response.success) {
        router.push('/dashboard');
      } else {
        showError(
          'Sign in failed',
          response.message || 'Please check your credentials and try again.'
        );
      }
    } catch {
      showError(
        'Sign in failed',
        'An unexpected error occurred. Please try again.'
      );
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <>
      <ToastContainer toasts={toasts} onRemoveToast={removeToast} />
      
      <div className="min-h-screen flex items-center justify-center bg-gray-50 py-12 px-4 sm:px-6 lg:px-8">
        <div className="max-w-md w-full space-y-8">
          <div>
            <div className="flex justify-center mb-4">
              <div className="w-12 h-12 bg-blue-600 rounded-xl flex items-center justify-center">
                <svg className="w-7 h-7 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" />
                </svg>
              </div>
            </div>
            <h2 className="text-center text-3xl font-extrabold text-gray-900">
              Apex Banking
            </h2>
            <p className="mt-1 text-center text-sm text-gray-500">
              Secure Digital Banking Platform
            </p>
            <p className="mt-4 text-center text-sm text-gray-600">
              Or{' '}
              <Link
                href="/register"
                className="font-medium text-blue-600 hover:text-blue-500"
              >
                create a new account
              </Link>
            </p>
          </div>

          <form className="mt-8 space-y-6" onSubmit={handleSubmit(onSubmit)}>
            <div className="space-y-4">
              <Input
                label="Username or Email"
                type="text"
                autoComplete="username"
                {...register('usernameOrEmail')}
                error={errors.usernameOrEmail?.message}
                placeholder="Enter your username or email"
              />

              <Input
                label="Password"
                type="password"
                autoComplete="current-password"
                {...register('password')}
                error={errors.password?.message}
                placeholder="Enter your password"
              />
            </div>

            <div className="flex items-center justify-between">
              <div className="flex items-center">
                <input
                  id="remember-me"
                  name="remember-me"
                  type="checkbox"
                  className="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded"
                />
                <label htmlFor="remember-me" className="ml-2 block text-sm text-gray-900">
                  Remember me
                </label>
              </div>

              <div className="text-sm">
                <a href="#" className="font-medium text-blue-600 hover:text-blue-500">
                  Forgot your password?
                </a>
              </div>
            </div>

            <Button
              type="submit"
              size="lg"
              isLoading={isSubmitting}
              disabled={isSubmitting}
              className="w-full"
            >
              {isSubmitting ? 'Signing in...' : 'Sign in'}
            </Button>
          </form>

          <div className="mt-4 p-3 bg-gray-100 rounded-md border border-gray-200">
            <p className="text-xs text-gray-500 text-center">
              Demo credentials: <span className="font-mono font-medium text-gray-700">demo_user</span> / <span className="font-mono font-medium text-gray-700">Demo1234!</span>
            </p>
          </div>
        </div>
      </div>
    </>
  );
};

export default LoginForm;