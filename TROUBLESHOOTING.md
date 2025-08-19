# Troubleshooting Guide

This guide helps you debug common issues in the Banking Microservices Application.

## Quick Diagnostics

### Health Checks
Check if all services are running:
```bash
# All services
curl http://localhost:8080/actuator/health  # API Gateway
curl http://localhost:8081/actuator/health  # User Service
curl http://localhost:8082/actuator/health  # Accounts Service
curl http://localhost:8083/actuator/health  # Transactions Service
curl http://localhost:3000/api/health       # Frontend
```

### Database Connection
Test database connectivity:
```bash
# From host machine
psql -h localhost -p 5432 -U banking_user -d banking_app

# Check individual service databases
psql -h localhost -p 5432 -U user_service_user -d banking_app
psql -h localhost -p 5432 -U accounts_service_user -d banking_app
psql -h localhost -p 5432 -U transactions_service_user -d banking_app
```

### Service Logs
View logs for debugging:
```bash
# Docker Compose logs
docker-compose logs user-service
docker-compose logs accounts-service
docker-compose logs transactions-service
docker-compose logs api-gateway
docker-compose logs frontend

# Follow logs in real-time
docker-compose logs -f user-service
```

## Common Issues

### 1. Service Won't Start

**Symptom**: Service fails to start with port binding errors
**Solution**:
```bash
# Check if port is already in use
lsof -i :8080  # Replace with actual port
kill -9 <PID> # Kill the process using the port

# Or restart with different ports
export USER_SERVICE_PORT=8091
docker-compose up user-service
```

### 2. Database Connection Issues

**Symptom**: `Failed to obtain JDBC Connection`
**Root Causes & Solutions**:

- **Database not running**:
  ```bash
  docker-compose up -d postgres
  docker-compose logs postgres
  ```

- **Wrong credentials**:
  Check environment variables in `docker-compose.yml`

- **Network issues**:
  ```bash
  docker network ls
  docker network inspect microsvc_default
  ```

### 3. JWT Authentication Problems

**Symptom**: 401 Unauthorized responses
**Debug Steps**:
```bash
# Check JWT token in browser developer tools
# Look for Authorization header in requests

# Verify JWT configuration
grep -r "jwt" backend/*/src/main/resources/application.yml

# Check if user-service is running (it generates tokens)
curl http://localhost:8081/actuator/health
```

### 4. Frontend API Connection Issues

**Symptom**: Frontend can't reach backend APIs
**Debug Steps**:
```bash
# Check if API Gateway is accessible
curl http://localhost:8080/actuator/health

# Verify frontend API configuration
cat frontend/.env.local

# Check browser network tab for failed requests
# Look for CORS errors in browser console
```

### 5. Build Failures

**Symptom**: Maven build fails
**Solutions**:
```bash
# Clean and rebuild
./mvnw clean install -DskipTests

# Check Java version
java -version  # Should be Java 17+

# Clear Maven cache
rm -rf ~/.m2/repository

# For specific service
cd backend/user-service
./mvnw clean package
```

### 6. OpenTelemetry Issues

**Symptom**: No traces appearing in Jaeger
**Debug Steps**:
```bash
# Check if Jaeger is running
curl http://localhost:16686

# Verify OTLP collector is running
curl http://localhost:4318/v1/traces

# Check service environment variables
docker-compose exec user-service env | grep OTEL

# Enable debug logging
export OTEL_LOG_LEVEL=DEBUG
```

## Debugging with Proxymock

### Individual Service Testing

Use service-specific Makefiles for isolated testing:

```bash
# Test user-service in isolation
cd backend/user-service
make proxymock-record  # Record traffic
make proxymock-mock    # Start with mocked dependencies
make proxymock-replay  # Replay recorded requests

# Test without database
make proxymock-mock  # This mocks postgres connection
```

### Recording and Replaying Workflows

1. **Record real traffic**:
   ```bash
   cd backend/user-service
   make proxymock-record
   # In another terminal, make actual API calls
   curl -X POST http://localhost:4181/api/users/register \
     -H "Content-Type: application/json" \
     -d '{"username":"test","email":"test@test.com","password":"pass123"}'
   ```

2. **Replay without dependencies**:
   ```bash
   make proxymock-mock    # Start service with mocked postgres
   make proxymock-replay  # Replay the recorded requests
   ```

3. **Debug failed replays**:
   ```bash
   make proxymock-list    # See recorded files
   tail -f proxymock.log  # Check proxymock logs
   ```

### Service Isolation Matrix

