# Zero-Code Service Mocking with ProxyMock: Banking API Development Made Simple

**Target Keywords**: proxymock api testing, service virtualization, api mocking tools  
**Estimated Monthly Searches**: 320 + 1,900 + 8,100 = 10,320

## Introduction

Developing microservices often requires mocking dependencies, creating test data, and simulating complex scenarios. ProxyMock eliminates the need for manual mock creation by capturing real API interactions and replaying them instantly. This guide demonstrates how to use ProxyMock for banking API development, from local development to CI/CD integration.

## The Traditional Mocking Problem

### Manual Mock Creation Challenges

**Time-Intensive Setup**: Creating comprehensive mocks for banking APIs takes days
**Maintenance Overhead**: Mocks become outdated as APIs evolve
**Unrealistic Data**: Synthetic test data doesn't reflect production scenarios
**Complex Dependencies**: Banking services have intricate interdependencies

### Example: Banking Transfer Flow Complexity

A simple money transfer involves:
1. User authentication validation
2. Account ownership verification
3. Balance checking with overdraft rules
4. Fraud detection screening
5. Regulatory compliance checks
6. Transaction processing
7. Notification services

Traditional mocking requires recreating all these interactions manually.

## ProxyMock Solution Overview

### How ProxyMock Works

1. **Traffic Interception**: Captures API calls between services
2. **Intelligent Recording**: Stores request/response pairs automatically
3. **Instant Replay**: Replays recorded interactions without configuration
4. **Dynamic Modification**: Adjusts responses for different test scenarios

### Key Benefits

- **Zero Configuration**: No manual mock setup required
- **Production Accuracy**: Uses real API data and behaviors
- **Instant Availability**: Start mocking immediately after recording
- **Flexible Modification**: Customize responses for specific test cases

## Getting Started with ProxyMock

### Installation Options

**VS Code Extension**:
```bash
# Install directly from VS Code marketplace
code --install-extension speedscale.proxymock
```

**CLI Installation**:
```bash
# Install via npm
npm install -g proxymock-cli

# Install via homebrew (macOS)
brew install speedscale/tap/proxymock

# Download binary directly
curl -sSL https://install.speedscale.com/proxymock | bash
```

### Basic Setup for Banking Services

```bash
# Initialize ProxyMock in your banking project
cd banking-microservices
proxymock init

# This creates:
# - .proxymock/ directory for recordings
# - proxymock.config.js for configuration
# - .gitignore entries for sensitive data
```

## Recording Banking API Interactions

### 1. Local Development Recording

Start the banking services and record interactions:

```bash
# Start your banking services
docker-compose up -d

# Start ProxyMock recording
proxymock record \
  --port 8080 \
  --target http://localhost:8081 \
  --name banking-user-service \
  --duration 30m
```

Now route your development traffic through ProxyMock:

```javascript
// Update frontend API base URL to use ProxyMock
const API_BASE_URL = process.env.NODE_ENV === 'development' 
  ? 'http://localhost:8080'  // ProxyMock proxy
  : 'http://localhost:8081'; // Direct service
```

### 2. Multi-Service Recording

Record interactions across all banking services:

```bash
# Record user service interactions
proxymock record --port 8080 --target http://localhost:8081 --tag user-service &

# Record accounts service interactions  
proxymock record --port 8082 --target http://localhost:8082 --tag accounts-service &

# Record transactions service interactions
proxymock record --port 8083 --target http://localhost:8083 --tag transactions-service &

# Use your banking application normally
# ProxyMock captures all API interactions automatically
```

### 3. Scenario-Based Recording

Capture specific banking scenarios:

```bash
# Record authentication flows
proxymock record \
  --name auth-scenarios \
  --filter "path=/users/login OR path=/users/register" \
  --duration 15m

# Use the banking app to perform various auth actions:
# - Valid login
# - Invalid credentials
# - Account lockout
# - Password reset
# All interactions are captured automatically
```

## Configuration and Customization

### ProxyMock Configuration File

