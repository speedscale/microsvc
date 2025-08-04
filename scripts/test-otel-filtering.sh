#!/bin/bash

# OpenTelemetry Filtering Test Script
# This script provides a systematic way to test OpenTelemetry configuration changes

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SERVICE_NAME="api-gateway"
JAEGER_NAMESPACE="banking-app"
LOCAL_PORT="8080"
JAEGER_UI_PORT="16686"
OTLP_PORT="4317"

echo -e "${BLUE}=== OpenTelemetry Filtering Test Script ===${NC}"

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to wait for service to be ready
wait_for_service() {
    local url=$1
    local max_attempts=30
    local attempt=1
    
    echo -e "${YELLOW}Waiting for service at $url...${NC}"
    
    while [ $attempt -le $max_attempts ]; do
        if curl -s "$url" >/dev/null 2>&1; then
            echo -e "${GREEN}Service is ready!${NC}"
            return 0
        fi
        echo -n "."
        sleep 2
        attempt=$((attempt + 1))
    done
    
    echo -e "${RED}Service failed to start within $((max_attempts * 2)) seconds${NC}"
    return 1
}

# Function to stop all test environments
stop_all_test_environments() {
    echo -e "${BLUE}Step 1: Stopping all test environments...${NC}"
    
    # Kill all running services
    echo -e "${YELLOW}Stopping all Spring Boot services...${NC}"
    pkill -f "spring-boot:run" || true
    
    # Kill all port forwards
    echo -e "${YELLOW}Stopping all port forwards...${NC}"
    pkill -f "kubectl port-forward" || true
    
    # Kill any other potential test processes
    echo -e "${YELLOW}Stopping any other test processes...${NC}"
    pkill -f "mvn.*spring-boot:run" || true
    
    # Wait for processes to fully stop
    sleep 5
    
    # Verify no processes are running on our test ports
    if lsof -i :$LOCAL_PORT >/dev/null 2>&1; then
        echo -e "${RED}Warning: Port $LOCAL_PORT is still in use${NC}"
        lsof -i :$LOCAL_PORT
    fi
    
    if lsof -i :$JAEGER_UI_PORT >/dev/null 2>&1; then
        echo -e "${RED}Warning: Port $JAEGER_UI_PORT is still in use${NC}"
        lsof -i :$JAEGER_UI_PORT
    fi
    
    if lsof -i :$OTLP_PORT >/dev/null 2>&1; then
        echo -e "${RED}Warning: Port $OTLP_PORT is still in use${NC}"
        lsof -i :$OTLP_PORT
    fi
    
    echo -e "${GREEN}All test environments stopped${NC}"
}

# Function to clear all traces
clear_traces() {
    echo -e "${BLUE}Step 2: Clearing all traces by restarting Jaeger...${NC}"
    
    # Delete Jaeger pod to clear all traces
    kubectl delete pod -n $JAEGER_NAMESPACE -l app=jaeger --ignore-not-found=true
    
    # Wait for new pod to be ready
    echo -e "${YELLOW}Waiting for Jaeger pod to be ready...${NC}"
    kubectl wait --for=condition=ready pod -n $JAEGER_NAMESPACE -l app=jaeger --timeout=120s
    
    # Wait a bit more for Jaeger to fully initialize
    sleep 30
    
    echo -e "${GREEN}Jaeger pod is ready${NC}"
}

# Function to setup port forwards
setup_port_forwards() {
    echo -e "${BLUE}Step 3: Setting up port forwards...${NC}"
    
    # Kill existing port forwards
    pkill -f "kubectl port-forward" || true
    sleep 2
    
    # Start new port forwards
    kubectl port-forward -n $JAEGER_NAMESPACE svc/jaeger $JAEGER_UI_PORT:16686 >/dev/null 2>&1 &
    kubectl port-forward -n $JAEGER_NAMESPACE svc/jaeger $OTLP_PORT:4317 >/dev/null 2>&1 &
    
    # Wait for port forwards to be ready
    sleep 10
    
    # Wait for Jaeger to be accessible
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if curl -s "http://localhost:$JAEGER_UI_PORT/api/services" >/dev/null 2>&1; then
            break
        fi
        echo -n "."
        sleep 2
        attempt=$((attempt + 1))
    done
    
    if [ $attempt -gt $max_attempts ]; then
        echo -e "${RED}Port forwards failed to establish within $((max_attempts * 2)) seconds${NC}"
        return 1
    fi
    
    # Verify port forwards are working
    if curl -s "http://localhost:$JAEGER_UI_PORT/api/services" >/dev/null 2>&1; then
        echo -e "${GREEN}Port forwards are working${NC}"
    else
        echo -e "${RED}Port forwards are not working${NC}"
        return 1
    fi
}

