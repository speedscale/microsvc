import axios, { AxiosInstance, AxiosRequestConfig, AxiosResponse } from 'axios';
import { TokenManager } from '../auth/token';
import { logApiRequest, logApiResponse, logError } from '../logger';

// Trace propagation utilities
const generateTraceId = (): string => {
  return Array.from({ length: 32 }, () => Math.floor(Math.random() * 16).toString(16)).join('');
};

const generateSpanId = (): string => {
  return Array.from({ length: 16 }, () => Math.floor(Math.random() * 16).toString(16)).join('');
};

const createTraceParent = (): string => {
  const traceId = generateTraceId();
  const spanId = generateSpanId();
  return `00-${traceId}-${spanId}-01`;
};

// Always use relative URLs - Next.js will handle API routing
const API_BASE_URL = '';
const API_TIMEOUT = 30000;

export interface ApiResponse<T = unknown> {
  success: boolean;
  data?: T;
  message?: string;
  errors?: string[];
}

export interface PaginatedResponse<T> {
  content: T[];
  pageable: {
    sort: {
      empty: boolean;
      sorted: boolean;
      unsorted: boolean;
    };
    offset: number;
    pageSize: number;
    pageNumber: number;
    paged: boolean;
    unpaged: boolean;
  };
  last: boolean;
  totalPages: number;
  totalElements: number;
  size: number;
  number: number;
  sort: {
    empty: boolean;
    sorted: boolean;
    unsorted: boolean;
  };
  first: boolean;
  numberOfElements: number;
  empty: boolean;
}

class ApiClient {
  private axiosInstance: AxiosInstance;

  constructor() {
    this.axiosInstance = axios.create({
      baseURL: API_BASE_URL,
      timeout: API_TIMEOUT,
      headers: {
        'Content-Type': 'application/json',
      },
    });

    this.setupInterceptors();
  }

  private setupInterceptors(): void {
    // Request interceptor to add auth token and trace headers
    this.axiosInstance.interceptors.request.use(
      (config) => {
        const token = TokenManager.getToken();
        if (token) {
          config.headers.Authorization = `Bearer ${token}`;
        }
        
        // Add trace context header for distributed tracing
        if (typeof window !== 'undefined') {
          config.headers['traceparent'] = createTraceParent();
        }
        
        return config;
      },
      (error) => {
        return Promise.reject(error);
      }
    );

    // Response interceptor to handle common errors
    this.axiosInstance.interceptors.response.use(
      (response) => {
        return response;
      },
      async (error) => {
        const originalRequest = error.config;

        // Handle 401 Unauthorized responses
        if (error.response?.status === 401 && !originalRequest._retry) {
          originalRequest._retry = true;
          
          // Remove expired token
          TokenManager.removeToken();
          
          // Redirect to login page
          if (typeof window !== 'undefined') {
            window.location.href = '/login';
          }
          
          return Promise.reject(error);
        }

        // Handle network errors
        if (!error.response) {
          const networkError = {
            ...error,
            message: 'Network error. Please check your connection.',
          };
          return Promise.reject(networkError);
        }

        return Promise.reject(error);
      }
    );
  }

  // Generic GET request
  async get<T>(url: string, config?: AxiosRequestConfig): Promise<ApiResponse<T>> {
    const startTime = Date.now();
    try {
      logApiRequest('GET', url);
      const response: AxiosResponse<T> = await this.axiosInstance.get(url, config);
      const duration = Date.now() - startTime;
      logApiResponse('GET', url, response.status, duration);
      return {
        success: true,
        data: response.data,
      };
    } catch (error: unknown) {
      const duration = Date.now() - startTime;
      logError(error as Error, { method: 'GET', url, duration });
      return this.handleError(error);
    }
  }

  // Generic POST request
  async post<T>(url: string, data?: unknown, config?: AxiosRequestConfig): Promise<ApiResponse<T>> {
    const startTime = Date.now();
    try {
      logApiRequest('POST', url);
      const response: AxiosResponse<T> = await this.axiosInstance.post(url, data, config);
      const duration = Date.now() - startTime;
      logApiResponse('POST', url, response.status, duration);
      return {
        success: true,
        data: response.data,
      };
    } catch (error: unknown) {
      const duration = Date.now() - startTime;
      logError(error as Error, { method: 'POST', url, duration });
      return this.handleError(error);
    }
  }

