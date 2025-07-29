import axios from 'axios';
import { LoginRequest, RegisterRequest, AuthResponse, User } from '../types/auth';
import { TokenManager } from '../auth/token';

// Use relative URL if NEXT_PUBLIC_API_URL is not set (works with Next.js API proxying)
const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL || '';
const API_TIMEOUT = parseInt(process.env.NEXT_PUBLIC_API_TIMEOUT || '30000');

// Create axios instance for auth API
const authAPI = axios.create({
  baseURL: API_BASE_URL,
  timeout: API_TIMEOUT,
  headers: {
    'Content-Type': 'application/json',
  },
});

// Request interceptor to add auth token
authAPI.interceptors.request.use(
  (config) => {
    const token = TokenManager.getToken();
    if (token) {
      config.headers.Authorization = `Bearer ${token}`;
    }
    return config;
  },
  (error) => {
    return Promise.reject(error);
  },
);

// Response interceptor to handle token expiration
authAPI.interceptors.response.use(
  (response) => {
    return response;
  },
  async (error) => {
    const originalRequest = error.config;

    // If token is expired, remove it and redirect to login
    if (error.response?.status === 401 && !originalRequest._retry) {
      TokenManager.removeToken();
      window.location.href = '/login';
    }

    return Promise.reject(error);
  },
);

export class AuthAPI {
  // User registration
  static async register(userData: RegisterRequest): Promise<AuthResponse> {
    try {
      const response = await authAPI.post('/api/users/register', userData);
      // Handle direct token response from server
      const tokenData = response.data;
      return {
        success: true,
        message: 'Registration successful',
        data: {
          token: tokenData.token,
          type: tokenData.type,
          id: tokenData.id,
          username: tokenData.username,
          email: tokenData.email,
          roles: tokenData.roles,
        }
      };
    } catch (error: unknown) {
      const axiosError = error as { response?: { data?: { message?: string; errors?: string[] } } };
      return {
        success: false,
        message: axiosError.response?.data?.message || 'Registration failed',
        errors: axiosError.response?.data?.errors || ['Registration failed'],
      };
    }
  }

  // User login
  static async login(credentials: LoginRequest): Promise<AuthResponse> {
    try {
      const response = await authAPI.post('/api/users/login', credentials);
      // Handle direct token response from server
      const tokenData = response.data;
      return {
        success: true,
        message: 'Login successful',
        data: {
          token: tokenData.token,
          type: tokenData.type,
          id: tokenData.id,
          username: tokenData.username,
          email: tokenData.email,
          roles: tokenData.roles,
        }
      };
    } catch (error: unknown) {
      const axiosError = error as { response?: { data?: { message?: string; errors?: string[] } } };
      return {
        success: false,
        message: axiosError.response?.data?.message || 'Login failed',
        errors: axiosError.response?.data?.errors || ['Login failed'],
      };
    }
  }

  // Get user profile
  static async getProfile(): Promise<{ success: boolean; data?: User; message?: string }> {
    try {
      const response = await authAPI.get('/api/users/profile');
      return response.data;
    } catch (error: unknown) {
      const axiosError = error as { response?: { data?: { message?: string } } };
      return {
        success: false,
        message: axiosError.response?.data?.message || 'Failed to fetch profile',
      };
    }
  }

  // Check username availability
  static async checkUsername(username: string): Promise<{ available: boolean }> {
    try {
      const response = await authAPI.get(`/api/users/check-username?username=${username}`);
      return response.data;
    } catch {
      return { available: false };
    }
  }

  // Check email availability
  static async checkEmail(email: string): Promise<{ available: boolean }> {
    try {
      const response = await authAPI.get(`/api/users/check-email?email=${email}`);
      return response.data;
    } catch {
      return { available: false };
    }
  }
}