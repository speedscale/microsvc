require('dotenv').config();

const config = {
  // Application settings
  app: {
    name: 'banking-simulation-client',
    version: '1.0.0',
    environment: process.env.NODE_ENV || 'development'
  },

  // Target application settings
  target: {
    baseUrl: process.env.TARGET_BASE_URL || 'http://frontend:3000',
    timeout: parseInt(process.env.REQUEST_TIMEOUT) || 10000
  },

  // Simulation settings
  simulation: {
    // Number of concurrent users to simulate
    concurrentUsers: parseInt(process.env.CONCURRENT_USERS) || 10,
    
    // Percentage of users that are pre-existing (vs new registrations)
    existingUserPercentage: parseInt(process.env.EXISTING_USER_PERCENTAGE) || 80,
    
    // Session duration in milliseconds
    sessionDurationMs: parseInt(process.env.SESSION_DURATION_MS) || 300000, // 5 minutes
    
    // Delay between user actions (milliseconds)
    actionDelayMs: {
      min: parseInt(process.env.MIN_ACTION_DELAY) || 1000,   // 1 second
      max: parseInt(process.env.MAX_ACTION_DELAY) || 5000    // 5 seconds
    },
    
    // Delay between starting new user sessions
    newUserDelayMs: parseInt(process.env.NEW_USER_DELAY) || 2000, // 2 seconds
    
    // Retry settings
    maxRetries: parseInt(process.env.MAX_RETRIES) || 3,
    retryDelayMs: parseInt(process.env.RETRY_DELAY) || 1000
  },

  // Pre-existing user pool
  userPool: {
    // Pattern for pre-existing usernames
    usernamePrefix: process.env.USER_PREFIX || 'sim_user_',
    
    // Total number of pre-existing users in database
    totalUsers: parseInt(process.env.TOTAL_USERS) || 1000,
    
    // Common password for simulation users
    password: process.env.SIM_USER_PASSWORD || 'SimUser123!'
  },

  // Transaction simulation settings
  transactions: {
    // Probability of different transaction types
    depositProbability: parseFloat(process.env.DEPOSIT_PROBABILITY) || 0.3,
    withdrawalProbability: parseFloat(process.env.WITHDRAWAL_PROBABILITY) || 0.2,
    transferProbability: parseFloat(process.env.TRANSFER_PROBABILITY) || 0.1,
    
    // Transaction amount ranges
    depositRange: {
      min: parseFloat(process.env.MIN_DEPOSIT) || 10.00,
      max: parseFloat(process.env.MAX_DEPOSIT) || 1000.00
    },
    withdrawalRange: {
      min: parseFloat(process.env.MIN_WITHDRAWAL) || 5.00,
      max: parseFloat(process.env.MAX_WITHDRAWAL) || 500.00
    },
    transferRange: {
      min: parseFloat(process.env.MIN_TRANSFER) || 10.00,
      max: parseFloat(process.env.MAX_TRANSFER) || 250.00
    }
  },

  // Observability settings
  observability: {
    // OpenTelemetry settings
    otel: {
      serviceName: process.env.OTEL_SERVICE_NAME || 'simulation-client',
      endpoint: process.env.OTEL_EXPORTER_OTLP_ENDPOINT || 'http://jaeger:4317',
      protocol: process.env.OTEL_EXPORTER_OTLP_PROTOCOL || 'grpc'
    },
    
    // Logging settings
    logging: {
      level: process.env.LOG_LEVEL || 'info',
      format: process.env.LOG_FORMAT || 'json'
    },
    
    // Metrics reporting interval
    metricsIntervalMs: parseInt(process.env.METRICS_INTERVAL) || 30000 // 30 seconds
  }
};

module.exports = config;