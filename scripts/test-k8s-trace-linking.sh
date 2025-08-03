#!/bin/bash

# Test script to verify OpenTelemetry trace linking in Kubernetes
# This script makes requests to the application and provides instructions for checking traces

set -e

NAMESPACE="banking-app"

echo "🔍 Testing OpenTelemetry Trace Linking in Kubernetes"
echo "===================================================="

# Check if namespace exists
if ! kubectl get namespace $NAMESPACE > /dev/null 2>&1; then
    echo "❌ Namespace '$NAMESPACE' does not exist. Please deploy the application first:"
    echo "   kubectl apply -k kubernetes/base"
    echo "   kubectl apply -k kubernetes/observability"
    exit 1
fi

echo "✅ Namespace '$NAMESPACE' exists"

# Check if services are running
echo "📋 Checking if services are running..."

if ! kubectl get deployment api-gateway -n $NAMESPACE > /dev/null 2>&1; then
    echo "❌ API Gateway deployment not found. Please deploy the application first."
    exit 1
fi

# Wait for services to be ready
echo "⏳ Waiting for services to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/api-gateway -n $NAMESPACE
kubectl wait --for=condition=available --timeout=300s deployment/user-service -n $NAMESPACE
kubectl wait --for=condition=available --timeout=300s deployment/accounts-service -n $NAMESPACE
kubectl wait --for=condition=available --timeout=300s deployment/transactions-service -n $NAMESPACE

echo "✅ All services are ready"

# Get service URLs
API_GATEWAY_URL=$(kubectl get svc api-gateway -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
if [ -z "$API_GATEWAY_URL" ]; then
    API_GATEWAY_URL=$(kubectl get svc api-gateway -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
fi

if [ -z "$API_GATEWAY_URL" ]; then
    echo "⚠️  Could not determine API Gateway external IP. Using port-forward..."
    # Start port-forward in background
    kubectl port-forward svc/api-gateway 8080:80 -n $NAMESPACE &
    PF_PID=$!
    sleep 5
    API_GATEWAY_URL="http://localhost:8080"
    echo "✅ Using port-forward at $API_GATEWAY_URL"
else
    API_GATEWAY_URL="http://$API_GATEWAY_URL"
    echo "✅ API Gateway available at $API_GATEWAY_URL"
fi

# Make some test requests to generate traces
echo ""
echo "🚀 Generating test traffic to create traces..."

# Test user registration
echo "📝 Testing user registration..."
curl -s -X POST $API_GATEWAY_URL/api/users/register \
  -H "Content-Type: application/json" \
  -d '{
    "username": "testuser",
    "email": "test@example.com",
    "password": "password123",
    "firstName": "Test",
    "lastName": "User"
  }' > /dev/null

# Test login
echo "🔐 Testing login..."
TOKEN=$(curl -s -X POST $API_GATEWAY_URL/api/users/login \
  -H "Content-Type: application/json" \
  -d '{
    "username": "testuser",
    "password": "password123"
  }' | jq -r '.token')

if [ "$TOKEN" != "null" ] && [ -n "$TOKEN" ]; then
    echo "✅ Login successful, got token"
    
    # Test getting accounts
    echo "💰 Testing accounts API..."
    curl -s -X GET $API_GATEWAY_URL/api/accounts \
      -H "Authorization: Bearer $TOKEN" > /dev/null
    
    # Test getting transactions
    echo "📊 Testing transactions API..."
    curl -s -X GET $API_GATEWAY_URL/api/transactions \
      -H "Authorization: Bearer $TOKEN" > /dev/null
    
    # Test creating an account
    echo "🏦 Testing account creation..."
    curl -s -X POST $API_GATEWAY_URL/api/accounts \
      -H "Authorization: Bearer $TOKEN" \
      -H "Content-Type: application/json" \
      -d '{
        "accountType": "CHECKING",
        "initialBalance": 1000.00
      }' > /dev/null
else
    echo "⚠️  Login failed, but that's okay for trace testing"
fi

echo ""
echo "✅ Test traffic generated successfully!"
echo ""

# Clean up port-forward if we started it
if [ ! -z "$PF_PID" ]; then
    echo "🧹 Cleaning up port-forward..."
    kill $PF_PID 2>/dev/null || true
fi

echo "🔍 Next Steps to Verify Trace Linking:"
echo "======================================"
echo ""
echo "1. Start Jaeger port-forward:"
echo "   kubectl port-forward svc/jaeger 16686:16686 -n $NAMESPACE"
echo ""
echo "2. Open Jaeger UI: http://localhost:16686"
echo ""
echo "3. Look for traces with these characteristics:"
echo "   - Traces that span multiple services (frontend → api-gateway → backend-service)"
echo "   - API Gateway traces showing calls to backend services"
echo "   - Backend service traces showing database calls"
echo "   - Consistent trace IDs across related spans"
echo ""
echo "4. Check service logs for trace IDs:"
echo "   kubectl logs -f deployment/api-gateway -n $NAMESPACE | grep -E '\[[a-f0-9]{32},[a-f0-9]{16}\]'"
echo "   kubectl logs -f deployment/accounts-service -n $NAMESPACE | grep -E '\[[a-f0-9]{32},[a-f0-9]{16}\]'"
echo "   kubectl logs -f deployment/transactions-service -n $NAMESPACE | grep -E '\[[a-f0-9]{32},[a-f0-9]{16}\]'"
echo ""
echo "5. Check OpenTelemetry environment variables:"
echo "   kubectl exec -it deployment/api-gateway -n $NAMESPACE -- env | grep OTEL"
echo "   kubectl exec -it deployment/accounts-service -n $NAMESPACE -- env | grep OTEL"
echo ""
echo "6. Verify Jaeger connectivity:"
echo "   kubectl exec -it deployment/api-gateway -n $NAMESPACE -- curl -v http://jaeger:4318"
echo ""
echo "7. Expected trace flow:"
echo "   Frontend → API Gateway → Backend Service → Database"
echo ""
echo "8. If traces are not linking:"
echo "   - Check ConfigMaps: kubectl describe configmap app-config -n $NAMESPACE"
echo "   - Verify all services have OTEL environment variables"
echo "   - Ensure Jaeger is accessible from all services"
echo "   - Check that OTEL_PROPAGATORS=tracecontext is set"
echo "   - Verify OTEL_TRACES_SAMPLER=always_on is set"
echo ""
echo "📚 For more details, see: kubernetes/OTEL_KUBERNETES_SETUP.md" 