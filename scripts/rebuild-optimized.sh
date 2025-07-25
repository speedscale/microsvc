#!/bin/bash

# Rebuild and redeploy optimized Spring Boot services with faster startup times

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Rebuilding Optimized Services${NC}"
echo -e "${BLUE}========================================${NC}"

# Check if minikube is running
if ! minikube status > /dev/null 2>&1; then
    echo -e "${RED}Error: Minikube is not running. Please start minikube first.${NC}"
    exit 1
fi

# Set up Docker environment for minikube
echo -e "${YELLOW}Setting up Docker environment for minikube...${NC}"
eval $(minikube docker-env)

# Delete existing deployment
echo -e "${YELLOW}Removing existing deployment...${NC}"
kubectl delete -k kubernetes/overlays/local/ --ignore-not-found=true || true

# Wait for cleanup
echo -e "${YELLOW}Waiting for cleanup to complete...${NC}"
sleep 15

# Build optimized images
echo -e "${YELLOW}Building optimized Docker images...${NC}"

SERVICES=("user-service" "accounts-service" "transactions-service" "api-gateway")

for service in "${SERVICES[@]}"; do
    echo -e "${YELLOW}Building ${service}...${NC}"
    
    CONTEXT="./backend/$service"
    
    # Build optimized image
    docker build \
        --tag "${service}:optimized" \
        "$CONTEXT"
    
    echo -e "${GREEN}✓ Built ${service} with optimizations${NC}"
done

# Update kustomization to use optimized images
echo -e "${YELLOW}Updating kustomization for optimized images...${NC}"
cp kubernetes/overlays/local/kustomization.yaml kubernetes/overlays/local/kustomization.yaml.backup
sed 's/newTag: local/newTag: optimized/g' kubernetes/overlays/local/kustomization.yaml.backup > kubernetes/overlays/local/kustomization.yaml

# Deploy optimized services
echo -e "${YELLOW}Deploying optimized services...${NC}"
kubectl apply -k kubernetes/overlays/local/

# Wait for database to be ready first
echo -e "${YELLOW}Waiting for database to be ready...${NC}"
kubectl wait --for=condition=ready --timeout=120s pod -l app=postgres -n banking-app

# Wait for deployments to be ready with better error handling
echo -e "${YELLOW}Waiting for optimized deployments to be ready...${NC}"

for service in "${SERVICES[@]}"; do
    echo -e "${YELLOW}Waiting for ${service}...${NC}"
    kubectl wait --for=condition=available --timeout=300s deployment/${service} -n banking-app || {
        echo -e "${RED}Failed to wait for ${service} deployment${NC}"
        kubectl describe deployment/${service} -n banking-app
        kubectl logs deployment/${service} -n banking-app --tail=50
        exit 1
    }
done

# Show deployment status
echo -e "${GREEN}Optimized deployment completed successfully!${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "${YELLOW}Deployment Status:${NC}"
kubectl get pods -n banking-app

echo -e "${BLUE}========================================${NC}"
echo -e "${YELLOW}Access URLs:${NC}"
echo -e "${GREEN}Frontend:${NC} $(minikube service frontend -n banking-app --url)"
echo -e "${GREEN}API Gateway:${NC} $(minikube service api-gateway -n banking-app --url)"

echo -e "${BLUE}========================================${NC}"
echo -e "${YELLOW}Startup Time Analysis:${NC}"

# Function to extract startup time from logs
get_startup_time() {
    local service=$1
    local logs=$(kubectl logs deployment/${service} -n banking-app 2>/dev/null | grep "Started.*in.*seconds" | tail -1)
    if [[ -n "$logs" ]]; then
        echo "$logs"
    else
        echo "Startup time not found in logs"
    fi
}

# Check startup times for each service
for service in "${SERVICES[@]}"; do
    echo -e "${YELLOW}${service} startup time:${NC}"
    get_startup_time $service
done

echo -e "${BLUE}========================================${NC}"
echo -e "${YELLOW}Optimizations Applied:${NC}"
echo -e "✓ Lazy initialization enabled"
echo -e "✓ JVM optimizations for faster startup"
echo -e "✓ Reduced logging levels"
echo -e "✓ Conditional OpenTelemetry loading"
echo -e "✓ Optimized database connection pool"
echo -e "✓ Disabled unnecessary features (Prometheus, detailed health checks)"

echo -e "${BLUE}========================================${NC}"
echo -e "${YELLOW}Useful Commands:${NC}"
echo -e "kubectl logs -f deployment/user-service -n banking-app"
echo -e "kubectl logs -f deployment/accounts-service -n banking-app"
echo -e "kubectl logs -f deployment/transactions-service -n banking-app"
echo -e "kubectl logs -f deployment/api-gateway -n banking-app" 