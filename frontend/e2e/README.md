# End-to-End Testing Guide

This directory contains end-to-end tests for the banking application frontend using Playwright.

## Test Types

### 1. Mocked Tests (`auth-flow.spec.ts`)
These tests use API mocking to test the frontend in isolation without requiring backend services.

**Pros:**
- Fast execution
- No external dependencies
- Predictable results
- Good for CI/CD

**Cons:**
- Doesn't test real API integration
- May miss backend-specific issues

### 2. Real Backend Tests (`real-backend.spec.ts`)
These tests work with the actual backend services to test the complete integration.

**Pros:**
- Tests real API integration
- Catches backend-specific issues
- More realistic test scenarios

**Cons:**
- Slower execution
- Requires backend services to be running
- More complex setup

## Running Tests

### Prerequisites

1. **Node.js and npm** installed
2. **Docker and Docker Compose** installed
3. **Frontend dependencies** installed:
   ```bash
   cd frontend
   npm install
   ```

### Option 1: Mocked Tests (Recommended for Development)

```bash
cd frontend
npm run test:e2e
```

This runs the mocked tests without requiring backend services.

### Option 2: Real Backend Tests

#### Step 1: Start Backend Services
```bash
# From the project root
./scripts/start-e2e-backend.sh
```

This script will:
- Start PostgreSQL, user-service, accounts-service, transactions-service, and api-gateway
- Wait for all services to be healthy
- Display service URLs

#### Step 2: Run Tests
```bash
cd frontend
npm run test:e2e:real-backend
```

### Option 3: All-in-One Script

```bash
# From the project root
./scripts/run-e2e-tests.sh
```

This script automatically:
- Checks if backend services are running
- Starts them if needed
- Waits for services to be ready
- Runs the e2e tests

### Option 4: UI Mode (Interactive)

```bash
cd frontend
npm run test:e2e:ui
```

This opens the Playwright UI for interactive test debugging.

## Configuration

### Environment Variables

The tests use these environment variables:

- `BACKEND_API_URL`: URL of the API Gateway (default: `http://localhost:8080`)
- `NODE_ENV`: Environment mode (set to `test` for e2e tests)

### Playwright Configuration

- **`playwright.config.ts`**: Default configuration for mocked tests
- **`playwright.config.real-backend.ts`**: Configuration for real backend tests

## Troubleshooting

### Common Issues

#### 1. "getaddrinfo EAI_AGAIN api-gateway" Error
**Cause**: Tests trying to connect to Docker hostname from outside Docker network
**Solution**: Use the real backend test configuration or ensure `BACKEND_API_URL` is set to `http://localhost:8080`

#### 2. Backend Services Not Starting
**Cause**: Docker not running or port conflicts
**Solution**: 
```bash
# Check Docker status
docker info

# Check for port conflicts
lsof -i :8080
lsof -i :5432

# Restart Docker if needed
```

#### 3. Tests Timing Out
**Cause**: Backend services taking too long to start
**Solution**: Increase timeout in Playwright config or check service health:
```bash
curl http://localhost:8080/actuator/health
```

#### 4. Database Connection Issues
**Cause**: PostgreSQL not ready or wrong credentials
**Solution**: Check database logs:
```bash
docker-compose logs postgres
```

### Debug Mode

To run tests in debug mode with browser visible:

```bash
cd frontend
npm run test:e2e:headed
```

### Viewing Test Results

After running tests, view the HTML report:

```bash
cd frontend
npx playwright show-report
```

## Test Data Management

### Unique Test Data
The real backend tests generate unique usernames and emails using timestamps to avoid conflicts:

```typescript
const timestamp = Date.now();
const username = `testuser${timestamp}`;
const email = `test${timestamp}@example.com`;
```

### Database Cleanup
The tests don't automatically clean up test data. For production testing, consider:

1. Using a separate test database
2. Adding cleanup scripts
3. Using database transactions that rollback

## Best Practices

1. **Use mocked tests for quick feedback** during development
2. **Use real backend tests** for integration testing and before releases
3. **Run tests in CI/CD** with mocked tests for speed
4. **Run real backend tests** in staging environments
5. **Use unique test data** to avoid conflicts
6. **Add proper error handling** and timeouts
7. **Use descriptive test names** and comments

## Adding New Tests

### For Mocked Tests
1. Add to existing spec files or create new ones
2. Use `page.route()` to mock API responses
3. Test frontend behavior in isolation

### For Real Backend Tests
1. Add to `real-backend.spec.ts`
2. Use real API calls
3. Generate unique test data
4. Test complete user workflows

## CI/CD Integration

For CI/CD pipelines, use the mocked tests for speed:

```yaml
# Example GitHub Actions step
- name: Run E2E Tests
  run: |
    cd frontend
    npm run test:e2e
```

For staging deployments, use real backend tests:

```yaml
- name: Run Integration Tests
  run: |
    ./scripts/run-e2e-tests.sh
``` 