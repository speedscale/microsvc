#!/bin/bash

# Deploy the banking application to minikube with multi-architecture support
# This script builds images for both ARM64 and AMD64 and deploys to minikube

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Banking App Minikube Deployment${NC}"
echo -e "${BLUE}========================================${NC}"

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

# Check if minikube is installed
if ! command -v minikube &> /dev/null; then
    echo -e "${RED}Error: minikube is not installed. Please install minikube first.${NC}"
    exit 1
fi

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}Error: kubectl is not installed. Please install kubectl first.${NC}"
    exit 1
fi

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker is not installed. Please install Docker first.${NC}"
    exit 1
fi

echo -e "${GREEN}✓ All prerequisites are satisfied${NC}"

# Start minikube if not running
echo -e "${YELLOW}Starting minikube...${NC}"
if ! minikube status > /dev/null 2>&1; then
    echo -e "${YELLOW}Minikube is not running. Starting minikube...${NC}"
    minikube start --driver=docker --memory=4096 --cpus=2
else
    echo -e "${GREEN}✓ Minikube is already running${NC}"
fi

# Set up Docker environment for minikube
echo -e "${YELLOW}Setting up Docker environment for minikube...${NC}"
eval $(minikube docker-env)

# Build images for current platform (works better with minikube)
echo -e "${YELLOW}Building Docker images for current platform...${NC}"

SERVICES=("user-service" "accounts-service" "transactions-service" "api-gateway" "frontend")

for service in "${SERVICES[@]}"; do
    echo -e "${YELLOW}Building ${service}...${NC}"
    
    # Determine the context path
    if [ "$service" = "frontend" ]; then
        CONTEXT="./frontend"
    else
        CONTEXT="./backend/$service"
    fi
    
    # Build image for current platform
    docker build \
        --tag "${service}:local" \
        "$CONTEXT"
    
    echo -e "${GREEN}✓ Built ${service}${NC}"
done

# Deploy to minikube
echo -e "${YELLOW}Deploying to minikube...${NC}"

# Apply the local overlay
kubectl apply -k kubernetes/overlays/local/

# Wait for deployments to be ready
echo -e "${YELLOW}Waiting for deployments to be ready...${NC}"
kubectl wait --for=condition=available --timeout=300s deployment/user-service -n banking-app
kubectl wait --for=condition=available --timeout=300s deployment/accounts-service -n banking-app
kubectl wait --for=condition=available --timeout=300s deployment/transactions-service -n banking-app
kubectl wait --for=condition=available --timeout=300s deployment/api-gateway -n banking-app
kubectl wait --for=condition=available --timeout=300s deployment/frontend -n banking-app

# Wait for database to be ready
echo -e "${YELLOW}Waiting for database to be ready...${NC}"
kubectl wait --for=condition=ready --timeout=300s pod -l app=postgres -n banking-app

# Show deployment status
echo -e "${GREEN}Deployment completed successfully!${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "${YELLOW}Deployment Status:${NC}"
kubectl get pods -n banking-app

echo -e "${BLUE}========================================${NC}"
echo -e "${YELLOW}Access URLs:${NC}"
echo -e "${GREEN}Frontend:${NC} $(minikube service frontend -n banking-app --url)"
echo -e "${GREEN}API Gateway:${NC} $(minikube service api-gateway -n banking-app --url)"
echo -e "${GREEN}Grafana:${NC} $(minikube service grafana -n banking-app --url)"

echo -e "${BLUE}========================================${NC}"
echo -e "${YELLOW}Useful Commands:${NC}"
echo -e "kubectl logs -f deployment/frontend -n banking-app"
echo -e "kubectl logs -f deployment/api-gateway -n banking-app"
echo -e "minikube dashboard"
echo -e "kubectl delete -k kubernetes/overlays/local/  # To clean up" 