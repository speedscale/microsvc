#!/bin/bash

# Business Traffic Generator Script
# Generates real business API traffic for trace validation

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE=${NAMESPACE:-banking-app}
API_GATEWAY_URL=""
TEST_USER_PREFIX="testuser"
TIMESTAMP=$(date +%s)

print_color() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Setup port forward to API gateway
setup_api_gateway() {
    print_color $BLUE "🔍 Setting up API Gateway connection..."
    
    # Check if port 8080 is already in use
    if lsof -i :8080 &> /dev/null; then
        print_color $YELLOW "⚠️  Port 8080 is already in use, assuming API Gateway is accessible"
        API_GATEWAY_URL="http://localhost:8080"
    else
        print_color $BLUE "🚀 Starting port forward to API Gateway..."
        kubectl port-forward -n $NAMESPACE service/api-gateway 8080:80 &
        PORT_FORWARD_PID=$!
        sleep 5
        API_GATEWAY_URL="http://localhost:8080"
        
        if ! curl -s --max-time 5 "$API_GATEWAY_URL/health" > /dev/null 2>&1; then
            print_color $RED "❌ Failed to connect to API Gateway"
            kill $PORT_FORWARD_PID 2>/dev/null || true
            exit 1
        fi
    fi
    
    print_color $GREEN "✅ API Gateway is accessible at $API_GATEWAY_URL"
}

# Cleanup function
cleanup() {
    if [ ! -z "$PORT_FORWARD_PID" ]; then
        print_color $BLUE "🧹 Cleaning up port forward..."
        kill $PORT_FORWARD_PID 2>/dev/null || true
    fi
}

# Function to make API call and report result
api_call() {
    local method=$1
    local endpoint=$2
    local data=$3
    local token=$4
    
    local headers=""
    if [ ! -z "$token" ]; then
        headers="-H \"Authorization: Bearer $token\""
    fi
    
    local cmd="curl -s -X $method"
    if [ ! -z "$data" ]; then
        cmd="$cmd -H \"Content-Type: application/json\" -d '$data'"
    fi
    if [ ! -z "$headers" ]; then
        cmd="$cmd $headers"
    fi
    cmd="$cmd \"$API_GATEWAY_URL$endpoint\""
    
    print_color $BLUE "  📡 $method $endpoint"
    
    local response=$(eval $cmd 2>/dev/null)
    local status=$?
    
    if [ $status -eq 0 ]; then
        if echo "$response" | jq . > /dev/null 2>&1; then
            print_color $GREEN "    ✅ Success"
            echo "$response"
        else
            print_color $GREEN "    ✅ Success (non-JSON response)"
        fi
    else
        print_color $RED "    ❌ Failed"
    fi
}

# Generate user registration traffic
generate_user_traffic() {
    print_color $BLUE "👤 Generating USER service traffic..."
    
    local username="${TEST_USER_PREFIX}${TIMESTAMP}"
    local email="test${TIMESTAMP}@example.com"
    local password="TestPassword123!"
    
    # Check username availability
    api_call "GET" "/api/users/check-username?username=$username" "" ""
    
    # Check email availability  
    api_call "GET" "/api/users/check-email?email=$email" "" ""
    
    # Register new user
    local register_data='{"username":"'$username'","email":"'$email'","password":"'$password'"}'
    local register_response=$(api_call "POST" "/api/users/register" "$register_data" "")
    
    # Login
    local login_data='{"usernameOrEmail":"'$username'","password":"'$password'"}'
    local login_response=$(curl -s -X POST -H "Content-Type: application/json" \
        -d "$login_data" "$API_GATEWAY_URL/api/users/login" 2>/dev/null)
    
    local token=""
    if echo "$login_response" | jq . > /dev/null 2>&1; then
        token=$(echo "$login_response" | jq -r '.token // empty')
        if [ ! -z "$token" ]; then
            print_color $GREEN "    ✅ Login successful, got token"
        else
            print_color $YELLOW "    ⚠️  Login succeeded but no token in response"
        fi
    fi
    
    # Get profile (requires auth)
    if [ ! -z "$token" ]; then
        api_call "GET" "/api/users/profile" "" "$token"
    fi
    
    echo "$token"
}

# Generate account traffic
generate_account_traffic() {
    local token=$1
    print_color $BLUE "💰 Generating ACCOUNTS service traffic..."
    
    if [ -z "$token" ]; then
        print_color $YELLOW "  ⚠️  No auth token, skipping authenticated endpoints"
        return
    fi
    
    # Create account
    local account_data='{"accountType":"CHECKING","initialBalance":1000.00}'
    local account_response=$(curl -s -X POST -H "Content-Type: application/json" \
        -H "Authorization: Bearer $token" \
        -d "$account_data" "$API_GATEWAY_URL/api/accounts" 2>/dev/null)
    
    local account_id=""
    if echo "$account_response" | jq . > /dev/null 2>&1; then
        account_id=$(echo "$account_response" | jq -r '.id // empty')
        if [ ! -z "$account_id" ]; then
            print_color $GREEN "    ✅ Created account: $account_id"
        fi
    fi
    
    # Get all accounts
    api_call "GET" "/api/accounts" "" "$token"
    
    if [ ! -z "$account_id" ]; then
        # Get specific account
        api_call "GET" "/api/accounts/$account_id" "" "$token"
        
        # Get account balance
        api_call "GET" "/api/accounts/$account_id/balance" "" "$token"
    fi
    
    echo "$account_id"
}

