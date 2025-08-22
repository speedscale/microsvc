# System Architecture & Traffic Flow

## Local Development with Colima

When using Colima for local Kubernetes development, use the local overlay which references local Docker images:

```bash
# Build local images (without pushing to registry)
make docker-build-versioned

# Deploy using local overlay (uses localhost:5000 registry)
kubectl apply -k kubernetes/overlays/local/

# Or if running a local registry
docker run -d -p 5000:5000 --name registry registry:2
docker tag ghcr.io/speedscale/microsvc/frontend:v1.1.11 localhost:5000/frontend:v1.1.11
docker push localhost:5000/frontend:v1.1.11
```

The local overlay:
- Uses `imagePullPolicy: IfNotPresent` instead of `Always`
- References images from `localhost:5000` registry
- Avoids pulling from remote registries

## Traffic Flow Design
All external traffic flows through the frontend service, which acts as the single entry point:

```
Client → Frontend Service → API Gateway → Backend Services
```

## Architecture Principles

- **Frontend as Proxy**: Frontend contains Next.js API routes that proxy requests to the API Gateway
- **No Direct Backend Access**: Clients never directly access backend services or API Gateway
- **Server-Side Communication**: Backend communication uses internal Kubernetes service URLs (e.g., `http://api-gateway:8080`)
- **Relative Client URLs**: Frontend client code uses relative URLs (`/api/users/login`) that route to Next.js API handlers
- **Environment Agnostic**: No hardcoded URLs in client-side code, eliminating `NEXT_PUBLIC_API_URL` configuration issues

## Benefits

- Simplified client configuration (no environment-specific URLs)
- Proper separation of concerns between client and server
- Security through single entry point
- Consistent request/response handling and logging

## Observability

The application is instrumented with OpenTelemetry (OTEL) for comprehensive observability, including distributed tracing, metrics, and logs.

### Monitoring Stack

- **Jaeger**: For distributed trace collection and visualization.
- **Prometheus**: For collecting and storing time-series metrics.
- **Grafana**: For visualizing metrics and creating dashboards.

### Distributed Tracing

Distributed tracing is configured across all services (frontend, API Gateway, and all backend microservices) to provide end-to-end visibility of requests.

#### Standardized Configuration

**Protocol**: gRPC (not HTTP/protobuf)
**Endpoint**: `http://jaeger:4317` (gRPC port)
**Propagator**: `tracecontext` (W3C Trace Context format)
**Sampling**: 100% sampling (`always_on`) for complete visibility

#### Environment Variables (Docker Compose & Kubernetes)

All services use these standardized environment variables:

```yaml
OTEL_SERVICE_NAME=<service-name>
OTEL_EXPORTER_OTLP_ENDPOINT=http://jaeger:4317
OTEL_EXPORTER_OTLP_PROTOCOL=grpc
OTEL_TRACES_EXPORTER=otlp
OTEL_METRICS_EXPORTER=otlp
OTEL_LOGS_EXPORTER=otlp
OTEL_TRACES_SAMPLER=always_on
OTEL_PROPAGATORS=tracecontext
OTEL_RESOURCE_ATTRIBUTES=service.namespace=banking-app
```

#### Application YAML Configuration

All Spring Boot services use this standardized configuration:

```yaml
otel:
  service:
    name: ${spring.application.name}
  exporter:
    otlp:
      protocol: grpc
      endpoint: http://localhost:4317
  traces:
    exporter: otlp
    propagators: tracecontext
    sampler:
      type: always_on
  metrics:
    exporter: otlp
  logs:
    exporter: otlp
  propagation:
    type: tracecontext
```

#### Trace Flow

The trace flow follows the application's traffic flow:
`Frontend → API Gateway → Backend Service → Database`

This setup allows for debugging and performance analysis by visualizing the entire lifecycle of a request as it travels through the different components of the system.

## Troubleshooting

### OpenTelemetry Issues

**"Unsupported type of propagator: w3c"**
- **Cause**: Using `w3c` instead of `tracecontext` propagator
- **Solution**: Ensure all configurations use `OTEL_PROPAGATORS=tracecontext` and `otel.propagation.type: tracecontext`

**gRPC Connection Errors**
- **Cause**: Protocol mismatch (using `http/protobuf` instead of `grpc`)
- **Solution**: Use `OTEL_EXPORTER_OTLP_PROTOCOL=grpc` and `protocol: grpc` in application.yml

**Endpoint Mismatch**
- **Cause**: Using port 4318 (HTTP) instead of 4317 (gRPC)
- **Solution**: Use `http://jaeger:4317` for all gRPC connections

### Verification Steps

1. **Check environment variables**:
   ```bash
   # Docker Compose
   docker exec <container> env | grep OTEL
   
   # Kubernetes
   kubectl exec -it deployment/<service> -n banking-app -- env | grep OTEL
   ```

