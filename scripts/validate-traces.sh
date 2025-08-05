#!/bin/bash

# Trace Validation Script for Banking App
# This script validates that traces contain expected data and exclude unwanted data

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE=${NAMESPACE:-banking-app}
JAEGER_PORT=${JAEGER_PORT:-16686}
JAEGER_POD=""
VALIDATION_TIMEOUT=${VALIDATION_TIMEOUT:-300}  # 5 minutes
TRACE_LOOKBACK=${TRACE_LOOKBACK:-3600000}  # 1 hour in microseconds

# Expected services
SERVICES=("frontend" "api-gateway" "user-service" "accounts-service" "transactions-service")

# Business endpoints we WANT to see (from e2e tests)
EXPECTED_BUSINESS_ENDPOINTS=(
    "/api/users/register"
    "/api/users/login"
    "/api/users/profile"
    "/api/users/check-username"
    "/api/users/check-email"
    "/api/accounts"
    "/api/accounts/[0-9]+"
    "/api/accounts/[0-9]+/balance"
    "/api/transactions"
    "/api/transactions/create"
    "/api/transactions/deposit"
    "/api/transactions/withdraw"
    "/api/transactions/transfer"
)

# Database operations we WANT to see
EXPECTED_DB_OPERATIONS=(
    "SELECT"
    "INSERT"
    "UPDATE"
    "DELETE"
)

# Spans/URLs we DO NOT want to see (health checks and monitoring)
UNWANTED_PATTERNS=(
    "/actuator/health"
    "/actuator/prometheus"
    "/actuator/info"
    "/actuator/metrics"
    "/api/healthz"
    "/healthz"
    "/metrics"
    "/-/ready"
    "/-/healthy"
    "/api/health"
)

# Function to print colored output
print_color() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to check if kubectl is available and connected
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        print_color $RED "❌ kubectl is not installed or not in PATH"
        exit 1
    fi
    
    if ! kubectl get ns $NAMESPACE &> /dev/null; then
        print_color $RED "❌ Namespace '$NAMESPACE' not found or not accessible"
        exit 1
    fi
    
    print_color $GREEN "✅ kubectl is configured and namespace '$NAMESPACE' is accessible"
}