# Function to verify no traces exist
verify_no_traces() {
    echo -e "${BLUE}Step 4: Verifying no traces exist...${NC}"
    
    local trace_count=$(curl -s "http://localhost:$JAEGER_UI_PORT/api/traces?service=$SERVICE_NAME&limit=5" | jq '.data | length' 2>/dev/null || echo "0")
    
    if [ "$trace_count" = "0" ]; then
        echo -e "${GREEN}No traces found - clean baseline${NC}"
        return 0
    else
        echo -e "${YELLOW}Found $trace_count traces - this might be from other services${NC}"
        return 0
    fi
}

# Function to start local service
start_local_service() {
    echo -e "${BLUE}Step 5: Starting local service...${NC}"
    
    # Kill existing service
    pkill -f "spring-boot:run" || true
    sleep 2
    
    # Start service in background
    cd backend/$SERVICE_NAME
    mvn spring-boot:run -Dspring-boot.run.profiles=local -Dspring-boot.run.jvmArguments="-Dotel.exporter.otlp.endpoint=http://localhost:$OTLP_PORT" >/dev/null 2>&1 &
    cd ../..
    
    # Wait for service to be ready
    wait_for_service "http://localhost:$LOCAL_PORT/actuator/info"
}

# Function to make test request
make_test_request() {
    local endpoint=$1
    local description=$2
    
    echo -e "${BLUE}Step 6: Making test request to $description...${NC}"
    
    # Make the request
    curl -s "http://localhost:$LOCAL_PORT$endpoint" >/dev/null 2>&1
    
    # Wait a moment for trace to be exported
    sleep 3
}

# Function to check if trace was created
check_trace_created() {
    local expected_operation=$1
    local description=$2
    
    echo -e "${BLUE}Step 7: Checking if trace was created for $description...${NC}"
    
    # Get the most recent trace
    local operation_name=$(curl -s "http://localhost:$JAEGER_UI_PORT/api/traces?service=$SERVICE_NAME&limit=5" | jq -r '.data[-1].spans[] | select(.operationName | contains("http")) | .operationName' 2>/dev/null || echo "")
    
    if [ -n "$operation_name" ]; then
        echo -e "${YELLOW}Found trace: $operation_name${NC}"
        
        if [[ "$operation_name" == *"$expected_operation"* ]]; then
            echo -e "${GREEN}✓ Trace contains expected operation: $expected_operation${NC}"
            return 0
        else
            echo -e "${RED}✗ Trace does not contain expected operation: $expected_operation${NC}"
            return 1
        fi
    else
        echo -e "${YELLOW}No HTTP traces found${NC}"
        return 1
    fi
}

# Function to test actuator filtering
test_actuator_filtering() {
    echo -e "${BLUE}=== Testing Actuator Endpoint Filtering ===${NC}"
    
    # Clear environment
    stop_all_test_environments
    clear_traces
    setup_port_forwards
    verify_no_traces
    start_local_service
    
    # Test 1: Health endpoint (should be filtered out)
    make_test_request "/actuator/health" "health endpoint"
    check_trace_created "actuator/health" "health endpoint"
    
    if [ $? -eq 0 ]; then
        echo -e "${RED}✗ FAILED: Health endpoint trace was created (should be filtered)${NC}"
        return 1
    else
        echo -e "${GREEN}✓ PASSED: Health endpoint trace was filtered out${NC}"
    fi
    
    # Test 2: Info endpoint (should be traced)
    make_test_request "/actuator/info" "info endpoint"
    check_trace_created "actuator/info" "info endpoint"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ PASSED: Info endpoint trace was created${NC}"
        return 0
    else
        echo -e "${RED}✗ FAILED: Info endpoint trace was not created${NC}"
        return 1
    fi
}

# Function to cleanup
cleanup() {
    echo -e "${BLUE}Cleaning up...${NC}"
    pkill -f "spring-boot:run" || true
    pkill -f "kubectl port-forward" || true
}

# Main execution
main() {
    # Check dependencies
    if ! command_exists kubectl; then
        echo -e "${RED}Error: kubectl is not installed${NC}"
        exit 1
    fi
    
    if ! command_exists curl; then
        echo -e "${RED}Error: curl is not installed${NC}"
        exit 1
    fi
    
    if ! command_exists jq; then
        echo -e "${RED}Error: jq is not installed${NC}"
        exit 1
    fi
    
    # Set trap to cleanup on exit
    trap cleanup EXIT
    
    # Run the test
    test_actuator_filtering
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}=== Test completed successfully ===${NC}"
    else
        echo -e "${RED}=== Test failed ===${NC}"
        exit 1
    fi
}

# Run main function
main "$@" 