```javascript
// proxymock.config.js
module.exports = {
  // Global settings
  port: 8080,
  verbose: true,
  
  // Recording configuration
  recording: {
    sanitization: {
      // Remove sensitive headers
      removeHeaders: [
        'authorization',
        'x-api-key',
        'cookie'
      ],
      
      // Mask sensitive data in request/response bodies
      maskFields: [
        'password',
        'ssn',
        'account_number',
        'credit_card'
      ]
    },
    
    // Filter what to record
    filters: [
      {
        path: '/users/login',
        methods: ['POST'],
        tag: 'authentication'
      },
      {
        path: '/accounts/*/balance',
        methods: ['GET'],
        tag: 'balance-checks'
      },
      {
        path: '/transactions/*',
        methods: ['POST', 'PUT'],
        tag: 'transaction-processing'
      }
    ]
  },
  
  // Replay configuration
  replay: {
    // Add latency to simulate network conditions
    latency: {
      min: 50,
      max: 200
    },
    
    // Introduce occasional errors for resilience testing
    errorRate: 0.02,
    
    // Modify responses for different test scenarios
    modifications: [
      {
        path: '/accounts/*/balance',
        response: {
          // Randomize balance amounts for variety
          transform: (response) => {
            if (response.balance) {
              response.balance = Math.random() * 10000;
            }
            return response;
          }
        }
      }
    ]
  }
};
```

### Environment-Specific Configuration

```javascript
// proxymock.config.js
const baseConfig = {
  // Base configuration
};

const environments = {
  development: {
    ...baseConfig,
    latency: { min: 10, max: 50 },
    errorRate: 0.01,
    verbose: true
  },
  
  testing: {
    ...baseConfig,
    latency: { min: 100, max: 300 },
    errorRate: 0.05,
    chaos: {
      enabled: true,
      scenarios: ['network-timeout', 'service-unavailable']
    }
  },
  
  staging: {
    ...baseConfig,
    latency: { min: 200, max: 500 },
    errorRate: 0.1,
    monitoring: {
      enabled: true,
      metrics: ['response_time', 'error_rate', 'throughput']
    }
  }
};

module.exports = environments[process.env.NODE_ENV || 'development'];
```

## Banking-Specific Use Cases

### 1. User Authentication Flows

Record and replay complex authentication scenarios:

```bash
# Start recording authentication flows
proxymock record --name auth-flows --port 8080

# Perform various authentication actions:
# - Successful login
# - Invalid credentials
# - Account locked
# - Two-factor authentication
# - Password reset request
# - Session timeout

# Stop recording
proxymock stop

# Replay for testing
proxymock replay --name auth-flows --port 3001
```

Test different authentication scenarios:

```javascript
// auth-test.js
const axios = require('axios');

async function testAuthenticationScenarios() {
  const baseURL = 'http://localhost:3001';
  
  // Test successful login - uses recorded response
  const loginResponse = await axios.post(`${baseURL}/users/login`, {
    username: 'john.doe',
    password: 'correct-password'
  });
  console.log('Login successful:', loginResponse.data.token);
  
  // Test invalid credentials - uses recorded error response
  try {
    await axios.post(`${baseURL}/users/login`, {
      username: 'john.doe',
      password: 'wrong-password'
    });
  } catch (error) {
    console.log('Expected error:', error.response.status); // 401
  }
  
  // Test account lockout - uses another recorded scenario
  try {
    await axios.post(`${baseURL}/users/login`, {
      username: 'locked.user',
      password: 'any-password'
    });
  } catch (error) {
    console.log('Account locked:', error.response.status); // 423
  }
}
```

### 2. Account Balance and Transaction Testing

```bash
# Record account operations
proxymock record --name account-ops --filter "path=/accounts/*" --duration 20m

# Perform various account operations:
# - Check balance for different account types
# - Overdraft scenarios
# - Frozen account access
# - Different currency balances
```

Create dynamic balance responses:

```javascript
// proxymock.config.js - Account balance customization
module.exports = {
  replay: {
    modifications: [
      {
        path: '/accounts/:id/balance',
        response: {
          transform: (response, request) => {
            const accountId = request.params.id;
            
            // Simulate different account types
            if (accountId.startsWith('SAV')) {
              response.account_type = 'SAVINGS';
              response.interest_rate = 0.025;
            } else if (accountId.startsWith('CHK')) {
              response.account_type = 'CHECKING';
              response.overdraft_limit = 500;
            }
            
            // Add random balance variation
            response.balance = response.balance + (Math.random() - 0.5) * 100;
            
            return response;
          }
        }
      }
    ]
  }
};
```

