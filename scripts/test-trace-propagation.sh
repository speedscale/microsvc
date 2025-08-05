#!/bin/bash

# Test script to verify OpenTelemetry trace propagation across microservices
# This script tests that trace IDs are properly propagated from frontend through API Gateway to backend services

set -e

echo "🔍 Testing OpenTelemetry Trace Propagation"
echo "=========================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed or not in PATH"
    exit 1
fi

# Check if we're connected to a cluster
if ! kubectl cluster-info &> /dev/null; then
    print_error "Not connected to a Kubernetes cluster"
    exit 1
fi

print_status "Checking if banking-app namespace exists..."
if ! kubectl get namespace banking-app &> /dev/null; then
    print_error "banking-app namespace not found. Please deploy the application first."
    exit 1
fi

print_status "Checking if all pods are running..."
PODS=$(kubectl get pods -n banking-app -o jsonpath='{.items[*].metadata.name}')
RUNNING_PODS=$(kubectl get pods -n banking-app --field-selector=status.phase=Running -o jsonpath='{.items[*].metadata.name}')

if [ "$PODS" != "$RUNNING_PODS" ]; then
    print_warning "Not all pods are running. Current status:"
    kubectl get pods -n banking-app
    print_warning "Continuing with test, but some services may not be available..."
fi

# Get service URLs
FRONTEND_URL=$(kubectl get service frontend-service -n banking-app -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "localhost")
FRONTEND_PORT=$(kubectl get service frontend-service -n banking-app -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "30000")

if [ "$FRONTEND_URL" = "localhost" ]; then
    FRONTEND_URL="localhost"
fi

print_status "Frontend URL: http://$FRONTEND_URL:$FRONTEND_PORT"

# Test 1: Check if Jaeger is accessible
print_status "Testing Jaeger accessibility..."
JAEGER_URL=$(kubectl get service jaeger -n banking-app -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "localhost")
JAEGER_PORT=$(kubectl get service jaeger -n banking-app -o jsonpath='{.spec.ports[?(@.name=="http-query")].nodePort}' 2>/dev/null || echo "16686")

if [ "$JAEGER_URL" = "localhost" ]; then
    JAEGER_URL="localhost"
fi

print_status "Jaeger URL: http://$JAEGER_URL:$JAEGER_PORT"

# Test 2: Generate some traffic to create traces
print_status "Generating test traffic to create traces..."

# Create a test user and perform some operations
print_status "Creating test user..."
USER_RESPONSE=$(curl -s -X POST "http://$FRONTEND_URL:$FRONTEND_PORT/api/users/register" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "trace-test-user",
    "email": "trace-test@example.com",
    "password": "TestPassword123!",
    "firstName": "Trace",
    "lastName": "Test"
  }')

if echo "$USER_RESPONSE" | grep -q "success.*true"; then
    print_success "Test user created successfully"
else
    print_warning "Failed to create test user: $USER_RESPONSE"
fi

# Login to get a token
print_status "Logging in to get authentication token..."
LOGIN_RESPONSE=$(curl -s -X POST "http://$FRONTEND_URL:$FRONTEND_PORT/api/users/login" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "trace-test-user",
    "password": "TestPassword123!"
  }')

TOKEN=$(echo "$LOGIN_RESPONSE" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)

if [ -n "$TOKEN" ]; then
    print_success "Authentication successful, token obtained"
    
    # Perform some operations that should create traces
    print_status "Creating test account..."
    ACCOUNT_RESPONSE=$(curl -s -X POST "http://$FRONTEND_URL:$FRONTEND_PORT/api/accounts" \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $TOKEN" \
      -d '{
        "accountType": "CHECKING",
        "initialBalance": 1000.00
      }')
    
    if echo "$ACCOUNT_RESPONSE" | grep -q "success.*true"; then
        print_success "Test account created successfully"
        
        # Get account ID for further operations
        ACCOUNT_ID=$(echo "$ACCOUNT_RESPONSE" | grep -o '"id":[0-9]*' | cut -d':' -f2)
        
        if [ -n "$ACCOUNT_ID" ]; then
            print_status "Performing test transaction..."
            TRANSACTION_RESPONSE=$(curl -s -X POST "http://$FRONTEND_URL:$FRONTEND_PORT/api/transactions" \
              -H "Content-Type: application/json" \
              -H "Authorization: Bearer $TOKEN" \
              -d "{
                \"accountId\": $ACCOUNT_ID,
                \"type\": \"DEPOSIT\",
                \"amount\": 500.00,
                \"description\": \"Test trace propagation\"
              }")
            
            if echo "$TRANSACTION_RESPONSE" | grep -q "success.*true"; then
                print_success "Test transaction completed successfully"
            else
                print_warning "Failed to create test transaction: $TRANSACTION_RESPONSE"
            fi
        fi
    else
        print_warning "Failed to create test account: $ACCOUNT_RESPONSE"
    fi
