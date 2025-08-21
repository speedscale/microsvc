# Banking Simulation Client

A Node.js application that continuously simulates realistic user interactions with the banking application. This client generates concurrent user sessions performing typical banking operations like login, account management, and transactions.

## Features

- **Continuous User Simulation**: Generates realistic user traffic patterns
- **Pre-existing User Pool**: 80% of traffic uses seeded simulation users, 20% creates new users
- **Realistic Workflows**: Mimics real user behavior with appropriate delays and actions
- **Configurable Load**: Adjustable concurrent users, session duration, and transaction patterns
- **OpenTelemetry Integration**: Full observability with distributed tracing
- **Kubernetes Ready**: Production-ready container with resource constraints
- **Graceful Shutdown**: Proper signal handling and session cleanup

## Architecture

```
Simulation Client
├── Configuration Management (environment-based)
├── API Client (HTTP with retry logic)
├── User Pool Manager (pre-existing vs new users)
├── Workflow Engine (realistic user behavior)
├── Session Manager (concurrent session handling)
├── Metrics Reporter (OpenTelemetry integration)
└── Health Monitoring (target application checks)
```

## User Behavior Patterns

### Existing Users (80% of traffic)
1. Login with pre-existing credentials
2. Get user profile
3. Check account balances
4. View recent transactions
5. Perform 0-3 random transactions (deposits, withdrawals, transfers)
6. Check balances again
7. Natural session end

### New Users (20% of traffic)
1. Register new account
2. Login with new credentials
3. Get user profile
4. Check accounts (initially empty)
5. Make initial deposit if accounts exist
6. Check updated balance
7. Natural session end

## Quick Start

### Local Development

```bash
# Install dependencies
npm install

# Create environment file
make env-example
cp .env.example .env

# Edit .env with your target URL
TARGET_BASE_URL=http://localhost:3000

# Run in development mode
npm run dev

# Or run in production mode
npm start
```

### Docker

```bash
# Build Docker image
make docker-build

# Run container locally
make docker-run
```

### Kubernetes Deployment

```bash
# Apply database migration first
make migrate-simulation-users

# Deploy entire banking app (including simulation client)
kubectl apply -k ../kubernetes/base/

# Or deploy with local overlay for development
kubectl apply -k ../kubernetes/overlays/local/

# Check status
make k8s-status

# View logs
make k8s-logs

# Scale deployment
make k8s-scale REPLICAS=3
```

## Configuration

The simulation client is configured via environment variables:

### Application Settings
- `NODE_ENV`: Environment (development/production)
- `LOG_LEVEL`: Logging level (debug/info/warn/error)
- `TARGET_BASE_URL`: Banking application URL

### Simulation Settings
- `CONCURRENT_USERS`: Number of concurrent user sessions (default: 10)
- `EXISTING_USER_PERCENTAGE`: Percentage using pre-existing users (default: 80)
- `SESSION_DURATION_MS`: Average session duration (default: 300000ms/5min)
- `MIN_ACTION_DELAY`/`MAX_ACTION_DELAY`: Delays between user actions
- `NEW_USER_DELAY`: Delay between starting new sessions

### Transaction Settings
- `DEPOSIT_PROBABILITY`: Probability of making deposits (default: 0.3)
- `WITHDRAWAL_PROBABILITY`: Probability of withdrawals (default: 0.2)
- `TRANSFER_PROBABILITY`: Probability of transfers (default: 0.1)
- Amount ranges for each transaction type

### User Pool Settings
- `USER_PREFIX`: Prefix for simulation usernames (default: sim_user_)
- `TOTAL_USERS`: Number of pre-seeded users (default: 1000)
- `SIM_USER_PASSWORD`: Password for simulation users

## Database Setup

The simulation requires pre-existing users in the database:

```bash
# Run the database migration
cd ../backend/user-service
./mvnw flyway:migrate

# Or use the Makefile from simulation-client directory
make migrate-simulation-users
```

This creates:
- 1000 simulation users (`sim_user_001` to `sim_user_1000`)
- Realistic account balances ($100 - $50,000)
- Transaction history
- Multiple account types (checking, savings, investment)

## Monitoring & Observability

### OpenTelemetry Integration
- **Distributed Tracing**: Full request tracing through the banking application
- **Custom Metrics**: Session counts, success rates, transaction volumes
- **Structured Logging**: JSON logs with correlation IDs

### Key Metrics
- Active sessions
- Session success/failure rates
- Transaction completion rates
- Average session duration
- Sessions per minute

### Viewing Metrics

```bash
# View live metrics from logs
make metrics

# Check health status
make health

# Detailed deployment status
make k8s-describe
```

## Resource Usage

The simulation client is designed for minimal resource consumption:

- **Memory**: 64-128MB per pod
- **CPU**: 50-200m per pod
- **Startup time**: <10 seconds
- **Graceful shutdown**: <60 seconds

## Scaling

### Horizontal Pod Autoscaler
Automatic scaling based on:
- CPU utilization (target: 70%)
- Memory utilization (target: 80%)
- Min replicas: 1, Max replicas: 5

### Manual Scaling
```bash
# Scale to specific replica count
make k8s-scale REPLICAS=3

# Or use kubectl directly
kubectl scale deployment simulation-client --replicas=5 -n banking-app
```

## Development

### Project Structure
```
src/
├── client/         # HTTP client and API communication
├── config/         # Configuration management
├── models/         # Data models (User, etc.)
├── utils/          # Utilities (logging, tracing)
├── workflows/      # User behavior workflows
└── index.js        # Application entry point
```

### Adding New Workflows
1. Extend `UserWorkflow` class with new methods
2. Update `SimulationManager` to call new workflows
3. Add configuration options for new behavior patterns
4. Update tests and documentation

### Testing
```bash
# Run tests
npm test

# Run linting
npm run lint

# Test Docker build
make docker-build
```

## Troubleshooting

### Common Issues

**Connection Refused**
- Check `TARGET_BASE_URL` configuration
- Verify banking application is running
- Check network connectivity in Kubernetes

**No Simulation Users**
- Run database migration: `make migrate-simulation-users`
- Check user count: `make check-simulation-users`

**High Memory Usage**
- Reduce `CONCURRENT_USERS`
- Increase `SESSION_DURATION_MS` to reduce churn
- Check for memory leaks in logs

**Authentication Failures**
- Verify `SIM_USER_PASSWORD` matches database
- Check simulation user creation in database logs

### Logs Analysis
```bash
# View all logs
make k8s-logs

# Filter for errors
kubectl logs -l app=simulation-client -n banking-app | grep ERROR

# Filter for specific user sessions
kubectl logs -l app=simulation-client -n banking-app | grep "session_"
```

## Production Considerations

- **Load Testing**: Start with low `CONCURRENT_USERS` and gradually increase
- **Database Impact**: Monitor database connections and query performance
- **Network Traffic**: Consider bandwidth usage for high-frequency simulations
- **Rate Limiting**: Respect API rate limits in the target application
- **Resource Monitoring**: Watch CPU/memory usage patterns over time

## Contributing

1. Follow existing code patterns and naming conventions
2. Add appropriate logging for new features
3. Update configuration options in ConfigMap
4. Test locally before deploying to Kubernetes
5. Update documentation for new features