# Function to check if all services are running
check_services() {
    print_color $BLUE "🔍 Checking service status..."
    
    local all_ready=true
    for service in "${SERVICES[@]}"; do
        local ready_replicas=$(kubectl get deployment $service -n $NAMESPACE -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
        local desired_replicas=$(kubectl get deployment $service -n $NAMESPACE -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "1")
        
        if [ "$ready_replicas" = "$desired_replicas" ] && [ "$ready_replicas" != "0" ]; then
            print_color $GREEN "  ✅ $service: $ready_replicas/$desired_replicas ready"
        else
            print_color $RED "  ❌ $service: $ready_replicas/$desired_replicas ready"
            all_ready=false
        fi
    done
    
    if [ "$all_ready" = false ]; then
        print_color $RED "❌ Not all services are ready. Please ensure all services are running before validation."
        exit 1
    fi
}

# Function to setup port forwarding to Jaeger
setup_jaeger_port_forward() {
    print_color $BLUE "🔍 Setting up Jaeger port forwarding..."
    
    # Find Jaeger pod
    JAEGER_POD=$(kubectl get pods -n $NAMESPACE -l app=jaeger -o jsonpath='{.items[0].metadata.name}')
    
    if [ -z "$JAEGER_POD" ]; then
        print_color $RED "❌ Jaeger pod not found in namespace '$NAMESPACE'"
        exit 1
    fi
    
    print_color $GREEN "✅ Found Jaeger pod: $JAEGER_POD"
    
    # Check if port is already in use
    if lsof -i :$JAEGER_PORT &> /dev/null; then
        print_color $YELLOW "⚠️  Port $JAEGER_PORT is already in use. Attempting to use existing connection..."
    else
        print_color $BLUE "🚀 Starting port forward to Jaeger on port $JAEGER_PORT..."
        kubectl port-forward -n $NAMESPACE pod/$JAEGER_POD $JAEGER_PORT:16686 &
        PORT_FORWARD_PID=$!
        
        # Wait for port forward to be ready
        sleep 5
        
        if ! lsof -i :$JAEGER_PORT &> /dev/null; then
            print_color $RED "❌ Failed to establish port forward to Jaeger"
            exit 1
        fi
        
        print_color $GREEN "✅ Port forward established to Jaeger"
    fi
}

# Function to cleanup port forward
cleanup() {
    if [ ! -z "$PORT_FORWARD_PID" ]; then
        print_color $BLUE "🧹 Cleaning up port forward..."
        kill $PORT_FORWARD_PID 2>/dev/null || true
    fi
}

# Function to query Jaeger API
query_jaeger() {
    local service=$1
    local start_time=$(($(date -u +%s%6N) - $TRACE_LOOKBACK))
    local end_time=$(date -u +%s%6N)
    
    curl -s "http://localhost:$JAEGER_PORT/api/traces?service=$service&start=$start_time&end=$end_time&limit=100" 2>/dev/null || echo '{"data":[]}'
}

# Function to validate traces for a service
validate_service_traces() {
    local service=$1
    print_color $BLUE "🔍 Validating traces for service: $service"
    
    local traces_response=$(query_jaeger "$service")
    local traces_count=$(echo "$traces_response" | jq '.data | length' 2>/dev/null || echo "0")
    
    if [ "$traces_count" = "0" ]; then
        print_color $YELLOW "  ⚠️  No traces found for $service (this might be expected if no traffic has been generated)"
        return 0
    fi
    
    print_color $GREEN "  ✅ Found $traces_count traces for $service"
    
    # Extract all span operation names and HTTP URLs from traces
    local operations=$(echo "$traces_response" | jq -r '.data[].spans[].operationName' 2>/dev/null | sort | uniq)
    local http_urls=$(echo "$traces_response" | jq -r '.data[].spans[].tags[]? | select(.key == "http.url" or .key == "http.target" or .key == "url.path") | .value' 2>/dev/null | sort | uniq)
    
    # Check for expected business endpoints
    local found_business_endpoints=()
    local missing_business_endpoints=()
    
    echo "  📊 Operations found:"
    echo "$operations" | while read -r op; do
        if [ ! -z "$op" ] && [ "$op" != "null" ]; then
            echo "    - $op"
        fi
    done
    
    # Check for business endpoints and unwanted patterns
    echo "  🌐 HTTP URLs found:"
    local found_business=false
    local found_unwanted=false
    
    if [ ! -z "$http_urls" ]; then
        echo "$http_urls" | while read -r url; do
            if [ ! -z "$url" ] && [ "$url" != "null" ]; then
                local is_business=false
                local is_unwanted=false
                
                # Check if it's a business endpoint
                for business_endpoint in "${EXPECTED_BUSINESS_ENDPOINTS[@]}"; do
                    if [[ "$url" =~ $business_endpoint ]]; then
                        is_business=true
                        found_business=true
                        break
                    fi
                done
                
                # Check if it's an unwanted pattern
                for unwanted in "${UNWANTED_PATTERNS[@]}"; do
                    if [[ "$url" == *"$unwanted"* ]]; then
                        is_unwanted=true
                        found_unwanted=true
                        break
                    fi
                done
                
                # Output with appropriate coloring
                if [ "$is_unwanted" = true ]; then
                    print_color $RED "    ❌ $url (UNWANTED: health/monitoring endpoint)"
                elif [ "$is_business" = true ]; then
                    print_color $GREEN "    ✅ $url (business endpoint)"
                else
                    echo "    - $url"
                fi
            fi
        done
    else
        echo "    (No HTTP URLs found)"
    fi
    
    # Check operations for unwanted patterns
    echo "  🔍 Checking operations for unwanted patterns:"
    echo "$operations" | while read -r op; do
        if [ ! -z "$op" ] && [ "$op" != "null" ]; then
            for unwanted in "${UNWANTED_PATTERNS[@]}"; do
                if [[ "$op" == *"$unwanted"* ]]; then
                    print_color $RED "    ❌ UNWANTED: Found unwanted pattern '$unwanted' in operation: $op"
                fi
            done
        fi
    done
    
    # Check for database spans (for backend services)
    if [[ "$service" != "frontend" ]]; then
        local db_spans=$(echo "$traces_response" | jq -r '.data[].spans[] | select(.tags[]?.key == "db.system") | .operationName' 2>/dev/null)
        if [ ! -z "$db_spans" ]; then
            print_color $GREEN "  ✅ Found database spans:"
            echo "$db_spans" | while read -r db_span; do
                if [ ! -z "$db_span" ] && [ "$db_span" != "null" ]; then
                    echo "    - $db_span"
                fi
            done
        else
            print_color $YELLOW "  ⚠️  No database spans found (might be expected if no DB operations occurred)"
        fi
    fi
    
    echo ""
}

# Function to generate test traffic
generate_test_traffic() {
    print_color $BLUE "🚀 Generating test traffic..."
    
    # Check if test-client-job exists
    if kubectl get job test-client -n $NAMESPACE &> /dev/null; then
        print_color $BLUE "  🗑️  Deleting existing test-client job..."
        kubectl delete job test-client -n $NAMESPACE
        sleep 5
    fi
    
    # Create test client job
    kubectl apply -f kubernetes/testing/test-client-job.yaml
    
    # Wait for job to complete
    print_color $BLUE "  ⏳ Waiting for test traffic generation to complete..."
    kubectl wait --for=condition=complete --timeout=300s job/test-client -n $NAMESPACE
    
    # Show job logs
    print_color $BLUE "  📋 Test client logs:"
    kubectl logs job/test-client -n $NAMESPACE | head -20
    
    print_color $GREEN "✅ Test traffic generation completed"
    
    # Wait a bit for traces to be processed
    print_color $BLUE "  ⏳ Waiting for traces to be processed..."
    sleep 10
}

# Function to run comprehensive validation
run_validation() {
    print_color $BLUE "🔍 Running comprehensive trace validation..."
    echo ""
    
    for service in "${SERVICES[@]}"; do
        validate_service_traces "$service"
    done
    
    print_color $GREEN "✅ Trace validation completed"
}

# Function to show summary
show_summary() {
    print_color $BLUE "📋 VALIDATION SUMMARY"
    echo ""
    print_color $BLUE "Expected BUSINESS endpoints (from e2e tests):"
    for endpoint in "${EXPECTED_BUSINESS_ENDPOINTS[@]}"; do
        echo "  ✅ $endpoint"
    done
    echo ""
    print_color $BLUE "Expected DATABASE operations:"
    for db_op in "${EXPECTED_DB_OPERATIONS[@]}"; do
        echo "  ✅ $db_op"
    done
    echo ""
    print_color $BLUE "UNWANTED patterns (should be filtered):"
    for unwanted in "${UNWANTED_PATTERNS[@]}"; do
        echo "  ❌ $unwanted"
    done
    echo ""
    print_color $YELLOW "⚠️  VALIDATION CRITERIA:"
    print_color $YELLOW "  1. NO health check or monitoring endpoints should appear in traces"
    print_color $YELLOW "  2. Business endpoints (login, register, accounts, transactions) SHOULD appear"
    print_color $YELLOW "  3. Database operations (SELECT, INSERT, UPDATE, DELETE) SHOULD appear for backend services"
    echo ""
    print_color $YELLOW "⚠️  If unwanted patterns appear, the OTel collector filter needs adjustment"
    print_color $YELLOW "⚠️  If business endpoints are missing, ensure test traffic includes those operations"
    echo ""
}

# Main execution
main() {
    print_color $BLUE "🚀 Banking App Trace Validation Script"
    print_color $BLUE "======================================"
    echo ""
    
    # Trap to ensure cleanup
    trap cleanup EXIT
    
    # Run checks
    check_kubectl
    check_services
    setup_jaeger_port_forward
    
    # Check if jq is available
    if ! command -v jq &> /dev/null; then
        print_color $RED "❌ jq is not installed. Please install jq to parse JSON responses."
        exit 1
    fi
    
    # Ask user if they want to generate test traffic
    read -p "$(echo -e ${YELLOW}Do you want to generate test traffic first? [y/N]: ${NC})" -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        generate_test_traffic
    fi
    
    # Run validation
    run_validation
    
    # Show summary
    show_summary
}

# Help function
show_help() {
    echo "Banking App Trace Validation Script"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help              Show this help message"
    echo "  -n, --namespace NAME    Kubernetes namespace (default: banking-app)"
    echo "  -p, --port PORT         Jaeger port for port-forward (default: 16686)"
    echo "  -t, --timeout SECONDS   Validation timeout (default: 300)"
    echo ""
    echo "Environment Variables:"
    echo "  NAMESPACE               Kubernetes namespace"
    echo "  JAEGER_PORT            Jaeger port for port-forward"
    echo "  VALIDATION_TIMEOUT     Validation timeout in seconds"
    echo "  TRACE_LOOKBACK         How far back to look for traces in microseconds (default: 3600000 = 1 hour)"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Run with defaults"
    echo "  $0 -n my-namespace -p 16687          # Use custom namespace and port"
    echo "  TRACE_LOOKBACK=1800000 $0            # Look back 30 minutes for traces"
    echo ""
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -p|--port)
            JAEGER_PORT="$2"
            shift 2
            ;;
        -t|--timeout)
            VALIDATION_TIMEOUT="$2"
            shift 2
            ;;
        *)
            print_color $RED "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Run main function
main