else
    print_warning "Failed to authenticate: $LOGIN_RESPONSE"
fi

# Test 3: Check OpenTelemetry Collector logs
print_status "Checking OpenTelemetry Collector logs for trace processing..."
COLLECTOR_POD=$(kubectl get pods -n banking-app -l app=opentelemetry,component=otel-collector -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [ -n "$COLLECTOR_POD" ]; then
    print_status "Collector pod: $COLLECTOR_POD"
    
    # Check recent logs for trace processing
    COLLECTOR_LOGS=$(kubectl logs -n banking-app "$COLLECTOR_POD" --tail=20 2>/dev/null || echo "")
    
    if echo "$COLLECTOR_LOGS" | grep -q "traces"; then
        print_success "OpenTelemetry Collector is processing traces"
    else
        print_warning "No trace processing logs found in collector"
    fi
else
    print_warning "OpenTelemetry Collector pod not found"
fi

# Test 4: Check service logs for trace headers
print_status "Checking service logs for trace propagation..."

# Check API Gateway logs
GATEWAY_POD=$(kubectl get pods -n banking-app -l app=api-gateway -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [ -n "$GATEWAY_POD" ]; then
    print_status "API Gateway pod: $GATEWAY_POD"
    GATEWAY_LOGS=$(kubectl logs -n banking-app "$GATEWAY_POD" --tail=10 2>/dev/null || echo "")
    
    if echo "$GATEWAY_LOGS" | grep -q "traceparent\|tracestate"; then
        print_success "API Gateway shows trace header propagation"
    else
        print_warning "No trace headers found in API Gateway logs"
    fi
fi

# Test 5: Verify traces in Jaeger
print_status "Waiting 10 seconds for traces to be processed..."
sleep 10

print_status "You can now check Jaeger UI at http://$JAEGER_URL:$JAEGER_PORT to verify trace propagation"
print_status "Look for traces with service names: frontend, api-gateway, user-service, accounts-service, transactions-service"

# Test 6: Check if all services are reporting to the collector
print_status "Checking service OpenTelemetry configuration..."

SERVICES=("frontend" "api-gateway" "user-service" "accounts-service" "transactions-service")

for service in "${SERVICES[@]}"; do
    SERVICE_POD=$(kubectl get pods -n banking-app -l app.kubernetes.io/service="$service" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    
    if [ -n "$SERVICE_POD" ]; then
        print_status "Checking $service configuration..."
        SERVICE_LOGS=$(kubectl logs -n banking-app "$SERVICE_POD" --tail=5 2>/dev/null || echo "")
        
        if echo "$SERVICE_LOGS" | grep -q "OpenTelemetry\|OTEL"; then
            print_success "$service has OpenTelemetry configured"
        else
            print_warning "$service may not have OpenTelemetry properly configured"
        fi
    else
        print_warning "$service pod not found"
    fi
done

print_status "Trace propagation test completed!"
print_status "Summary:"
print_status "- Check Jaeger UI for complete trace chains"
print_status "- Verify that trace IDs are consistent across services"
print_status "- Look for spans from frontend → api-gateway → backend services"

echo ""
print_status "To manually verify trace propagation:"
echo "1. Open Jaeger UI: http://$JAEGER_URL:$JAEGER_PORT"
echo "2. Search for traces from the last 15 minutes"
echo "3. Look for traces that span multiple services"
echo "4. Verify that trace IDs are consistent across all spans in a trace"
echo "5. Check that parent-child relationships are properly established" 