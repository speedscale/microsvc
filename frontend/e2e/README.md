# End-to-End Testing Guide

This directory contains end-to-end tests for the banking application frontend using Playwright.

## Test Types

### 1. Simplified CI Tests (`simple.spec.ts`) - **RECOMMENDED FOR CI**
These tests use API mocking and are optimized for CI/CD pipelines with:
- Single browser (Chromium only)
- Mocked APIs to avoid network dependencies
- Shorter timeouts and faster execution
- Circuit breaker for failures
- Focused on core functionality

**Pros:**
- Fast execution (2-3 minutes)
- No external dependencies
- Predictable results
- Reliable in CI/CD
- No network timeouts

**Cons:**
- Doesn't test real API integration
- May miss backend-specific issues

### 2. Mocked Tests (`auth-flow.spec.ts`)
These tests use API mocking to test the frontend in isolation without requiring backend services.

**Pros:**
- Fast execution
- No external dependencies
- Predictable results
- Good for development

**Cons:**
- Doesn't test real API integration
- May miss backend-specific issues

### 3. Real Backend Tests (`real-backend.spec.ts`)
These tests work with the actual backend services to test the complete integration.

**Pros:**
- Tests real API integration
- Catches backend-specific issues
- More realistic test scenarios

**Cons:**
- Slower execution
- Requires backend services to be running
- More complex setup
- Network dependencies

## Running Tests

### Prerequisites

1. **Node.js and npm** installed
2. **Frontend dependencies** installed:
   ```bash
   cd frontend
   npm install
   ```

### Option 1: Simplified CI Tests (Recommended)

```bash
# From project root
make test-e2e

# Or directly
./scripts/validate-e2e.sh

# Or from frontend directory
cd frontend
npm run test:e2e:ci
```

This runs the simplified tests that are used in CI/CD pipelines.

### Option 2: Mocked Tests (Development)

```bash
cd frontend
npm run test:e2e
```

This runs the mocked tests without requiring backend services.

### Option 3: Real Backend Tests

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

### Option 4: All-in-One Script

```bash
# From the project root
./scripts/run-e2e-tests.sh
```

This script automatically:
- Checks if backend services are running
- Starts them if needed
- Waits for services to be ready
- Runs the e2e tests

### Option 5: UI Mode (Interactive)

```bash
cd frontend
npm run test:e2e:ui
```

This opens the Playwright UI for interactive test debugging.

## CI/CD Integration

### GitHub Actions
The CI pipeline uses the simplified configuration (`playwright.config.ci.ts`) which:
- Runs only on Chromium browser
- Uses mocked APIs
- Has shorter timeouts (15 minutes total)
- Generates multiple report formats
- Installs only Chromium browser

### Pre-commit Validation
Before committing frontend changes, run:
```bash
./scripts/pre-commit-e2e.sh
```

This script:
- Detects frontend changes
- Runs the same tests as CI
- Prevents commits with failing tests

## Configuration

### Environment Variables

The tests use these environment variables:

- `BACKEND_API_URL`: URL of the API Gateway (default: `http://localhost:8080`)
- `NODE_ENV`: Environment mode (set to `test` for e2e tests)

### Playwright Configuration

- **`playwright.config.ts`**: Default configuration for development
- **`playwright.config.ci.ts`**: **CI-optimized configuration** (single browser, mocked APIs)
- **`playwright.config.real-backend.ts`**: Configuration for real backend tests

## Troubleshooting

### Common Issues

#### 1. "getaddrinfo EAI_AGAIN api-gateway" Error
**Cause**: Tests trying to connect to Docker hostname from outside Docker network
**Solution**: Use the CI configuration or ensure `BACKEND_API_URL` is set to `http://localhost:8080`

#### 2. Tests Timing Out in CI
**Cause**: Complex test scenarios or network issues
**Solution**: Use the simplified CI configuration with mocked APIs

#### 3. Browser Installation Issues
**Cause**: Missing browser dependencies
**Solution**: 
```bash
cd frontend
npx playwright install --with-deps chromium
```

#### 4. Frontend Server Not Starting
**Cause**: Port conflicts or missing dependencies
**Solution**: 
```bash
cd frontend
npm install
npm run dev
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

1. **Use simplified CI tests for pipelines** - Fast, reliable, no network dependencies
2. **Use mocked tests for development** - Quick feedback during development
3. **Use real backend tests for integration testing** - Before releases or staging
4. **Run validation before commits** - Use `./scripts/pre-commit-e2e.sh`
5. **Use unique test data** to avoid conflicts
6. **Add proper error handling** and timeouts
7. **Use descriptive test names** and comments

## Adding New Tests

### For Simplified CI Tests
1. Add to `simple.spec.ts` or create new files matching `simple*.spec.ts`
2. Use `page.route()` to mock API responses
3. Focus on core functionality and user workflows
4. Keep tests short and focused

### For Mocked Tests
1. Add to existing spec files or create new ones
2. Use `page.route()` to mock API responses
3. Test frontend behavior in isolation

### For Real Backend Tests
1. Add to `real-backend.spec.ts`
2. Use real API calls
3. Generate unique test data
4. Test complete user workflows

## Performance Optimization

### CI Pipeline Optimizations
- **Single browser**: Chromium only reduces execution time by ~80%
- **Mocked APIs**: Eliminates network timeouts and backend dependencies
- **Shorter timeouts**: Faster failure detection
- **Single worker**: Avoids resource conflicts
- **Browser caching**: Reuses installed browsers across runs

### Expected Execution Times
- **Simplified CI tests**: 2-3 minutes
- **Mocked tests**: 3-5 minutes
- **Real backend tests**: 5-10 minutes (depending on backend startup)

## Migration Guide

### From Old E2E Tests to Simplified Tests
1. Move core functionality tests to `simple.spec.ts`
2. Use API mocking instead of real backend calls
3. Focus on user workflows rather than edge cases
4. Reduce test complexity and duration 