# Generate transaction traffic
generate_transaction_traffic() {
    local token=$1
    local account_id=$2
    print_color $BLUE "💸 Generating TRANSACTIONS service traffic..."
    
    if [ -z "$token" ] || [ -z "$account_id" ]; then
        print_color $YELLOW "  ⚠️  No auth token or account ID, skipping transaction endpoints"
        return
    fi
    
    # Deposit
    local deposit_data='{"accountId":"'$account_id'","amount":100.00,"description":"Test deposit"}'
    api_call "POST" "/api/transactions/deposit" "$deposit_data" "$token"
    
    # Withdraw
    local withdraw_data='{"accountId":"'$account_id'","amount":50.00,"description":"Test withdrawal"}'
    api_call "POST" "/api/transactions/withdraw" "$withdraw_data" "$token"
    
    # Get all transactions
    api_call "GET" "/api/transactions?accountId=$account_id" "" "$token"
    
    # Create another account for transfer
    local account2_data='{"accountType":"SAVINGS","initialBalance":500.00}'
    local account2_response=$(curl -s -X POST -H "Content-Type: application/json" \
        -H "Authorization: Bearer $token" \
        -d "$account2_data" "$API_GATEWAY_URL/api/accounts" 2>/dev/null)
    
    local account2_id=""
    if echo "$account2_response" | jq . > /dev/null 2>&1; then
        account2_id=$(echo "$account2_response" | jq -r '.id // empty')
    fi
    
    if [ ! -z "$account2_id" ]; then
        # Transfer between accounts
        local transfer_data='{"fromAccountId":"'$account_id'","toAccountId":"'$account2_id'","amount":25.00,"description":"Test transfer"}'
        api_call "POST" "/api/transactions/transfer" "$transfer_data" "$token"
    fi
}

# Generate comprehensive business traffic
generate_all_traffic() {
    print_color $BLUE "🚀 GENERATING COMPREHENSIVE BUSINESS TRAFFIC"
    print_color $BLUE "=========================================="
    echo ""
    
    # User operations
    local token=$(generate_user_traffic)
    echo ""
    
    # Account operations
    local account_id=""
    if [ ! -z "$token" ]; then
        account_id=$(generate_account_traffic "$token")
        echo ""
    fi
    
    # Transaction operations
    if [ ! -z "$token" ] && [ ! -z "$account_id" ]; then
        generate_transaction_traffic "$token" "$account_id"
        echo ""
    fi
    
    print_color $GREEN "✅ Business traffic generation completed!"
    print_color $BLUE ""
    print_color $BLUE "📊 Traffic Summary:"
    print_color $BLUE "  - User registration and login"
    print_color $BLUE "  - Account creation and queries"
    print_color $BLUE "  - Deposits, withdrawals, and transfers"
    print_color $BLUE ""
    print_color $YELLOW "⏳ Wait 10-15 seconds for traces to be processed,"
    print_color $YELLOW "   then run: ./scripts/validate-traces.sh"
}

# Main execution
main() {
    print_color $BLUE "🚀 Banking App Business Traffic Generator"
    print_color $BLUE "=========================================="
    echo ""
    
    # Check prerequisites
    if ! command -v kubectl &> /dev/null; then
        print_color $RED "❌ kubectl is not installed"
        exit 1
    fi
    
    if ! command -v curl &> /dev/null; then
        print_color $RED "❌ curl is not installed"
        exit 1
    fi
    
    if ! command -v jq &> /dev/null; then
        print_color $YELLOW "⚠️  jq is not installed (JSON parsing will be limited)"
    fi
    
    # Check namespace
    if ! kubectl get ns $NAMESPACE &> /dev/null; then
        print_color $RED "❌ Namespace '$NAMESPACE' not found"
        exit 1
    fi
    
    # Trap to ensure cleanup
    trap cleanup EXIT
    
    # Setup API Gateway connection
    setup_api_gateway
    
    # Generate traffic
    generate_all_traffic
}

# Help function
show_help() {
    echo "Banking App Business Traffic Generator"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help              Show this help message"
    echo "  -n, --namespace NAME    Kubernetes namespace (default: banking-app)"
    echo ""
    echo "This script generates real business API traffic including:"
    echo "  - User registration and authentication"
    echo "  - Account creation and management"
    echo "  - Financial transactions (deposits, withdrawals, transfers)"
    echo ""
    echo "The generated traffic helps validate that:"
    echo "  1. Business operations appear in traces"
    echo "  2. Health check endpoints are properly filtered"
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