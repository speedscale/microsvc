#!/usr/bin/env node

// Initialize tracing first, before any other imports
const { initializeTracing, shutdownTracing } = require('./utils/tracing');
initializeTracing();

const logger = require('./utils/logger');
const config = require('./config');
const ApiClient = require('./client/ApiClient');
const SimulationManager = require('./workflows/SimulationManager');

class SimulationClient {
  constructor() {
    this.apiClient = new ApiClient();
    this.simulationManager = new SimulationManager(this.apiClient);
    this.isShuttingDown = false;
  }

  async start() {
    try {
      logger.info('Starting Banking Simulation Client', {
        version: config.app.version,
        environment: config.app.environment,
        targetUrl: config.target.baseUrl,
        config: {
          concurrentUsers: config.simulation.concurrentUsers,
          existingUserPercentage: config.simulation.existingUserPercentage,
          sessionDurationMs: config.simulation.sessionDurationMs
        }
      });

      // Perform initial health check
      await this.performInitialHealthCheck();

      // Setup graceful shutdown handlers
      this.setupShutdownHandlers();

      // Start the simulation
      await this.simulationManager.start();

      logger.info('Simulation client started successfully');

    } catch (error) {
      logger.error('Failed to start simulation client', {
        error: error.message,
        stack: error.stack
      });
      process.exit(1);
    }
  }

  async performInitialHealthCheck() {
    logger.info('Performing initial health check...');
    
    const maxRetries = 5;
    let retries = 0;
    
    while (retries < maxRetries) {
      try {
        await this.apiClient.healthCheck();
        logger.info('Health check passed - target application is accessible');
        return;
      } catch (error) {
        retries++;
        logger.warn(`Health check failed (${retries}/${maxRetries})`, {
          error: error.message,
          status: error.response?.status,
          targetUrl: config.target.baseUrl
        });
        
        if (retries >= maxRetries) {
          throw new Error(`Target application is not accessible after ${maxRetries} attempts: ${error.message}`);
        }
        
        // Wait before retrying
        await new Promise(resolve => setTimeout(resolve, 5000));
      }
    }
  }

  setupShutdownHandlers() {
    const shutdown = async (signal) => {
      if (this.isShuttingDown) {
        logger.warn('Shutdown already in progress, forcing exit...');
        process.exit(1);
        return;
      }

      this.isShuttingDown = true;
      logger.info(`Received ${signal}, shutting down gracefully...`);

      try {
        // Stop the simulation manager
        await this.simulationManager.stop();
        
        // Shutdown tracing
        await shutdownTracing();
        
        logger.info('Graceful shutdown completed');
        process.exit(0);
      } catch (error) {
        logger.error('Error during shutdown', {
          error: error.message
        });
        process.exit(1);
      }
    };

    // Handle various shutdown signals
    process.on('SIGTERM', () => shutdown('SIGTERM'));
    process.on('SIGINT', () => shutdown('SIGINT'));
    process.on('SIGUSR2', () => shutdown('SIGUSR2')); // nodemon restart signal

    // Handle uncaught exceptions
    process.on('uncaughtException', (error) => {
      logger.error('Uncaught exception', {
        error: error.message,
        stack: error.stack
      });
      process.exit(1);
    });

    process.on('unhandledRejection', (reason, promise) => {
      logger.error('Unhandled rejection', {
        reason: reason?.toString(),
        promise: promise?.toString()
      });
      process.exit(1);
    });
  }
}

// Start the simulation client
if (require.main === module) {
  const client = new SimulationClient();
  client.start().catch((error) => {
    logger.error('Failed to start simulation client', {
      error: error.message,
      stack: error.stack
    });
    process.exit(1);
  });
}

module.exports = SimulationClient;