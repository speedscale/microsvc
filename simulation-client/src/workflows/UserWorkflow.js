const logger = require('../utils/logger');
const config = require('../config');
const User = require('../models/User');

class UserWorkflow {
  constructor(apiClient) {
    this.apiClient = apiClient;
    this.isRunning = false;
  }

  async executeUserSession(user) {
    try {
      user.startSession();
      logger.info('Starting user session', { user: user.toLogData() });

      if (user.isPreExisting) {
        await this.executeExistingUserWorkflow(user);
      } else {
        await this.executeNewUserWorkflow(user);
      }

      logger.info('Completed user session', { 
        user: user.toLogData(),
        sessionDuration: user.getSessionDuration()
      });

    } catch (error) {
      logger.error('User session failed', {
        user: user.toLogData(),
        error: error.message,
        sessionDuration: user.getSessionDuration()
      });
    }
  }

  async executeExistingUserWorkflow(user) {
    // Step 1: Login
    await this.performLogin(user);
    await this.randomDelay();

    // Step 2: Get user profile
    await this.getUserProfile(user);
    await this.randomDelay();

    // Step 3: Check accounts and balances
    const accounts = await this.getAccountsAndBalances(user);
    await this.randomDelay();

    // Step 4: View recent transactions
    await this.viewRecentTransactions(user);
    await this.randomDelay();

    // Step 5: Perform some transactions (optional)
    if (Math.random() < 0.7) { // 70% chance of making transactions
      await this.performRandomTransactions(user, accounts);
    }

    // Step 6: Check balances again (to see updates)
    await this.getAccountsAndBalances(user);
    await this.randomDelay();

    logger.info('Existing user workflow completed', { user: user.toLogData() });
  }

  async executeNewUserWorkflow(user) {
    // Step 1: Register new user
    await this.performRegistration(user);
    await this.randomDelay();

    // Step 2: Login with new credentials
    await this.performLogin(user);
    await this.randomDelay();

    // Step 3: Get user profile
    await this.getUserProfile(user);
    await this.randomDelay();

    // Step 4: Check accounts (likely empty for new user)
    const accounts = await this.getAccountsAndBalances(user);
    await this.randomDelay();

    // Step 5: Make an initial deposit if accounts exist
    if (accounts && accounts.length > 0) {
      await this.makeInitialDeposit(user, accounts[0]);
      await this.randomDelay();

      // Check balance after deposit
      await this.getAccountsAndBalances(user);
    }

    logger.info('New user workflow completed', { user: user.toLogData() });
  }

  async performRegistration(user) {
    try {
      logger.debug('Registering user', { username: user.username });
      
      const registrationData = {
        username: user.username,
        email: user.email,
        password: user.password
      };

      const response = await this.apiClient.register(registrationData);
      
      if (response && response.id) {
        user.id = response.id;
        logger.info('User registered successfully', { 
          userId: user.id, 
          username: user.username 
        });
      }

      user.updateLastAction();
    } catch (error) {
      logger.error('Registration failed', {
        username: user.username,
        error: error.message,
        status: error.response?.status
      });
      throw error;
    }
  }

  async performLogin(user) {
    try {
      logger.debug('Logging in user', { username: user.username });
      
      const credentials = {
        usernameOrEmail: user.username,
        password: user.password
      };

      const response = await this.apiClient.login(credentials);
      
      if (response && response.token) {
        user.setAuthToken(response.token);
        user.id = response.id;
        logger.info('User logged in successfully', { 
          userId: user.id, 
          username: user.username 
        });
      }

      user.updateLastAction();
    } catch (error) {
      logger.error('Login failed', {
        username: user.username,
        error: error.message,
        status: error.response?.status
      });
      throw error;
    }
  }

  async getUserProfile(user) {
    try {
      logger.debug('Getting user profile', { userId: user.id });
      
      const profile = await this.apiClient.getUserProfile(user.token);
      
      logger.info('Retrieved user profile', {
        userId: user.id,
        username: user.username
      });

      user.updateLastAction();
      return profile;
    } catch (error) {
      logger.error('Failed to get user profile', {
        userId: user.id,
        error: error.message
      });
      throw error;
    }
  }

  async getAccountsAndBalances(user) {
    try {
      logger.debug('Getting accounts and balances', { userId: user.id });
      
      const accounts = await this.apiClient.getAccounts(user.token);
      
      if (accounts && accounts.length > 0) {
        // Get balance for each account
        for (const account of accounts) {
          try {
            const balance = await this.apiClient.getAccountBalance(account.id, user.token);
            account.balance = balance;
          } catch (error) {
            logger.warn('Failed to get account balance', {
              accountId: account.id,
              error: error.message
            });
          }
        }
      }

      user.accounts = accounts || [];
      
      logger.info('Retrieved accounts and balances', {
        userId: user.id,
        accountCount: user.accounts.length,
        totalBalance: user.accounts.reduce((sum, acc) => sum + (acc.balance || 0), 0)
      });

      user.updateLastAction();
      return user.accounts;
    } catch (error) {
      logger.error('Failed to get accounts', {
        userId: user.id,
        error: error.message
      });
      throw error;
    }
  }

