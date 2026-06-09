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
    notificationServiceUrl: process.env.NOTIFICATION_SERVICE_URL || 'http://banking-notification:80',
    timeout: parseInt(process.env.REQUEST_TIMEOUT) || 10000
  },

  // Simulation settings
  simulation: {
    // Number of concurrent users (fallback when burst mode is off)
    concurrentUsers: parseInt(process.env.CONCURRENT_USERS) || 10,

    // Percentage of users that are pre-existing (vs new registrations)
    existingUserPercentage: parseInt(process.env.EXISTING_USER_PERCENTAGE) || 80,

    // Session duration in milliseconds
    sessionDurationMs: parseInt(process.env.SESSION_DURATION_MS) || 300000,

    // Delay between user actions (milliseconds)
    actionDelayMs: {
      min: parseInt(process.env.MIN_ACTION_DELAY) || 1000,
      max: parseInt(process.env.MAX_ACTION_DELAY) || 5000
    },

    // Delay between starting new user sessions
    newUserDelayMs: parseInt(process.env.NEW_USER_DELAY) || 2000,

    // Organic traffic model: concurrency follows a mean-reverting random walk
    // (Ornstein–Uhlenbeck) with occasional random-height spikes, instead of a
    // fixed on/off burst. This makes throughput look like real, noisy
    // production traffic rather than a periodic square-wave pulse.
    burst: {
      enabled: (process.env.BURST_ENABLED || 'true') === 'true',
      baseConcurrentUsers: parseInt(process.env.BURST_BASE_USERS) || 2,    // floor
      burstConcurrentUsers: parseInt(process.env.BURST_PEAK_USERS) || 14,  // ceiling
      meanConcurrentUsers: parseInt(process.env.TRAFFIC_MEAN_USERS) || 5,  // level it reverts toward
      reversion: parseFloat(process.env.TRAFFIC_REVERSION) || 0.25,        // pull toward mean (0–1)
      volatility: parseFloat(process.env.TRAFFIC_VOLATILITY) || 2.2,       // random step size per update
      updateMs: parseInt(process.env.TRAFFIC_UPDATE_MS) || 5000,           // how often the level changes
      updateJitter: parseFloat(process.env.TRAFFIC_UPDATE_JITTER) || 0.5,  // ±50% on update cadence
      spikeChance: parseFloat(process.env.TRAFFIC_SPIKE_CHANCE) || 0.07,   // per-update prob of a spike
      spikeMagnitude: parseInt(process.env.TRAFFIC_SPIKE_MAG) || 8         // max extra users on a spike
    },

    // Retry settings
    maxRetries: parseInt(process.env.MAX_RETRIES) || 3,
    retryDelayMs: parseInt(process.env.RETRY_DELAY) || 1000,

    // Error injection: each session has a chance to run one realistic
    // "unhappy path" (bad login, expired token, missing account, overdraw,
    // invalid amount). Because burst mode scales the number of concurrent
    // sessions, the absolute error rate rises and falls *with* throughput —
    // which is what the Banking Health error panel is meant to show.
    errorInjection: {
      enabled: (process.env.ERROR_INJECTION_ENABLED || 'true') === 'true',
      probability: parseFloat(process.env.ERROR_INJECTION_PROBABILITY) || 0.05
    }
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

  // Feature toggles
  features: {
    aiChatEnabled: (process.env.AI_CHAT_ENABLED || 'true') === 'true',
    exportStatementEnabled: (process.env.EXPORT_STATEMENT_ENABLED || 'true') === 'true'
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