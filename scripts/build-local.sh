#!/bin/bash

# Build Docker images locally for minikube testing
# This script builds images for the current platform and loads them into minikube

set -e

# Configuration
VERSION="local"

# Services to build
SERVICES=("user-service" "accounts-service" "transactions-service" "api-gateway" "frontend")

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Building Docker images for local minikube testing...${NC}"

# Check if minikube is running
if ! minikube status > /dev/null 2>&1; then
    echo -e "${RED}Error: Minikube is not running. Please start minikube first.${NC}"
    exit 1
fi

# Set up Docker environment for minikube
echo -e "${YELLOW}Setting up Docker environment for minikube...${NC}"
eval $(minikube docker-env)

# Build each service
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
        --tag "${service}:${VERSION}" \
        "$CONTEXT"
    
    echo -e "${GREEN}✓ Built ${service}${NC}"
done

echo -e "${GREEN}All images have been built successfully!${NC}"
echo -e "${YELLOW}You can now deploy to minikube using:${NC}"
echo -e "kubectl apply -k kubernetes/overlays/local/" 