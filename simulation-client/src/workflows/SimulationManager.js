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
    this.burstActive = false;
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
      burstMode: config.simulation.burst.enabled,
      baseConcurrency: config.simulation.burst.baseConcurrentUsers,
      burstConcurrency: config.simulation.burst.burstConcurrentUsers,
      burstInterval: `${config.simulation.burst.intervalMs / 1000}s`,
      burstDuration: `${config.simulation.burst.durationMs / 1000}s`,
      targetUrl: config.target.baseUrl
    });

    this.startHealthChecks();
    this.startMetricsReporting();

    if (config.simulation.burst.enabled) {
      this.startBurstCycle();
    }

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
    await this.waitForActiveSessions(30000);

    logger.info('User simulation stopped', {
      finalMetrics: this.getMetrics()
    });
  }

  // Burst cycle: alternate between quiet periods and traffic spikes.
  // Adds jitter so bursts don't land on exact clock boundaries.
  startBurstCycle() {
    const scheduleBurst = () => {
      if (!this.isRunning) return;

      const jitter = (Math.random() - 0.5) * config.simulation.burst.intervalJitterMs * 2;
      const nextBurstIn = config.simulation.burst.intervalMs + jitter;

      setTimeout(async () => {
        if (!this.isRunning) return;

        const durationJitter = (Math.random() - 0.5) * config.simulation.burst.durationMs * 0.4;
        const burstDuration = config.simulation.burst.durationMs + durationJitter;

        this.burstActive = true;
        logger.info('Burst started', {
          concurrency: config.simulation.burst.burstConcurrentUsers,
          plannedDuration: `${Math.round(burstDuration / 1000)}s`
        });

        setTimeout(() => {
          this.burstActive = false;
          logger.info('Burst ended, returning to base traffic');
          scheduleBurst();
        }, burstDuration);

      }, nextBurstIn);
    };

    // First burst after a shorter initial wait (30-90s) so the demo isn't boring
    const initialDelay = 30000 + Math.random() * 60000;
    setTimeout(() => {
      if (!this.isRunning) return;
      this.burstActive = true;
      logger.info('Initial burst started');

      const dur = config.simulation.burst.durationMs * (0.5 + Math.random() * 0.5);
      setTimeout(() => {
        this.burstActive = false;
        logger.info('Initial burst ended');
        scheduleBurst();
      }, dur);
    }, initialDelay);
  }

  getCurrentConcurrency() {
    if (!config.simulation.burst.enabled) {
      return config.simulation.concurrentUsers;
    }
    return this.burstActive
      ? config.simulation.burst.burstConcurrentUsers
      : config.simulation.burst.baseConcurrentUsers;
  }

  getCurrentDelay() {
    if (!config.simulation.burst.enabled) {
      return config.simulation.newUserDelayMs;
    }
    // During bursts: faster session starts. During quiet: slower.
    return this.burstActive
      ? Math.max(200, config.simulation.newUserDelayMs / 4)
      : config.simulation.newUserDelayMs * 2;
  }

  async startHealthChecks() {
    const healthCheckInterval = 30000;

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

    setTimeout(checkHealth, 5000);
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
        const maxConcurrency = this.getCurrentConcurrency();

        if (this.activeSessions.size >= maxConcurrency) {
          await this.delay(1000);
          continue;
        }

        const user = this.generateUser();
        this.startUserSession(user);

        await this.delay(this.getCurrentDelay());

      } catch (error) {
        logger.error('Error in user session generation', {
          error: error.message
        });
        await this.delay(5000);
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
      activeSessions: this.activeSessions.size,
      burstActive: this.burstActive
    });

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
      burstActive: this.burstActive,
      currentConcurrency: this.getCurrentConcurrency(),
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
