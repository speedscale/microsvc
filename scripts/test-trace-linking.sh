#!/bin/bash

# Test script to verify OpenTelemetry trace linking
# This script makes requests to the application and provides instructions for checking traces

set -e

echo "🔍 Testing OpenTelemetry Trace Linking"
echo "======================================"

# Check if services are running
echo "📋 Checking if services are running..."

if ! curl -s http://localhost:8080/actuator/health > /dev/null; then
    echo "❌ API Gateway is not running. Please start the application first:"
    echo "   docker-compose up -d"
    exit 1
fi

echo "✅ API Gateway is running"

# Make some test requests to generate traces
echo ""
echo "🚀 Generating test traffic to create traces..."

# Test user registration
echo "📝 Testing user registration..."
curl -s -X POST http://localhost:8080/api/users/register \
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
TOKEN=$(curl -s -X POST http://localhost:8080/api/users/login \
  -H "Content-Type: application/json" \
  -d '{
    "username": "testuser",
    "password": "password123"
  }' | jq -r '.token')

if [ "$TOKEN" != "null" ] && [ -n "$TOKEN" ]; then
    echo "✅ Login successful, got token"
    
    # Test getting accounts
    echo "💰 Testing accounts API..."
    curl -s -X GET http://localhost:8080/api/accounts \
      -H "Authorization: Bearer $TOKEN" > /dev/null
    
    # Test getting transactions
    echo "📊 Testing transactions API..."
    curl -s -X GET http://localhost:8080/api/transactions \
      -H "Authorization: Bearer $TOKEN" > /dev/null
    
    # Test creating an account
    echo "🏦 Testing account creation..."
    curl -s -X POST http://localhost:8080/api/accounts \
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
echo "🔍 Next Steps to Verify Trace Linking:"
echo "======================================"
echo ""
echo "1. Open Jaeger UI: http://localhost:16686"
echo ""
echo "2. Look for traces with these characteristics:"
echo "   - Traces that span multiple services (frontend → api-gateway → backend-service)"
echo "   - API Gateway traces showing calls to backend services"
echo "   - Backend service traces showing database calls"
echo "   - Consistent trace IDs across related spans"
echo ""
echo "3. Check service logs for trace IDs:"
echo "   docker-compose logs api-gateway | grep -E '\[[a-f0-9]{32},[a-f0-9]{16}\]'"
echo "   docker-compose logs accounts-service | grep -E '\[[a-f0-9]{32},[a-f0-9]{16}\]'"
echo "   docker-compose logs transactions-service | grep -E '\[[a-f0-9]{32},[a-f0-9]{16}\]'"
echo ""
echo "4. Expected trace flow:"
echo "   Frontend → API Gateway → Backend Service → Database"
echo ""
echo "5. If traces are not linking:"
echo "   - Check that all services have OTEL environment variables"
echo "   - Verify Jaeger is accessible from all services"
echo "   - Ensure OTEL_PROPAGATORS=w3c is set"
echo "   - Check that OTEL_TRACES_SAMPLER=always_on is set"
echo ""
echo "📚 For more details, see: OTEL_TRACING_SETUP.md" 