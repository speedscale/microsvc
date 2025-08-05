#!/bin/bash

# Test Script for Trace Filtering Configuration
# This script helps test the OTel collector filtering and health check changes

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

NAMESPACE=${NAMESPACE:-banking-app}

print_color() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

print_header() {
    local title=$1
    echo ""
    print_color $BLUE "======================================"
    print_color $BLUE "$title"
    print_color $BLUE "======================================"
}

# Function to wait for deployment rollout
wait_for_rollout() {
    local deployment=$1
    print_color $BLUE "⏳ Waiting for $deployment rollout to complete..."
    kubectl rollout status deployment/$deployment -n $NAMESPACE --timeout=300s
    print_color $GREEN "✅ $deployment rollout completed"
}

# Function to restart a deployment
restart_deployment() {
    local deployment=$1
    print_color $BLUE "🔄 Restarting $deployment..."
    kubectl rollout restart deployment/$deployment -n $NAMESPACE
    wait_for_rollout $deployment
}

# Function to test health endpoints
test_health_endpoints() {
    print_header "TESTING HEALTH ENDPOINTS"
    
    # Test each service health endpoint
    local services=("frontend:3000:/api/healthz" "api-gateway:80:/actuator/health" "user-service:80:/actuator/health" "accounts-service:80:/actuator/health" "transactions-service:80:/actuator/health")
    
    for service_info in "${services[@]}"; do
        IFS=':' read -r service port path <<< "$service_info"
        
        print_color $BLUE "🔍 Testing $service health endpoint..."
        
        # Port forward to the service
        kubectl port-forward -n $NAMESPACE service/$service $port:$port &
        PORT_FORWARD_PID=$!
        sleep 3
        
        # Test the health endpoint
        if curl -s --max-time 5 "http://localhost:$port$path" > /dev/null; then
            print_color $GREEN "  ✅ $service$path is accessible"
        else
            print_color $RED "  ❌ $service$path is not accessible"
        fi
        
        # Cleanup port forward
        kill $PORT_FORWARD_PID 2>/dev/null || true
        sleep 1
    done
}

# Function to apply configuration changes
apply_changes() {
    print_header "APPLYING CONFIGURATION CHANGES"
    
    print_color $BLUE "📋 Applying updated configurations..."
    
    # Apply the OTel collector changes
    kubectl apply -f kubernetes/observability/otel-collector.yaml
    print_color $GREEN "✅ Applied OTel collector configuration"
    
    # Apply the frontend deployment changes
    kubectl apply -f kubernetes/base/deployments/frontend-deployment.yaml
    print_color $GREEN "✅ Applied frontend deployment configuration"
    
    # Wait for rollouts
    wait_for_rollout "otel-collector"
    wait_for_rollout "frontend"
    
    print_color $GREEN "✅ All configuration changes applied successfully"
}

# Function to generate clean test traffic
generate_clean_traffic() {
    print_header "GENERATING CLEAN TEST TRAFFIC"
    
    print_color $BLUE "🚀 Starting clean test traffic generation..."
    
    # Remove existing test job if it exists
    kubectl delete job test-client -n $NAMESPACE 2>/dev/null || true
    sleep 5
    
    # Create and run test job
    kubectl apply -f kubernetes/testing/test-client-job.yaml
    
    # Wait for completion
    kubectl wait --for=condition=complete --timeout=300s job/test-client -n $NAMESPACE
    
    print_color $GREEN "✅ Clean test traffic generated"
}

# Function to check OTel collector logs
check_otel_logs() {
    print_header "CHECKING OTEL COLLECTOR LOGS"
    
    local otel_pod=$(kubectl get pods -n $NAMESPACE -l component=otel-collector -o jsonpath='{.items[0].metadata.name}')
    
    if [ -z "$otel_pod" ]; then
        print_color $RED "❌ OTel collector pod not found"
        return 1
    fi
    
    print_color $BLUE "📋 Recent OTel collector logs:"
    kubectl logs $otel_pod -n $NAMESPACE --tail=50 | grep -E "(filter|drop|exclude)" || print_color $YELLOW "No filter-related logs found"
}

