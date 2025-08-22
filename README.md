# Banking Application - Microservices Demo

A banking application built with a microservices architecture demonstrating modern development practices including containerization, orchestration, and observability.

## 🚀 Quick Start

### Run Everything Locally (Docker Compose)
```bash
# Start all services and observability stack
docker-compose up -d

# Access the application and tools
open http://localhost:3000      # Frontend
open http://localhost:3001      # Grafana (admin/admin)
open http://localhost:9090      # Prometheus  
open http://localhost:16686     # Jaeger
```

### Deploy to Kubernetes
```bash
# Deploy the entire application stack
kubectl apply -k kubernetes/base/

# Deploy observability stack (optional)
kubectl apply -k kubernetes/observability/

# Access the application (adjust for your cluster)
kubectl port-forward -n banking-app svc/frontend-service-nodeport 30000:30000
open http://localhost:30000
```

## Architecture

A microservices application with:
- **Frontend**: Next.js application with TypeScript
- **Backend**: 4 Java Spring Boot microservices (User, Accounts, Transactions, API Gateway)
- **Database**: PostgreSQL with service-specific schemas
- **Observability**: OpenTelemetry with Jaeger, Prometheus, and Grafana

![Architecture](./images/microsvc-architecture.png)

## Repository Structure

```
├── backend/
│   ├── user-service/        # User authentication and profile management
│   ├── accounts-service/    # Bank account and balance management
│   ├── transactions-service/ # Financial transaction processing
│   └── api-gateway/        # Request routing and authentication
├── frontend/               # Next.js web application
├── kubernetes/             # Kubernetes manifests and configs
├── tools/                  # Development tools and templates
└── scripts/                # Essential utility scripts
```

## Development

### Individual Service Development
Each service has its own Makefile for isolated development and testing:

```bash
# Build and run individual services
cd backend/user-service
make build
make run

# Run with dependencies mocked using proxymock
make proxymock-record  # Record traffic with real dependencies
make proxymock-mock    # Run with mocked dependencies  
make proxymock-replay  # Test with recorded traffic
```

### Frontend Development
```bash
cd frontend
npm install
npm run dev            # Development server at http://localhost:3000
npm run build         # Production build
npm test              # Run tests
```

### Database Operations
```bash
# Connect to PostgreSQL
psql -h localhost -p 5432 -U postgres -d banking_app

# Run migrations (from service directory)  
./mvnw flyway:migrate
```

## Testing

### Backend Tests
```bash
# Run unit tests for all services
./mvnw test

# Run integration tests
./mvnw verify -P integration-tests

# Test individual service with mocked dependencies
cd backend/user-service
make test
make proxymock-mock  # Test in isolation
```

### Frontend Tests
```bash
cd frontend
npm test              # Unit tests
npm run test:e2e      # End-to-end tests
```

## Debugging with Proxymock

Each service supports isolated testing without running all dependencies:

### Debugging Workflow
```bash
# 1. Record traffic while system is working
cd backend/user-service
make proxymock-record
# Make some API calls to generate traffic

# 2. Test service in isolation with mocked dependencies
make proxymock-mock    # Starts service with postgres/other services mocked
make proxymock-replay  # Replays recorded requests

# 3. Debug specific issues
make proxymock-list    # See recorded traffic files
make proxymock-env     # Show environment variables needed
make proxymock-stop    # Stop all proxymock processes
```

### Service Isolation Testing
| Service | What Gets Mocked | Use Case |
|---------|-----------------|----------|
| user-service | postgres, accounts-service, transactions-service | Auth and user management testing |
| accounts-service | postgres, user-service | Account operations testing |
| transactions-service | postgres, accounts-service, user-service | Transaction processing testing |  
| api-gateway | All backend services | API routing and gateway testing |
| frontend | api-gateway | UI testing with mocked backend |

### Running Individual Services Locally

You can run services locally for debugging without Docker:

```bash
# 1. Start only PostgreSQL in Docker
docker-compose up -d postgres

# 2. Run service locally with IDE debugger
cd backend/user-service
export DB_HOST=localhost
export DB_PORT=5432
./mvnw spring-boot:run

# 3. Or use proxymock to mock all dependencies
make proxymock-mock  # No database or other services needed
```

## Key Features

- **Authentication**: JWT-based authentication with HttpOnly cookies
- **Observability**: Distributed tracing, metrics, and structured logging
- **Development Tools**: Service-specific Makefiles with proxymock integration
- **Container Ready**: Docker and Kubernetes deployment configurations
- **Testing**: Comprehensive unit, integration, and E2E test coverage

## Version Management

The project uses semantic versioning with all services sharing the same version number:

```bash
# Check current version
make version                          # Shows: 1.2.2

# Bump version
make version-bump BUMP_TYPE=patch     # 1.2.2 -> 1.2.3
make version-bump BUMP_TYPE=minor     # 1.2.2 -> 1.3.0
make version-bump BUMP_TYPE=major     # 1.2.2 -> 2.0.0

# Update all files and Kubernetes manifests
make version-bump BUMP_TYPE=patch && make update-k8s-version

# Build and deploy with new version
make docker-build-versioned           # Build images with version tag
kubectl apply -k kubernetes/overlays/speedscale/
```

## Documentation

- **[TROUBLESHOOTING.md](./TROUBLESHOOTING.md)** - Comprehensive debugging guide
- **[OBSERVABILITY.md](./OBSERVABILITY.md)** - Monitoring, tracing, and metrics setup
- **[PLAN.md](./PLAN.md)** - Detailed implementation phases and testing criteria
- **[ARCHITECTURE.md](./ARCHITECTURE.md)** - System architecture and design decisions

## Getting Started

1. **Prerequisites**: Docker, Docker Compose, Node.js 18+, Java 17+, Maven 3.8+
2. **Quick start**: Run `docker-compose up -d` to start everything
3. **Development**: Use service-specific Makefiles for isolated development
4. **Testing**: Use proxymock for dependency-free testing
5. **Deployment**: Use Kubernetes manifests for production deployment

## Health Checks

Verify all services are running:
```bash
curl http://localhost:8080/actuator/health  # API Gateway
curl http://localhost:8081/actuator/health  # User Service  
curl http://localhost:8082/actuator/health  # Accounts Service
curl http://localhost:8083/actuator/health  # Transactions Service
curl http://localhost:3000/api/health       # Frontend
```

---

For detailed troubleshooting, monitoring setup, and development workflows, see the documentation files listed above.