### 3. Transaction Processing Scenarios

Record complex transaction flows:

```bash
# Record transaction processing
proxymock record --name transactions \
  --filter "path=/transactions/transfer OR path=/transactions/deposit OR path=/transactions/withdraw" \
  --duration 30m

# Perform various transactions:
# - Successful transfers
# - Insufficient funds
# - Daily limit exceeded
# - International transfers with fees
# - Duplicate transaction prevention
```

Simulate transaction outcomes:

```javascript
// transaction-scenarios.js
const ProxyMock = require('proxymock-sdk');

class TransactionSimulator {
  constructor() {
    this.mock = new ProxyMock({
      recording: 'transactions',
      port: 3002
    });
  }
  
  async simulateTransferScenarios() {
    // Configure different transaction outcomes
    this.mock.addResponseModifier('/transactions/transfer', (request, response) => {
      const amount = request.body.amount;
      
      if (amount > 10000) {
        // Large transfer requires approval
        response.status = 'PENDING_APPROVAL';
        response.approval_required = true;
        response.estimated_approval_time = '2-4 hours';
      } else if (amount > 1000) {
        // Medium transfer with delay
        response.processing_time = '5-10 minutes';
        response.status = 'PROCESSING';
      } else {
        // Small transfer processes immediately
        response.status = 'COMPLETED';
        response.confirmation_number = 'TXN' + Math.random().toString(36).substr(2, 9);
      }
      
      return response;
    });
    
    await this.mock.start();
  }
}
```

## Integration with Development Workflows

### 1. Docker Compose Integration

```yaml
# docker-compose.yml
version: '3.8'
services:
  # Your existing banking services
  user-service:
    build: ./backend/user-service
    ports:
      - "8081:8081"
  
  accounts-service:
    build: ./backend/accounts-service
    ports:
      - "8082:8082"
  
  # ProxyMock service for development
  proxymock:
    image: speedscale/proxymock:latest
    ports:
      - "8080:8080"
    volumes:
      - ./.proxymock:/recordings
      - ./proxymock.config.js:/config/proxymock.config.js
    environment:
      - PROXYMOCK_CONFIG=/config/proxymock.config.js
    command: replay --recordings-dir /recordings --port 8080
```

### 2. Development Scripts

```json
{
  "scripts": {
    "dev": "npm run start:services && npm run start:proxymock",
    "start:services": "docker-compose up -d user-service accounts-service transactions-service",
    "start:proxymock": "proxymock replay --name banking-scenarios --port 8080",
    "record:banking": "proxymock record --name banking-scenarios --multi-service --duration 1h",
    "test:with-mocks": "PROXY_URL=http://localhost:8080 npm run test"
  }
}
```

### 3. VS Code Integration

Create VS Code tasks for ProxyMock operations:

```json
// .vscode/tasks.json
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "Start ProxyMock Recording",
      "type": "shell",
      "command": "proxymock",
      "args": ["record", "--name", "dev-session", "--port", "8080"],
      "group": "build",
      "presentation": {
        "reveal": "always",
        "panel": "new"
      }
    },
    {
      "label": "Start ProxyMock Replay",
      "type": "shell",
      "command": "proxymock",
      "args": ["replay", "--name", "banking-scenarios", "--port", "8080"],
      "group": "build",
      "presentation": {
        "reveal": "always",
        "panel": "new"
      }
    },
    {
      "label": "Stop ProxyMock",
      "type": "shell",
      "command": "proxymock",
      "args": ["stop"],
      "group": "build"
    }
  ]
}
```

## Testing Integration

### 1. Jest Test Integration

