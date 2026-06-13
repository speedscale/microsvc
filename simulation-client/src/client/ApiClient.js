const axios = require('axios');
const logger = require('../utils/logger');
const config = require('../config');

class ApiClient {
  constructor() {
    this.baseURL = config.target.baseUrl;
    this.timeout = config.target.timeout;
    this.maxRetries = config.simulation.maxRetries;
    this.retryDelay = config.simulation.retryDelayMs;
    
    this.client = axios.create({
      baseURL: this.baseURL,
      timeout: this.timeout,
      headers: {
        'Content-Type': 'application/json',
        'User-Agent': 'Banking-Simulation-Client/1.0.0'
      }
    });

    this.setupInterceptors();
  }

  setupInterceptors() {
    // Request interceptor for logging
    this.client.interceptors.request.use(
      (config) => {
        logger.debug('API Request', {
          method: config.method?.toUpperCase(),
          url: config.url,
          headers: config.headers
        });
        return config;
      },
      (error) => {
        logger.error('API Request Error', { error: error.message });
        return Promise.reject(error);
      }
    );

    // Response interceptor for logging and error handling
    this.client.interceptors.response.use(
      (response) => {
        logger.debug('API Response', {
          status: response.status,
          url: response.config.url,
          method: response.config.method?.toUpperCase()
        });
        return response;
      },
      (error) => {
        const errorData = {
          message: error.message,
          status: error.response?.status,
          url: error.config?.url,
          method: error.config?.method?.toUpperCase()
        };
        
        logger.warn('API Response Error', errorData);
        return Promise.reject(error);
      }
    );
  }

  async retryRequest(requestFn, retries = 0) {
    try {
      return await requestFn();
    } catch (error) {
      if (retries < this.maxRetries && this.isRetryableError(error)) {
        logger.info(`Retrying request (${retries + 1}/${this.maxRetries})`, {
          error: error.message,
          status: error.response?.status
        });
        
        await this.delay(this.retryDelay * (retries + 1));
        return this.retryRequest(requestFn, retries + 1);
      }
      throw error;
    }
  }

  isRetryableError(error) {
    if (!error.response) return true; // Network errors
    
    const status = error.response.status;
    return status >= 500 || status === 429; // Server errors or rate limiting
  }

  delay(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
  }

  // Authentication endpoints
  async register(userData) {
    return this.retryRequest(async () => {
      const response = await this.client.post('/api/users/register', userData);
      return response.data;
    });
  }

  async login(credentials) {
    return this.retryRequest(async () => {
      const response = await this.client.post('/api/users/login', credentials);
      return response.data;
    });
  }

  async getUserProfile(token) {
    return this.retryRequest(async () => {
      const response = await this.client.get('/api/users/profile', {
        headers: { Authorization: `Bearer ${token}` }
      });
      return response.data;
    });
  }

  // Account endpoints
  async getAccounts(token) {
    return this.retryRequest(async () => {
      const response = await this.client.get('/api/accounts', {
        headers: { Authorization: `Bearer ${token}` }
      });
      return response.data;
    });
  }

  async createAccount(accountData, token) {
    return this.retryRequest(async () => {
      const response = await this.client.post('/api/accounts', accountData, {
        headers: { Authorization: `Bearer ${token}` }
      });
      return response.data;
    });
  }

  async getAccountById(accountId, token) {
    return this.retryRequest(async () => {
      const response = await this.client.get(`/api/accounts/${accountId}`, {
        headers: { Authorization: `Bearer ${token}` }
      });
      return response.data;
    });
  }

  async getAccountBalance(accountId, token) {
    return this.retryRequest(async () => {
      const response = await this.client.get(`/api/accounts/${accountId}/balance`, {
        headers: { Authorization: `Bearer ${token}` }
      });
      return response.data;
    });
  }