| Service | Mocked Dependencies | Use Case |
|---------|-------------------|----------|
| user-service | postgres, accounts-service, transactions-service | User registration/auth testing |
| accounts-service | postgres, user-service | Account operations testing |
| transactions-service | postgres, accounts-service, user-service | Transaction testing |
| api-gateway | All backend services | API routing testing |
| frontend | api-gateway | UI testing |

## Performance Issues

### Slow Database Queries
```bash
# Enable PostgreSQL query logging
# In postgres container:
echo "log_statement = 'all'" >> /var/lib/postgresql/data/postgresql.conf
echo "log_duration = on" >> /var/lib/postgresql/data/postgresql.conf

# Restart postgres container
docker-compose restart postgres

# View query logs
docker-compose logs postgres | grep "duration:"
```

### Memory Issues
```bash
# Check container memory usage
docker stats

# Increase JVM heap size
export JAVA_OPTS="-Xmx1g -Xms512m"
docker-compose up user-service
```

### Network Latency
```bash
# Test service-to-service communication
docker-compose exec user-service curl http://accounts-service:8082/actuator/health
docker-compose exec accounts-service curl http://transactions-service:8083/actuator/health
```

## Development Environment

### Running Without Docker

1. **Start only PostgreSQL in Docker**:
   ```bash
   docker-compose up -d postgres
   ```

2. **Run services locally**:
   ```bash
   # Terminal 1: User Service
   cd backend/user-service
   export DB_HOST=localhost
   export DB_PORT=5432
   ./mvnw spring-boot:run

   # Terminal 2: Accounts Service  
   cd backend/accounts-service
   export DB_HOST=localhost
   export DB_PORT=5432
   export USER_SERVICE_URL=http://localhost:8081
   ./mvnw spring-boot:run
   ```

3. **Debug with IDE**:
   - Set breakpoints in your IDE
   - Configure run configuration with environment variables
   - Start services in debug mode

### Hot Reload Development
```bash
# For backend services (Maven)
cd backend/user-service
./mvnw spring-boot:run -Dspring-boot.run.jvmArguments="-agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=5005"

# For frontend (Next.js)
cd frontend
npm run dev  # Automatically reloads on file changes
```

## Configuration Issues

### Environment Variables
```bash
# Check current environment
docker-compose config

# Override for debugging
echo "LOGGING_LEVEL_ROOT=DEBUG" >> .env
docker-compose up user-service
```

### Database Migrations
```bash
# Check migration status
cd backend/user-service
./mvnw flyway:info

# Run migrations manually
./mvnw flyway:migrate

# Reset database (CAUTION: destroys data)
./mvnw flyway:clean
./mvnw flyway:migrate
```

## Monitoring and Logs

### Centralized Logging
```bash
# View all service logs together
docker-compose logs -f --tail=100

# Filter for errors
docker-compose logs | grep ERROR

# Filter by service
docker-compose logs user-service accounts-service
```

### Metrics Access
- **Prometheus**: http://localhost:9090
- **Grafana**: http://localhost:3001 (admin/admin)
- **Jaeger**: http://localhost:16686

## Testing

### Integration Tests
```bash
# Run all tests
./mvnw test

# Run specific test class
./mvnw test -Dtest=UserServiceTest

# Run with profile
./mvnw test -Dspring.profiles.active=test
```

### API Testing
```bash
# Use httpie for API testing
http POST localhost:8080/api/users/register username=test email=test@test.com password=pass123

# Use curl with proper headers
curl -X POST http://localhost:8080/api/users/register \
  -H "Content-Type: application/json" \
  -d '{"username":"test","email":"test@test.com","password":"pass123"}'
```

## Getting Help

### Log Analysis Commands
```bash
# Find errors in the last hour
docker-compose logs --since=1h | grep -i error

# Count error occurrences
docker-compose logs | grep -c ERROR

# Find specific error patterns
docker-compose logs | grep -E "(OutOfMemory|Connection.*failed|Timeout)"
```

### Useful Debug Information
When reporting issues, include:
```bash
# System information
docker --version
docker-compose --version
java -version
node --version
npm --version

# Service status
docker-compose ps
docker stats --no-stream

# Recent logs
docker-compose logs --tail=50 user-service
```

## Reset Everything
If all else fails, complete reset:
```bash
# Stop all services
docker-compose down

# Remove all containers and volumes
docker-compose down -v --remove-orphans

# Clean up Docker
docker system prune -f

# Rebuild from scratch
docker-compose build --no-cache
docker-compose up -d
```