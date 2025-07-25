#!/bin/bash

# Rebuild Docker images with fixed database configuration

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Rebuilding Images with Fixed Config${NC}"
echo -e "${BLUE}========================================${NC}"

# Check if minikube is running
if ! minikube status > /dev/null 2>&1; then
    echo -e "${RED}Error: Minikube is not running. Please start minikube first.${NC}"
    exit 1
fi

# Set up Docker environment for minikube
echo -e "${YELLOW}Setting up Docker environment for minikube...${NC}"
eval $(minikube docker-env)

# Build optimized images with fixed configuration
echo -e "${YELLOW}Building Docker images with fixed database configuration...${NC}"

SERVICES=("user-service" "accounts-service" "transactions-service" "api-gateway")

for service in "${SERVICES[@]}"; do
    echo -e "${YELLOW}Building ${service}...${NC}"
    
    CONTEXT="./backend/$service"
    
    # Build optimized image without cache to ensure new config is included
    docker build \
        --no-cache \
        --tag "${service}:optimized" \
        "$CONTEXT"
    
    echo -e "${GREEN}✓ Built ${service} with fixed configuration${NC}"
done

echo -e "${GREEN}All images rebuilt successfully!${NC}"
echo -e "${YELLOW}Now restart the deployments:${NC}"
echo -e "kubectl rollout restart deployment/user-service -n banking-app"
echo -e "kubectl rollout restart deployment/accounts-service -n banking-app"
echo -e "kubectl rollout restart deployment/transactions-service -n banking-app"
echo -e "kubectl rollout restart deployment/api-gateway -n banking-app" 