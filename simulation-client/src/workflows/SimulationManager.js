const logger = require('../utils/logger');
const config = require('../config');
const User = require('../models/User');
const UserWorkflow = require('./UserWorkflow');

class SimulationManager {
  constructor(apiClient) {
    this.apiClient = apiClient;
    this.userWorkflow = new UserWorkflow(apiClient);
    this.isRunning = false;
    this.activeSessions = new Map();
    this.metrics = {
      totalSessions: 0,
      successfulSessions: 0,
      failedSessions: 0,
      newUserRegistrations: 0,
      existingUserLogins: 0,
      totalTransactions: 0,
      startTime: null
    };
  }

  async start() {
    if (this.isRunning) {
      logger.warn('Simulation is already running');
      return;
    }

    this.isRunning = true;
    this.metrics.startTime = new Date();
    
    logger.info('Starting user simulation', {
      concurrentUsers: config.simulation.concurrentUsers,
      existingUserPercentage: config.simulation.existingUserPercentage,
      targetUrl: config.target.baseUrl
    });

    // Start health check monitoring
    this.startHealthChecks();
    
    // Start metrics reporting
    this.startMetricsReporting();
    
    // Start user session generation
    this.startUserSessionGeneration();
    
    logger.info('User simulation started successfully');
  }

  async stop() {
    if (!this.isRunning) {
      logger.warn('Simulation is not running');
      return;
    }

    this.isRunning = false;
    
    logger.info('Stopping user simulation...');
    
    // Wait for active sessions to complete (with timeout)
    await this.waitForActiveSessions(30000); // 30 second timeout
    
    logger.info('User simulation stopped', {
      finalMetrics: this.getMetrics()
    });
  }

  async startHealthChecks() {
    const healthCheckInterval = 30000; // 30 seconds
    
    const checkHealth = async () => {
      if (!this.isRunning) return;
      
      try {
        await this.apiClient.healthCheck();
        logger.debug('Health check passed');
      } catch (error) {
        logger.error('Health check failed', {
          error: error.message,
          status: error.response?.status
        });
      }
      
      if (this.isRunning) {
        setTimeout(checkHealth, healthCheckInterval);
      }
    };
    
    // Initial health check
    setTimeout(checkHealth, 5000); // Wait 5 seconds before first check
  }

  startMetricsReporting() {
    const reportMetrics = () => {
      if (!this.isRunning) return;
      
      const metrics = this.getMetrics();
      logger.info('Simulation metrics', metrics);
      
      if (this.isRunning) {
        setTimeout(reportMetrics, config.observability.metricsIntervalMs);
      }
    };
    
    setTimeout(reportMetrics, config.observability.metricsIntervalMs);
  }

  async startUserSessionGeneration() {
    while (this.isRunning) {
      try {
        // Check if we're at capacity
        if (this.activeSessions.size >= config.simulation.concurrentUsers) {
          await this.delay(1000); // Wait 1 second before checking again
          continue;
        }

        // Generate new user session
        const user = this.generateUser();
        this.startUserSession(user);
        
        // Wait before starting next user
        await this.delay(config.simulation.newUserDelayMs);
        
      } catch (error) {
        logger.error('Error in user session generation', {
          error: error.message
        });
        await this.delay(5000); // Wait 5 seconds before retrying
      }
    }
  }

  generateUser() {
    const useExistingUser = Math.random() < (config.simulation.existingUserPercentage / 100);
    
    if (useExistingUser) {
      const userNumber = Math.floor(Math.random() * config.userPool.totalUsers) + 1;
      return User.generateSimulationUser(userNumber);
    } else {
      return User.generateNewUser();
    }
  }

  async startUserSession(user) {
    const sessionId = this.generateSessionId();
    this.activeSessions.set(sessionId, user);
    this.metrics.totalSessions++;
    
    if (user.isPreExisting) {
      this.metrics.existingUserLogins++;
    } else {
      this.metrics.newUserRegistrations++;
    }

    logger.debug('Starting user session', {
      sessionId,
      user: user.toLogData(),
      activeSessions: this.activeSessions.size
    });

    // Execute user workflow asynchronously
    this.executeUserSessionAsync(sessionId, user);
  }

  async executeUserSessionAsync(sessionId, user) {
    try {
      await this.userWorkflow.executeUserSession(user);
      this.metrics.successfulSessions++;
      
      logger.debug('User session completed successfully', {
        sessionId,
        user: user.toLogData()
      });
      
    } catch (error) {
      this.metrics.failedSessions++;
      
      logger.error('User session failed', {
        sessionId,
        user: user.toLogData(),
        error: error.message
      });
      
    } finally {
      this.activeSessions.delete(sessionId);
      
      logger.debug('User session ended', {
        sessionId,
        activeSessions: this.activeSessions.size
      });
    }
  }

  async waitForActiveSessions(timeoutMs) {
    const startTime = Date.now();
    
    while (this.activeSessions.size > 0 && (Date.now() - startTime) < timeoutMs) {
      logger.info(`Waiting for ${this.activeSessions.size} active sessions to complete...`);
      await this.delay(1000);
    }
    
    if (this.activeSessions.size > 0) {
      logger.warn(`Timed out waiting for sessions. ${this.activeSessions.size} sessions still active.`);
    } else {
      logger.info('All active sessions completed.');
    }
  }

  generateSessionId() {
    return `session_${Date.now()}_${Math.floor(Math.random() * 10000)}`;
  }

  getMetrics() {
    const runtime = this.metrics.startTime ? Date.now() - this.metrics.startTime.getTime() : 0;
    const runtimeMinutes = Math.floor(runtime / 60000);
    
    return {
      runtime: `${runtimeMinutes} minutes`,
      runtimeMs: runtime,
      activeSessions: this.activeSessions.size,
      totalSessions: this.metrics.totalSessions,
      successfulSessions: this.metrics.successfulSessions,
      failedSessions: this.metrics.failedSessions,
      successRate: this.metrics.totalSessions > 0 
        ? Math.round((this.metrics.successfulSessions / this.metrics.totalSessions) * 100) + '%'
        : '0%',
      newUserRegistrations: this.metrics.newUserRegistrations,
      existingUserLogins: this.metrics.existingUserLogins,
      totalTransactions: this.metrics.totalTransactions,
      sessionsPerMinute: runtimeMinutes > 0 
        ? Math.round(this.metrics.totalSessions / runtimeMinutes)
        : 0
    };
  }

  delay(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
  }
}

module.exports = SimulationManager;