2. **Verify Jaeger connectivity**:
   ```bash
   # Docker Compose
   docker exec <container> curl -v http://jaeger:4317
   
   # Kubernetes
   kubectl exec -it deployment/<service> -n banking-app -- curl -v http://jaeger:4317
   ```

3. **Check application logs** for trace IDs:
   ```bash
   # Look for trace IDs in format: [traceId,spanId]
   docker logs <container> | grep -E '\[[a-f0-9]{32},[a-f0-9]{16}\]'
   ```

## Version Management

The application uses semantic versioning (SemVer) with all services versioned together. When any service is updated, all services get the same version number.

### Version Management Standard

**Single Source of Truth**: Version management is handled exclusively through the Makefile commands, which internally use `scripts/version.sh`. This ensures consistency across all components.

### Version Format
- **Format**: `MAJOR.MINOR.PATCH` (e.g., `1.2.2`)
- **Storage**: Current version stored in `VERSION` file at repository root
- **Image Tags**: 
  - Simple tag for Kubernetes: `v{VERSION}` (e.g., `v1.2.2`)
  - Development tag with SHA: `v{VERSION}-{GIT_SHA}` (e.g., `v1.2.2-c6c2bf6`)

### Version Management Process

1. **Check Current Version**:
   ```bash
   make version         # Shows current version
   make version-info    # Shows detailed version information
   ```

2. **Bump Version**:
   ```bash
   make version-bump BUMP_TYPE=patch    # 1.2.2 -> 1.2.3
   make version-bump BUMP_TYPE=minor    # 1.2.2 -> 1.3.0
   make version-bump BUMP_TYPE=major    # 1.2.2 -> 2.0.0
   ```

3. **Update All Components**:
   ```bash
   make update-k8s-version    # Updates Kubernetes manifests
   ```

4. **Build and Deploy**:
   ```bash
   make docker-build-versioned         # Build with version tags
   kubectl apply -k kubernetes/overlays/speedscale/
   ```

### What Gets Updated
When version is bumped, the following are automatically updated:
- `VERSION` file in repository root
- All backend service `pom.xml` files
- Frontend `package.json`
- Simulation client `package.json`
- Kubernetes deployment manifests (when running `make update-k8s-version`)

### Services
All services use the same version: `user-service`, `accounts-service`, `transactions-service`, `api-gateway`, `frontend`, `simulation-client`

## File Organization Standards

### Directory Structure
- **SQL Files**: Database-related SQL files belong in `database/` directory
  - Seed files: `database/seeds/`
  - Migration files: `database/migrations/<service>/`
  - Schema files: `database/init/`
- **JavaScript Utilities**: Non-application JS files belong in `scripts/` or `tools/`
- **Test Files**: 
  - Kubernetes test manifests: `kubernetes/testing/`
  - Documentation for testing: `docs/`
- **Markdown Documentation**: 
  - Test documentation: `docs/`
  - Service-specific docs: within service directories

### Root Directory Policy
The repository root should only contain:
- Core project files (README.md, LICENSE, etc.)
- Configuration files (Makefile, docker-compose.yml, etc.)
- Project instruction files (CLAUDE.md, ARCHITECTURE.md, PLAN.md)
- Version control files (.gitignore, VERSION)

## Git Workflow Standards

### Branch Management
- **Always work from feature branches**: Never commit directly to master
- **Branch naming**: Use descriptive names like `fix/version-consistency` or `feat/add-logging`
- **Short-lived branches**: Keep branches focused and merge quickly to avoid conflicts
- **Clean up**: Delete branches after merging to avoid confusion

### Workflow Process
1. **Start from master**: Always create new branches from latest master
   ```bash
   git checkout master
   git pull origin master
   git checkout -b fix/descriptive-name
   ```

2. **Make focused changes**: Keep commits atomic and related to the branch purpose
   ```bash
   git add -A
   git commit -m "descriptive commit message"
   ```

3. **Push and create PR**: Push branch and create pull request
   ```bash
   git push -u origin fix/descriptive-name
   # Create PR via GitHub UI
   ```

4. **Clean up after merge**: Delete local and remote branches
   ```bash
   git checkout master
   git pull origin master
   git branch -d fix/descriptive-name
   git push origin --delete fix/descriptive-name
   ```

### Critical Rules
- **Never rebase or force push** to shared branches
- **Never work directly on master** - always use feature branches
- **Always pull latest master** before creating new branches
- **Keep branches small** - one logical change per branch
- **Verify clean state** before starting new work: `git status` should show clean

## Known Issues & Future Improvements

- **Frontend Pod Logging**: Implemented structured logging with custom logger but logs don't appear in `kubectl logs` output. The logging middleware and API client logging are implemented but may be getting filtered by Next.js internal routing or Edge Runtime limitations. Consider investigating:
  - Server-side API route logging vs middleware logging
  - Alternative logging approaches for containerized Next.js applications