  async getAccountTransactions(accountId, token) {
    // Per-account history is served by transactions-service at GET /api/transactions?accountId=.
    // There is no /api/accounts/{id}/transactions route, so the old path 404'd -> stateless
    // Spring Security re-dispatches to /error unauthenticated -> 401.
    return this.retryRequest(async () => {
      const response = await this.client.get('/api/transactions', {
        params: { accountId },
        headers: { Authorization: `Bearer ${token}` }
      });
      return response.data;
    });
  }

  // Transaction endpoints
  async createTransaction(transactionData, token) {
    const payload = { currency: 'USD', ...transactionData };
    return this.retryRequest(async () => {
      const response = await this.client.post('/api/transactions/create', payload, {
        headers: { Authorization: `Bearer ${token}` }
      });
      return response.data;
    });
  }

  async getRecentTransactions(token) {
    return this.retryRequest(async () => {
      // The service lists transactions at GET /api/transactions (no /recent).
      const response = await this.client.get('/api/transactions', {
        headers: { Authorization: `Bearer ${token}` }
      });
      return response.data;
    });
  }

  async getTransaction(transactionId, token) {
    // No GET /{id} endpoint on transactions-service; use the list endpoint
    // and filter client-side. Return null if not found.
    return this.retryRequest(async () => {
      const response = await this.client.get('/api/transactions', {
        headers: { Authorization: `Bearer ${token}` }
      });
      const txns = Array.isArray(response.data) ? response.data : response.data?.content || [];
      return txns.find(t => t.id === transactionId) || null;
    });
  }

  async deposit(transactionData, token) {
    const payload = { currency: 'USD', ...transactionData };
    return this.retryRequest(async () => {
      const response = await this.client.post('/api/transactions/deposit', payload, {
        headers: { Authorization: `Bearer ${token}` }
      });
      return response.data;
    });
  }

  async withdraw(transactionData, token) {
    const payload = { currency: 'USD', ...transactionData };
    return this.retryRequest(async () => {
      const response = await this.client.post('/api/transactions/withdraw', payload, {
        headers: { Authorization: `Bearer ${token}` }
      });
      return response.data;
    });
  }

  async transfer(transactionData, token) {
    const payload = { currency: 'USD', ...transactionData };
    return this.retryRequest(async () => {
      const response = await this.client.post('/api/transactions/transfer', payload, {
        headers: { Authorization: `Bearer ${token}` }
      });
      return response.data;
    });
  }

  async checkUsername(username) {
    return this.retryRequest(async () => {
      const response = await this.client.get('/api/users/check-username', {
        params: { username }
      });
      return response.data;
    });
  }

  async checkEmail(email) {
    return this.retryRequest(async () => {
      const response = await this.client.get('/api/users/check-email', {
        params: { email }
      });
      return response.data;
    });
  }

  async exportStatement(accountId, token) {
    return this.retryRequest(async () => {
      const response = await this.client.post(`/api/accounts/${accountId}/export-statement`, {}, {
        headers: { Authorization: `Bearer ${token}` }
      });
      return response.data;
    });
  }

  async askAIChat(message, token) {
    return this.retryRequest(async () => {
      const response = await this.client.post('/api/ai/chat', { message }, {
        headers: { Authorization: `Bearer ${token}` }
      });
      return response.data;
    });
  }

  // Notification service endpoints
  async getNotifications(userId) {
    return this.retryRequest(async () => {
      const response = await axios.get(`${config.target.notificationServiceUrl}/notifications/${userId}`, {
        timeout: this.timeout,
        headers: { 'User-Agent': 'Banking-Simulation-Client/1.0.0' }
      });
      return response.data;
    });
  }

  // Raw request without retry — used for error injection so 5xx responses
  // are not amplified by the retry loop.
  async rawRequest(method, path, data, token) {
    const headers = { 'Content-Type': 'application/json' };
    if (token) headers.Authorization = `Bearer ${token}`;
    return this.client.request({ method, url: path, data, headers });
  }

  // Health check
  async healthCheck() {
    return this.retryRequest(async () => {
      const response = await this.client.get('/api/healthz');
      return response.data;
    });
  }
}

module.exports = ApiClient;