```javascript
// __tests__/banking-api.test.js
const ProxyMock = require('proxymock-sdk');
const axios = require('axios');

describe('Banking API Tests with ProxyMock', () => {
  let mockServer;
  
  beforeAll(async () => {
    mockServer = new ProxyMock({
      recording: 'banking-test-scenarios',
      port: 3003
    });
    await mockServer.start();
  });
  
  afterAll(async () => {
    await mockServer.stop();
  });
  
  describe('User Authentication', () => {
    test('successful login returns JWT token', async () => {
      const response = await axios.post('http://localhost:3003/users/login', {
        username: 'test.user',
        password: 'password123'
      });
      
      expect(response.status).toBe(200);
      expect(response.data).toHaveProperty('token');
      expect(response.data.user).toHaveProperty('id');
    });
    
    test('invalid credentials return 401', async () => {
      try {
        await axios.post('http://localhost:3003/users/login', {
          username: 'test.user',
          password: 'wrong-password'
        });
      } catch (error) {
        expect(error.response.status).toBe(401);
        expect(error.response.data.error).toContain('Invalid credentials');
      }
    });
  });
  
  describe('Account Operations', () => {
    test('balance check returns account information', async () => {
      const response = await axios.get('http://localhost:3003/accounts/12345/balance', {
        headers: { Authorization: 'Bearer test-token' }
      });
      
      expect(response.status).toBe(200);
      expect(response.data).toHaveProperty('balance');
      expect(response.data).toHaveProperty('account_type');
    });
  });
  
  describe('Transaction Processing', () => {
    test('valid transfer processes successfully', async () => {
      const transferRequest = {
        from_account: '12345',
        to_account: '67890',
        amount: 100.00,
        currency: 'USD'
      };
      
      const response = await axios.post('http://localhost:3003/transactions/transfer', transferRequest, {
        headers: { Authorization: 'Bearer test-token' }
      });
      
      expect(response.status).toBe(200);
      expect(response.data.status).toBe('COMPLETED');
      expect(response.data).toHaveProperty('confirmation_number');
    });
  });
});
```

### 2. Cypress E2E Integration

```javascript
// cypress/support/commands.js
Cypress.Commands.add('startProxyMock', (recording) => {
  return cy.task('startProxyMock', recording);
});

Cypress.Commands.add('stopProxyMock', () => {
  return cy.task('stopProxyMock');
});

// cypress/plugins/index.js
const ProxyMock = require('proxymock-sdk');

let mockServer;

module.exports = (on, config) => {
  on('task', {
    async startProxyMock(recording) {
      mockServer = new ProxyMock({
        recording,
        port: 8080
      });
      await mockServer.start();
      return null;
    },
    
    async stopProxyMock() {
      if (mockServer) {
        await mockServer.stop();
        mockServer = null;
      }
      return null;
    }
  });
};

// cypress/integration/banking-flow.spec.js
describe('Banking Application E2E', () => {
  beforeEach(() => {
    cy.startProxyMock('banking-full-flow');
  });
  
  afterEach(() => {
    cy.stopProxyMock();
  });
  
  it('completes money transfer successfully', () => {
    cy.visit('http://localhost:3000');
    
    // Login with mocked authentication
    cy.get('[data-cy=username]').type('john.doe');
    cy.get('[data-cy=password]').type('password123');
    cy.get('[data-cy=login-btn]').click();
    
    // Navigate to transfer page
    cy.get('[data-cy=transfer-link]').click();
    
    // Fill transfer form
    cy.get('[data-cy=from-account]').select('Checking - 12345');
    cy.get('[data-cy=to-account]').type('67890');
    cy.get('[data-cy=amount]').type('250.00');
    
    // Submit transfer
    cy.get('[data-cy=submit-transfer]').click();
    
    // Verify success
    cy.get('[data-cy=success-message]')
      .should('contain', 'Transfer completed successfully');
  });
});
```

## CI/CD Pipeline Integration

### 1. GitHub Actions Integration

```yaml
# .github/workflows/api-tests.yml
name: API Tests with ProxyMock
on:
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'
      
      - name: Install ProxyMock
        run: npm install -g proxymock-cli
      
      - name: Start ProxyMock
        run: |
          proxymock replay --name banking-ci-tests --port 8080 --daemon
          sleep 5  # Wait for ProxyMock to start
      
      - name: Run API tests
        env:
          API_BASE_URL: http://localhost:8080
        run: npm test
      
      - name: Stop ProxyMock
        if: always()
        run: proxymock stop
```

### 2. Docker-based CI Integration

```dockerfile
# Dockerfile.test
FROM node:18-alpine

# Install ProxyMock
RUN npm install -g proxymock-cli

# Copy recordings and config
COPY .proxymock /recordings
COPY proxymock.config.js /config/

# Copy test files
COPY package*.json ./
COPY __tests__ ./__tests__

RUN npm install

# Start ProxyMock and run tests
CMD ["sh", "-c", "proxymock replay --recordings-dir /recordings --port 8080 --daemon && npm test"]
```