  async viewRecentTransactions(user) {
    try {
      logger.debug('Getting recent transactions', { userId: user.id });
      
      const transactions = await this.apiClient.getRecentTransactions(user.token);
      
      logger.info('Retrieved recent transactions', {
        userId: user.id,
        transactionCount: transactions?.length || 0
      });

      user.updateLastAction();
      return transactions;
    } catch (error) {
      logger.error('Failed to get recent transactions', {
        userId: user.id,
        error: error.message
      });
      // Don't throw - this is not critical
    }
  }

  async performRandomTransactions(user, accounts) {
    if (!accounts || accounts.length === 0) {
      logger.debug('No accounts available for transactions', { userId: user.id });
      return;
    }

    const transactionCount = Math.floor(Math.random() * 3) + 1; // 1-3 transactions
    
    for (let i = 0; i < transactionCount; i++) {
      try {
        await this.performRandomTransaction(user, accounts);
        await this.randomDelay();
      } catch (error) {
        logger.warn('Transaction failed, continuing with workflow', {
          userId: user.id,
          error: error.message
        });
      }
    }
  }

  async performRandomTransaction(user, accounts) {
    const account = accounts[Math.floor(Math.random() * accounts.length)];
    const transactionType = this.selectTransactionType();
    
    let transactionData;
    
    switch (transactionType) {
      case 'deposit':
        transactionData = {
          type: 'DEPOSIT',
          amount: this.generateRandomAmount(config.transactions.depositRange),
          accountId: account.id,
          description: 'Simulation deposit'
        };
        break;
        
      case 'withdrawal':
        const maxWithdrawal = Math.min(
          account.balance || 0,
          config.transactions.withdrawalRange.max
        );
        if (maxWithdrawal < config.transactions.withdrawalRange.min) {
          logger.debug('Insufficient funds for withdrawal', { 
            userId: user.id,
            accountBalance: account.balance 
          });
          return;
        }
        
        transactionData = {
          type: 'WITHDRAWAL',
          amount: this.generateRandomAmount({
            min: config.transactions.withdrawalRange.min,
            max: maxWithdrawal
          }),
          accountId: account.id,
          description: 'Simulation withdrawal'
        };
        break;
        
      case 'transfer':
        if (accounts.length < 2) {
          logger.debug('Need at least 2 accounts for transfer', { userId: user.id });
          return;
        }
        
        const toAccount = accounts.find(acc => acc.id !== account.id);
        const maxTransfer = Math.min(
          account.balance || 0,
          config.transactions.transferRange.max
        );
        
        if (maxTransfer < config.transactions.transferRange.min) {
          logger.debug('Insufficient funds for transfer', { 
            userId: user.id,
            accountBalance: account.balance 
          });
          return;
        }
        
        transactionData = {
          type: 'TRANSFER',
          amount: this.generateRandomAmount({
            min: config.transactions.transferRange.min,
            max: maxTransfer
          }),
          fromAccountId: account.id,
          toAccountId: toAccount.id,
          description: 'Simulation transfer'
        };
        break;
        
      default:
        return;
    }

    try {
      const result = await this.apiClient.createTransaction(transactionData, user.token);
      
      logger.info('Transaction completed', {
        userId: user.id,
        transactionType,
        amount: transactionData.amount,
        transactionId: result?.id
      });

      user.updateLastAction();
    } catch (error) {
      logger.error('Transaction failed', {
        userId: user.id,
        transactionType,
        amount: transactionData.amount,
        error: error.message
      });
      throw error;
    }
  }

  async makeInitialDeposit(user, account) {
    const depositAmount = this.generateRandomAmount({
      min: 50,
      max: 500
    });
    
    try {
      const transactionData = {
        type: 'DEPOSIT',
        amount: depositAmount,
        accountId: account.id,
        description: 'Initial deposit for new user'
      };

      const result = await this.apiClient.createTransaction(transactionData, user.token);
      
      logger.info('Initial deposit completed', {
        userId: user.id,
        amount: depositAmount,
        transactionId: result?.id
      });

      user.updateLastAction();
    } catch (error) {
      logger.error('Initial deposit failed', {
        userId: user.id,
        amount: depositAmount,
        error: error.message
      });
      throw error;
    }
  }

  selectTransactionType() {
    const rand = Math.random();
    
    if (rand < config.transactions.depositProbability) {
      return 'deposit';
    } else if (rand < config.transactions.depositProbability + config.transactions.withdrawalProbability) {
      return 'withdrawal';
    } else if (rand < config.transactions.depositProbability + config.transactions.withdrawalProbability + config.transactions.transferProbability) {
      return 'transfer';
    }
    
    return 'deposit'; // Default fallback
  }

  generateRandomAmount(range) {
    return Math.round((Math.random() * (range.max - range.min) + range.min) * 100) / 100;
  }

  async randomDelay() {
    const delay = Math.random() * 
      (config.simulation.actionDelayMs.max - config.simulation.actionDelayMs.min) + 
      config.simulation.actionDelayMs.min;
    
    await new Promise(resolve => setTimeout(resolve, delay));
  }
}

module.exports = UserWorkflow;