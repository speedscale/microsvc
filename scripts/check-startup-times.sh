#!/bin/bash

# Check startup times of deployed Spring Boot services

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Spring Boot Startup Time Analysis${NC}"
echo -e "${BLUE}========================================${NC}"

# Check if services are deployed
if ! kubectl get namespace banking-app > /dev/null 2>&1; then
    echo -e "${RED}Error: banking-app namespace not found. Please deploy the services first.${NC}"
    exit 1
fi

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

# Function to extract WebApplicationContext initialization time
get_context_time() {
    local service=$1
    local logs=$(kubectl logs deployment/${service} -n banking-app 2>/dev/null | grep "Root WebApplicationContext.*initialization completed" | tail -1)
    if [[ -n "$logs" ]]; then
        echo "$logs"
    else
        echo "Context initialization time not found"
    fi
}

# Check startup times for each service
SERVICES=("user-service" "accounts-service" "transactions-service" "api-gateway")

echo -e "${YELLOW}Current Startup Times:${NC}"
echo -e "${BLUE}========================================${NC}"

for service in "${SERVICES[@]}"; do
    echo -e "${YELLOW}${service}:${NC}"
    echo -e "  Total startup time: $(get_startup_time $service)"
    echo -e "  Context init time:  $(get_context_time $service)"
    echo ""
done

echo -e "${BLUE}========================================${NC}"
echo -e "${YELLOW}Pod Status:${NC}"
kubectl get pods -n banking-app

echo -e "${BLUE}========================================${NC}"
echo -e "${YELLOW}Recent Logs (last 5 lines):${NC}"
for service in "${SERVICES[@]}"; do
    echo -e "${YELLOW}${service}:${NC}"
    kubectl logs deployment/${service} -n banking-app --tail=5 2>/dev/null || echo "  No logs available"
    echo ""
done 