### 3. Jenkins Pipeline Integration

```groovy
// Jenkinsfile
pipeline {
  agent any
  
  stages {
    stage('Setup') {
      steps {
        sh 'npm install -g proxymock-cli'
      }
    }
    
    stage('Start Mocks') {
      steps {
        sh 'proxymock replay --name banking-test-suite --port 8080 --daemon'
        sleep 5
      }
    }
    
    stage('Run Tests') {
      environment {
        API_BASE_URL = 'http://localhost:8080'
      }
      steps {
        sh 'npm test'
        sh 'npm run test:e2e'
      }
    }
  }
  
  post {
    always {
      sh 'proxymock stop || true'
    }
  }
}
```

## Advanced ProxyMock Features

### 1. Multi-Recording Scenarios

Combine multiple recordings for complex scenarios:

```javascript
// multi-scenario.config.js
module.exports = {
  scenarios: [
    {
      name: 'happy-path',
      recordings: ['user-auth-success', 'account-balance-normal', 'transfer-success'],
      weight: 0.7  // 70% of requests use this scenario
    },
    {
      name: 'error-scenarios',
      recordings: ['user-auth-fail', 'insufficient-funds', 'service-unavailable'],
      weight: 0.2  // 20% of requests use error scenarios
    },
    {
      name: 'edge-cases',
      recordings: ['large-transfers', 'international-transfers', 'concurrent-access'],
      weight: 0.1  // 10% of requests use edge cases
    }
  ]
};
```

### 2. Dynamic Response Generation

Create responses based on request parameters:

```javascript
// dynamic-responses.js
const ProxyMock = require('proxymock-sdk');

const mock = new ProxyMock({
  port: 8080,
  dynamicResponses: true
});

// Generate account balance based on account ID
mock.addDynamicResponse('/accounts/:id/balance', (request) => {
  const accountId = request.params.id;
  const accountType = accountId.startsWith('SAV') ? 'SAVINGS' : 'CHECKING';
  
  return {
    account_id: accountId,
    account_type: accountType,
    balance: Math.random() * 10000,
    currency: 'USD',
    last_updated: new Date().toISOString()
  };
});

// Generate transaction history
mock.addDynamicResponse('/accounts/:id/transactions', (request) => {
  const count = parseInt(request.query.limit) || 10;
  const transactions = [];
  
  for (let i = 0; i < count; i++) {
    transactions.push({
      id: `TXN${Math.random().toString(36).substr(2, 9)}`,
      amount: Math.random() * 1000,
      type: Math.random() > 0.5 ? 'DEBIT' : 'CREDIT',
      timestamp: new Date(Date.now() - i * 86400000).toISOString(),
      description: `Transaction ${i + 1}`
    });
  }
  
  return { transactions };
});

mock.start();
```

### 3. State Management

Maintain state across requests for realistic scenarios:

```javascript
// stateful-mock.js
const ProxyMock = require('proxymock-sdk');

class StatefulBankingMock {
  constructor() {
    this.accounts = new Map();
    this.mock = new ProxyMock({ port: 8080 });
    this.setupHandlers();
  }
  
  setupHandlers() {
    // Get account balance - stateful
    this.mock.addHandler('GET', '/accounts/:id/balance', (request) => {
      const accountId = request.params.id;
      const account = this.accounts.get(accountId) || {
        id: accountId,
        balance: Math.random() * 10000
      };
      
      this.accounts.set(accountId, account);
      return account;
    });
    
    // Process transfer - updates state
    this.mock.addHandler('POST', '/transactions/transfer', (request) => {
      const { from_account, to_account, amount } = request.body;
      
      // Get or create accounts
      const fromAcc = this.accounts.get(from_account) || { id: from_account, balance: 5000 };
      const toAcc = this.accounts.get(to_account) || { id: to_account, balance: 1000 };
      
      // Check sufficient funds
      if (fromAcc.balance < amount) {
        return {
          status: 400,
          body: { error: 'Insufficient funds' }
        };
      }
      
      // Process transfer
      fromAcc.balance -= amount;
      toAcc.balance += amount;
      
      // Update state
      this.accounts.set(from_account, fromAcc);
      this.accounts.set(to_account, toAcc);
      
      return {
        status: 'COMPLETED',
        confirmation_number: `TXN${Math.random().toString(36).substr(2, 9)}`,
        from_balance: fromAcc.balance,
        to_balance: toAcc.balance
      };
    });
  }
  
  async start() {
    await this.mock.start();
    console.log('Stateful banking mock started on port 8080');
  }
}

const bankingMock = new StatefulBankingMock();
bankingMock.start();
```