  // Generic PUT request
  async put<T>(url: string, data?: unknown, config?: AxiosRequestConfig): Promise<ApiResponse<T>> {
    try {
      console.log(`[API] PUT ${url}`, data ? 'with data' : 'without data');
      const response: AxiosResponse<T> = await this.axiosInstance.put(url, data, config);
      console.log(`[API] PUT ${url} - Success (${response.status})`);
      return {
        success: true,
        data: response.data,
      };
    } catch (error: unknown) {
      console.error(`[API] PUT ${url} - Error:`, error);
      return this.handleError(error);
    }
  }

  // Generic DELETE request
  async delete<T>(url: string, config?: AxiosRequestConfig): Promise<ApiResponse<T>> {
    try {
      console.log(`[API] DELETE ${url}`);
      const response: AxiosResponse<T> = await this.axiosInstance.delete(url, config);
      console.log(`[API] DELETE ${url} - Success (${response.status})`);
      return {
        success: true,
        data: response.data,
      };
    } catch (error: unknown) {
      console.error(`[API] DELETE ${url} - Error:`, error);
      return this.handleError(error);
    }
  }

  // Generic PATCH request
  async patch<T>(url: string, data?: unknown, config?: AxiosRequestConfig): Promise<ApiResponse<T>> {
    try {
      console.log(`[API] PATCH ${url}`, data ? 'with data' : 'without data');
      const response: AxiosResponse<T> = await this.axiosInstance.patch(url, data, config);
      console.log(`[API] PATCH ${url} - Success (${response.status})`);
      return {
        success: true,
        data: response.data,
      };
    } catch (error: unknown) {
      console.error(`[API] PATCH ${url} - Error:`, error);
      return this.handleError(error);
    }
  }

  // Handle API errors consistently
  private handleError<T>(error: unknown): ApiResponse<T> {
    const axiosError = error as {
      response?: {
        data?: {
          message?: string;
          errors?: string[];
          error?: string;
        };
        status?: number;
      };
      message?: string;
      code?: string;
    };

    // Handle timeout errors
    if (axiosError.code === 'ECONNABORTED') {
      return {
        success: false,
        message: 'Request timeout. Please try again.',
        errors: ['Request timeout'],
      };
    }

    // Handle network errors
    if (!axiosError.response) {
      return {
        success: false,
        message: axiosError.message || 'Network error. Please check your connection.',
        errors: [axiosError.message || 'Network error'],
      };
    }

    // Handle HTTP errors
    const { data, status } = axiosError.response;
    
    let message = 'An error occurred';
    let errors: string[] = [];

    if (data) {
      message = data.message || data.error || message;
      errors = data.errors || [message];
    }

    // Handle specific status codes
    switch (status) {
      case 400:
        message = message || 'Bad request. Please check your input.';
        break;
      case 401:
        message = message || 'Unauthorized. Please log in again.';
        break;
      case 403:
        message = message || 'Forbidden. You do not have permission to perform this action.';
        break;
      case 404:
        message = message || 'Not found. The requested resource does not exist.';
        break;
      case 409:
        message = message || 'Conflict. The request could not be completed due to a conflict.';
        break;
      case 422:
        message = message || 'Validation error. Please check your input.';
        break;
      case 500:
        message = message || 'Internal server error. Please try again later.';
        break;
      case 503:
        message = message || 'Service unavailable. Please try again later.';
        break;
      default:
        message = message || `Request failed with status ${status}`;
    }

    return {
      success: false,
      message,
      errors,
    };
  }

  // Get axios instance for custom requests
  getAxiosInstance(): AxiosInstance {
    return this.axiosInstance;
  }

  // Update base URL (useful for different environments)
  updateBaseURL(newBaseURL: string): void {
    this.axiosInstance.defaults.baseURL = newBaseURL;
  }

  // Update timeout
  updateTimeout(newTimeout: number): void {
    this.axiosInstance.defaults.timeout = newTimeout;
  }

  // Add custom headers
  setHeader(key: string, value: string): void {
    this.axiosInstance.defaults.headers.common[key] = value;
  }

  // Remove custom headers
  removeHeader(key: string): void {
    delete this.axiosInstance.defaults.headers.common[key];
  }
}

// Create singleton instance
export const apiClient = new ApiClient();
export default apiClient;