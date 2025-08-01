# Kubernetes Deployment for Banking Application

This directory contains Kubernetes manifests for deploying the banking application to a Kubernetes cluster, specifically tested with minikube.

## Prerequisites

1. **Minikube installed and running**:
   ```bash
   minikube start
   ```

2. **kubectl configured** to use minikube context:
   ```bash
   kubectl config current-context  # Should show minikube
   ```

3. **Docker images built** (the deployment script will handle this)

## Quick Start

The easiest way to deploy is using the Makefile from the root directory:

```bash
cd ..
make k8s-deploy
```

This will:
1. Set up Docker environment for minikube
2. Build all Docker images using local image references
3. Deploy all Kubernetes manifests
4. Wait for services to be ready

To check deployment status:
```bash
make status
```

## Manual Deployment

If you prefer to deploy manually:

1. **Set Docker environment**:
   ```bash
   eval $(minikube docker-env)
   ```

2. **Build Docker images**:
   ```bash
   cd ../backend
   cd user-service && docker build -t banking-user-service:latest . && cd ..
   cd accounts-service && docker build -t banking-accounts-service:latest . && cd ..
   cd transactions-service && docker build -t banking-transactions-service:latest . && cd ..
   cd api-gateway && docker build -t banking-api-gateway:latest . && cd ..
   cd ../kubernetes
   ```

3. **Deploy to Kubernetes**:
   ```bash
   kubectl apply -k base/
   ```

4. **Wait for services**:
   ```bash
   kubectl wait --for=condition=ready pod -l app=postgres -n banking-app --timeout=300s
   kubectl wait --for=condition=ready pod -l app=user-service -n banking-app --timeout=300s
   kubectl wait --for=condition=ready pod -l app=accounts-service -n banking-app --timeout=300s
   kubectl wait --for=condition=ready pod -l app=transactions-service -n banking-app --timeout=300s
   kubectl wait --for=condition=ready pod -l app=api-gateway -n banking-app --timeout=300s
   ```

5. **Get API Gateway URL**:
   ```bash
   minikube service api-gateway -n banking-app --url
   ```

## Accessing the Frontend

### Minikube
```bash
# Access frontend via NodePort service
minikube service frontend-nodeport -n banking-app

# Or get the URL without opening browser
minikube service frontend-nodeport -n banking-app --url
```

### Colima
```bash
# Access frontend directly on localhost
curl http://localhost:30080
# or open in browser: http://localhost:30080
```

### Alternative: Port Forwarding
```bash
# Forward frontend service
kubectl port-forward -n banking-app service/frontend 3000:80

# Forward API gateway
kubectl port-forward -n banking-app service/api-gateway 8080:8080
```

## Architecture

The deployment consists of:

### Database
- **PostgreSQL**: Single pod with persistent storage
- **Init Scripts**: Automatically creates schemas and users for each service

### Microservices (2 replicas each)
- **User Service**: Handles user registration and authentication
- **Accounts Service**: Manages bank accounts
- **Transactions Service**: Processes transactions
- **API Gateway**: Routes requests and handles authentication

### Configuration
- **ConfigMaps**: Environment variables and service URLs
- **Secrets**: Database passwords and JWT secret
- **Namespace**: `banking-app` with RBAC configuration

## Monitoring

Check deployment status:
```bash
kubectl get pods -n banking-app
kubectl get services -n banking-app
kubectl get ingress -n banking-app
```

View logs:
```bash
kubectl logs -f deployment/api-gateway -n banking-app
kubectl logs -f deployment/user-service -n banking-app
```

## Testing

Once deployed, you can test the API:

```bash
# Get the API Gateway URL
API_GATEWAY_URL=$(minikube service api-gateway -n banking-app --url)

# Test health endpoint
curl $API_GATEWAY_URL/actuator/health

# Test user registration
curl -X POST $API_GATEWAY_URL/api/user-service/register \
  -H "Content-Type: application/json" \
  -d '{"username":"testuser","email":"test@example.com","password":"password123"}'
```

## Cleanup

To remove the deployment, use the Makefile:
```bash
cd ..
make undeploy
```

Or remove manually:
```bash
kubectl delete namespace banking-app
```

## Troubleshooting

### Images not found
If you get "ImagePullBackOff" errors, ensure Docker environment is set correctly:
```bash
eval $(minikube docker-env)
docker images | grep banking  # Should show your built images
```

### Database connection issues
Check if PostgreSQL is running and ready:
```bash
kubectl logs deployment/postgres -n banking-app
kubectl get pod -l app=postgres -n banking-app
```

### Service communication issues
Verify services can reach each other:
```bash
kubectl exec -it deployment/api-gateway -n banking-app -- curl http://user-service:8080/actuator/health
```

## Directory Structure

```
kubernetes/
├── base/
│   ├── namespace/
│   │   └── namespace.yaml          # Namespace and RBAC
│   ├── database/
│   │   ├── postgres-configmap.yaml # Database init scripts
│   │   ├── postgres-pvc.yaml       # Persistent volume claim
│   │   ├── postgres-deployment.yaml # PostgreSQL deployment
│   │   └── postgres-service.yaml   # PostgreSQL service
│   ├── configmaps/
│   │   ├── app-config.yaml         # Application configuration
│   │   └── app-secrets.yaml        # Secrets (passwords, JWT)
│   ├── services/
│   │   ├── user-service-*.yaml     # User service manifests
│   │   ├── accounts-service-*.yaml # Accounts service manifests
│   │   ├── transactions-service-*.yaml # Transactions service manifests
│   │   └── api-gateway-*.yaml      # API Gateway manifests
│   └── kustomization.yaml          # Kustomize configuration
├── overlays/
│   └── local/                      # Local/development overrides
└── README.md                      # This file
```