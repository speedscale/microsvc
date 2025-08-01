interface LogEntry {
  timestamp: string;
  level: string;
  service: string;
  message: string;
  [key: string]: unknown;
}

const createLogEntry = (level: string, message: string, metadata: Record<string, unknown> = {}): LogEntry => {
  return {
    timestamp: new Date().toISOString(),
    level,
    service: 'frontend',
    message,
    ...metadata
  };
};

const log = (entry: LogEntry) => {
  // Output as structured JSON that will appear in pod logs
  console.log(JSON.stringify(entry));
};

// Helper functions for structured logging  
export const logApiRequest = (method: string, url: string, userAgent?: string, ip?: string) => {
  log(createLogEntry('info', 'API Request', {
    type: 'api_request',
    method,
    url,
    userAgent,
    ip
  }));
};

export const logApiResponse = (method: string, url: string, statusCode: number, duration?: number) => {
  log(createLogEntry('info', 'API Response', {
    type: 'api_response',
    method,
    url,
    statusCode,
    duration
  }));
};

export const logError = (error: Error, context?: Record<string, unknown>) => {
  log(createLogEntry('error', 'Application Error', {
    type: 'error',
    message: error.message,
    stack: error.stack,
    context
  }));
};

export const logTransaction = (type: 'deposit' | 'withdrawal' | 'transfer', accountId: number, amount: number, success: boolean) => {
  log(createLogEntry('info', 'Transaction Event', {
    type: 'transaction',
    transactionType: type,
    accountId,
    amount,
    success
  }));
};

export const logInfo = (message: string, metadata?: Record<string, unknown>) => {
  log(createLogEntry('info', message, metadata));
};

export const logWarn = (message: string, metadata?: Record<string, unknown>) => {
  log(createLogEntry('warn', message, metadata));
};