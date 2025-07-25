#!/bin/bash

# Build and push multi-architecture Docker images for minikube deployment
# This script builds images for both AMD64 and ARM64 architectures

set -e

# Configuration
REGISTRY="ghcr.io"
REPO="speedscale/microsvc"
VERSION="latest"

# Services to build
SERVICES=("user-service" "accounts-service" "transactions-service" "api-gateway" "frontend")

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Building multi-architecture Docker images for minikube deployment...${NC}"

# Check if Docker Buildx is available
if ! docker buildx version > /dev/null 2>&1; then
    echo -e "${RED}Error: Docker Buildx is not available. Please install Docker Buildx.${NC}"
    exit 1
fi

# Create and use a new builder instance for multi-architecture builds
echo -e "${YELLOW}Setting up Docker Buildx builder...${NC}"
docker buildx create --name multiarch-builder --use --bootstrap || true

# Build and push each service
for service in "${SERVICES[@]}"; do
    echo -e "${YELLOW}Building ${service}...${NC}"
    
    # Determine the context path
    if [ "$service" = "frontend" ]; then
        CONTEXT="./frontend"
    else
        CONTEXT="./backend/$service"
    fi
    
    # Build and push multi-architecture image
    docker buildx build \
        --platform linux/amd64,linux/arm64 \
        --tag "${REGISTRY}/${REPO}/${service}:${VERSION}" \
        --push \
        --cache-from type=gha \
        --cache-to type=gha,mode=max \
        "$CONTEXT"
    
    echo -e "${GREEN}✓ Built and pushed ${service} for AMD64 and ARM64${NC}"
done

echo -e "${GREEN}All multi-architecture images have been built and pushed successfully!${NC}"
echo -e "${YELLOW}You can now deploy to minikube using:${NC}"
echo -e "kubectl apply -k kubernetes/base/" 