const winston = require('winston');
const config = require('../config');

const logger = winston.createLogger({
  level: config.observability.logging.level,
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    config.observability.logging.format === 'json' 
      ? winston.format.json()
      : winston.format.simple()
  ),
  defaultMeta: { 
    service: config.app.name,
    version: config.app.version
  },
  transports: [
    new winston.transports.Console({
      handleExceptions: true,
      handleRejections: true
    })
  ],
  exitOnError: false
});

module.exports = logger;