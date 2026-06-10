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
    // Continuously-varying concurrency target for the organic traffic model.
    this.concurrencyLevel = config.simulation.burst.meanConcurrentUsers;
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
      trafficModel: config.simulation.burst.enabled ? 'organic-random-walk' : 'fixed',
      minConcurrency: config.simulation.burst.baseConcurrentUsers,
      meanConcurrency: config.simulation.burst.meanConcurrentUsers,
      maxConcurrency: config.simulation.burst.burstConcurrentUsers,
      targetUrl: config.target.baseUrl
    });

    this.startHealthChecks();
    this.startMetricsReporting();

    if (config.simulation.burst.enabled) {
      this.startTrafficModel();
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

  // Organic traffic model. Instead of toggling between a fixed quiet level and
  // a fixed burst level on a periodic timer (which graphs as a square wave),
  // the concurrency target drifts continuously via a mean-reverting random
  // walk (Ornstein–Uhlenbeck) with occasional random-height spikes. The update
  // cadence is itself jittered, so nothing about the pattern is periodic — it
  // looks like real, noisy production traffic.
  startTrafficModel() {
    const u = config.simulation.burst;

    const step = () => {
      if (!this.isRunning) return;

      // Mean-reverting random walk: pull toward the mean, plus Gaussian noise.
      const drift = u.reversion * (u.meanConcurrentUsers - this.concurrencyLevel);
      const noise = this.gaussian() * u.volatility;
      this.concurrencyLevel += drift + noise;

      // Occasional organic spike of random height (Poisson-like arrival, not
      // on a fixed schedule).
      if (Math.random() < u.spikeChance) {
        this.concurrencyLevel += Math.random() * u.spikeMagnitude;
      }

      // Keep within sane bounds.
      this.concurrencyLevel = Math.min(
        u.burstConcurrentUsers,
        Math.max(u.baseConcurrentUsers, this.concurrencyLevel)
      );

      // Surface a coarse "busy" flag for logs/metrics (not used for control).
      this.burstActive = this.concurrencyLevel >= u.meanConcurrentUsers +
        (u.burstConcurrentUsers - u.meanConcurrentUsers) / 2;

      logger.debug('Traffic level updated', {
        level: Math.round(this.concurrencyLevel),
        busy: this.burstActive
      });

      // Jittered cadence so even the update interval isn't periodic.
      const next = u.updateMs * (1 + (Math.random() - 0.5) * 2 * u.updateJitter);
      setTimeout(step, Math.max(1000, next));
    };

    setTimeout(step, 2000);
  }

  // Standard normal sample via Box–Muller (Math.random is uniform).
  gaussian() {
    let a = 0, b = 0;
    while (a === 0) a = Math.random();
    while (b === 0) b = Math.random();
    return Math.sqrt(-2 * Math.log(a)) * Math.cos(2 * Math.PI * b);
  }

  getCurrentConcurrency() {
    if (!config.simulation.burst.enabled) {
      return config.simulation.concurrentUsers;
    }
    return Math.max(1, Math.round(this.concurrencyLevel));
  }

  getCurrentDelay() {
    if (!config.simulation.burst.enabled) {
      return config.simulation.newUserDelayMs;
    }
    // Session-start delay scales inversely with the current level, so the
    // request rate (not just the concurrency cap) also varies organically.
    const u = config.simulation.burst;
    const frac = (this.concurrencyLevel - u.baseConcurrentUsers) /
      Math.max(1, u.burstConcurrentUsers - u.baseConcurrentUsers); // 0..1
    const fast = Math.max(200, config.simulation.newUserDelayMs / 4);
    const slow = config.simulation.newUserDelayMs * 2;
    return Math.round(slow - frac * (slow - fast));
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
      errorSpikeActive: this.isErrorSpikeActive(),
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

  isErrorSpikeActive() {
    const spike = config.simulation.errorSpike;
    if (!spike.enabled) return false;
    const minute = new Date().getMinutes();
    return spike.minuteMarks.some(m => minute >= m && minute < m + spike.durationMinutes);
  }

  delay(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
  }
}

module.exports = SimulationManager;