## Monitoring and Debugging

### 1. Request/Response Logging

```javascript
// logging.config.js
module.exports = {
  logging: {
    enabled: true,
    level: 'debug',
    format: 'json',
    
    // Log all requests and responses
    requests: true,
    responses: true,
    
    // Log performance metrics
    metrics: {
      response_time: true,
      request_size: true,
      response_size: true
    },
    
    // Custom log handlers
    handlers: [
      {
        type: 'console',
        format: 'pretty'
      },
      {
        type: 'file',
        path: './logs/proxymock.log',
        format: 'json'
      }
    ]
  }
};
```

### 2. Performance Monitoring

```javascript
// monitoring.js
const ProxyMock = require('proxymock-sdk');

const mock = new ProxyMock({
  recording: 'banking-scenarios',
  port: 8080,
  monitoring: {
    enabled: true,
    metrics: ['response_time', 'throughput', 'error_rate'],
    dashboard: {
      enabled: true,
      port: 8081  // Dashboard available at http://localhost:8081
    }
  }
});

// Add custom metrics
mock.addMetric('banking_transactions_total', 'counter');
mock.addMetric('banking_transfer_amount', 'histogram');

mock.addRequestMiddleware((request, response) => {
  if (request.path.includes('/transactions/transfer')) {
    mock.incrementMetric('banking_transactions_total');
    mock.recordMetric('banking_transfer_amount', request.body.amount);
  }
});

mock.start();
```

## Best Practices

### 1. Recording Strategy

```yaml
# recording-best-practices.yml
recording_strategy:
  session_based:
    - Record complete user sessions (login → operations → logout)
    - Capture error scenarios naturally occurring
    - Include edge cases and boundary conditions
  
  scenario_focused:
    - Record specific business flows separately
    - Tag recordings by functionality
    - Maintain separate recordings for different test types
  
  data_management:
    - Sanitize sensitive data automatically
    - Use consistent test data across recordings
    - Version control your recordings
```

### 2. Configuration Management

```javascript
// config-management.js
const configs = {
  development: {
    latency: { min: 10, max: 100 },
    errorRate: 0.01,
    verbose: true
  },
  
  testing: {
    latency: { min: 50, max: 200 },
    errorRate: 0.05,
    chaos: { enabled: true }
  },
  
  ci: {
    latency: { min: 0, max: 50 },
    errorRate: 0.02,
    verbose: false,
    timeout: 30000
  }
};

module.exports = configs[process.env.NODE_ENV || 'development'];
```

### 3. Team Collaboration

```bash
# Share recordings with team
proxymock export --name banking-scenarios --output banking-mocks.zip

# Import shared recordings
proxymock import --file banking-mocks.zip

# Version control integration
git add .proxymock/recordings/
git commit -m "Add banking API mock recordings"
```

## Conclusion

ProxyMock transforms API development by eliminating manual mock creation and providing instant access to realistic test scenarios. For banking applications, this means:

1. **Rapid Development**: Start testing immediately without creating mocks
2. **Production Accuracy**: Use real API behaviors and data patterns
3. **Comprehensive Coverage**: Capture edge cases and error scenarios automatically
4. **Zero Maintenance**: No manual updates required as APIs evolve
5. **Team Collaboration**: Share recordings across development teams

### Getting Started Checklist

- [ ] Install ProxyMock CLI or VS Code extension
- [ ] Configure recording settings for your banking services
- [ ] Record your first API interactions
- [ ] Set up replay configuration with modifications
- [ ] Integrate with your testing framework
- [ ] Add ProxyMock to your CI/CD pipeline
- [ ] Share recordings with your team

Ready to eliminate manual mocking from your development workflow? Start with ProxyMock today and experience zero-code service virtualization for your banking microservices.