# Function to verify pods are healthy
verify_pods_healthy() {
    print_header "VERIFYING POD HEALTH"
    
    local services=("frontend" "api-gateway" "user-service" "accounts-service" "transactions-service" "otel-collector")
    
    for service in "${services[@]}"; do
        local ready_replicas=$(kubectl get deployment $service -n $NAMESPACE -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
        local desired_replicas=$(kubectl get deployment $service -n $NAMESPACE -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "1")
        
        if [ "$ready_replicas" = "$desired_replicas" ] && [ "$ready_replicas" != "0" ]; then
            print_color $GREEN "  ✅ $service: $ready_replicas/$desired_replicas ready"
        else
            print_color $RED "  ❌ $service: $ready_replicas/$desired_replicas ready"
        fi
    done
}

# Function to run the trace validation
run_trace_validation() {
    print_header "RUNNING TRACE VALIDATION"
    
    print_color $BLUE "🔍 Running comprehensive trace validation..."
    ./scripts/validate-traces.sh
}

# Function to reset environment
reset_environment() {
    print_header "RESETTING ENVIRONMENT"
    
    print_color $YELLOW "⚠️  This will restart all services to ensure clean state"
    read -p "$(echo -e ${YELLOW}Continue with environment reset? [y/N]: ${NC})" -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_color $BLUE "Skipping environment reset"
        return 0
    fi
    
    local services=("frontend" "api-gateway" "user-service" "accounts-service" "transactions-service" "otel-collector")
    
    for service in "${services[@]}"; do
        restart_deployment $service
    done
    
    # Clean up any existing test jobs
    kubectl delete job test-client -n $NAMESPACE 2>/dev/null || true
    
    print_color $GREEN "✅ Environment reset completed"
}

# Function to show current configuration status
show_config_status() {
    print_header "CURRENT CONFIGURATION STATUS"
    
    print_color $BLUE "📋 Health Check Endpoints:"
    echo "  frontend: /api/healthz (port 3000)"
    echo "  api-gateway: /actuator/health (port 80)"
    echo "  user-service: /actuator/health (port 80)"
    echo "  accounts-service: /actuator/health (port 80)"
    echo "  transactions-service: /actuator/health (port 80)"
    echo ""
    
    print_color $BLUE "📋 OTel Filter Patterns:"
    echo "  URL patterns: .*(actuator|prometheus|healthz|metrics).*"
    echo "  Span names: GET /actuator/.*, GET /api/healthz, GET /healthz, GET /metrics"
    echo ""
    
    print_color $BLUE "📋 Expected Business Spans:"
    echo "  ✅ HTTP GET/POST/PUT/DELETE (business operations)"
    echo "  ✅ PostgreSQL operations (SELECT, INSERT, UPDATE, DELETE)"
    echo "  ✅ Service-to-service calls"
    echo ""
    
    print_color $BLUE "📋 Filtered (Unwanted) Spans:"
    echo "  ❌ /actuator/health, /actuator/prometheus, /actuator/info, /actuator/metrics"
    echo "  ❌ /api/healthz, /healthz, /metrics"
    echo "  ❌ Prometheus scrape requests"
    echo ""
}

# Main menu function
show_menu() {
    print_header "TRACE FILTERING TEST MENU"
    echo "Select an option:"
    echo "1) Show current configuration status"
    echo "2) Apply configuration changes"
    echo "3) Reset environment (restart all services)"
    echo "4) Test health endpoints"
    echo "5) Generate clean test traffic"
    echo "6) Check OTel collector logs"
    echo "7) Verify pods are healthy"
    echo "8) Run comprehensive trace validation"
    echo "9) Full test cycle (reset → apply → generate → validate)"
    echo "0) Exit"
    echo ""
}

# Function to run full test cycle
full_test_cycle() {
    print_header "RUNNING FULL TEST CYCLE"
    
    print_color $BLUE "This will:"
    print_color $BLUE "1. Reset the environment"
    print_color $BLUE "2. Apply configuration changes"
    print_color $BLUE "3. Generate test traffic"
    print_color $BLUE "4. Validate traces"
    echo ""
    
    read -p "$(echo -e ${YELLOW}Continue with full test cycle? [y/N]: ${NC})" -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_color $BLUE "Cancelled full test cycle"
        return 0
    fi
    
    reset_environment
    apply_changes
    verify_pods_healthy
    test_health_endpoints
    generate_clean_traffic
    check_otel_logs
    run_trace_validation
    
    print_color $GREEN "✅ Full test cycle completed!"
}

# Main execution
main() {
    # Check prerequisites
    if ! command -v kubectl &> /dev/null; then
        print_color $RED "❌ kubectl is not installed"
        exit 1
    fi
    
    if ! kubectl get ns $NAMESPACE &> /dev/null; then
        print_color $RED "❌ Namespace '$NAMESPACE' not found"
        exit 1
    fi
    
    # Make sure validation script is executable
    chmod +x scripts/validate-traces.sh
    
    while true; do
        show_menu
        read -p "$(echo -e ${BLUE}Enter your choice [0-9]: ${NC})" choice
        echo ""
        
        case $choice in
            1)
                show_config_status
                ;;
            2)
                apply_changes
                ;;
            3)
                reset_environment
                ;;
            4)
                test_health_endpoints
                ;;
            5)
                generate_clean_traffic
                ;;
            6)
                check_otel_logs
                ;;
            7)
                verify_pods_healthy
                ;;
            8)
                run_trace_validation
                ;;
            9)
                full_test_cycle
                ;;
            0)
                print_color $GREEN "👋 Goodbye!"
                exit 0
                ;;
            *)
                print_color $RED "❌ Invalid option. Please try again."
                ;;
        esac
        
        echo ""
        read -p "$(echo -e ${BLUE}Press Enter to continue...${NC})"
    done
}

# Help function
show_help() {
    echo "Trace Filtering Test Script"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help              Show this help message"
    echo "  -n, --namespace NAME    Kubernetes namespace (default: banking-app)"
    echo ""
    echo "Environment Variables:"
    echo "  NAMESPACE               Kubernetes namespace"
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
        *)
            print_color $RED "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Run main function
main