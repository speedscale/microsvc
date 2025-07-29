#!/bin/bash

# Script to run e2e tests with proper backend setup
set -e

echo "🧪 Running e2e tests..."

# Check if backend services are running
if ! docker-compose ps | grep -q "api-gateway"; then
    echo "⚠️  Backend services not running. Starting them..."
    ./scripts/start-e2e-backend.sh
fi

# Wait a bit for services to be fully ready
echo "⏳ Waiting for services to be fully ready..."
sleep 10

# Check if API Gateway is responding
echo "🔍 Checking API Gateway health..."
if ! curl -f http://localhost:8080/actuator/health > /dev/null 2>&1; then
    echo "❌ API Gateway is not responding. Please check the backend services."
    docker-compose logs api-gateway
    exit 1
fi

echo "✅ API Gateway is healthy!"

# Change to frontend directory
cd frontend

# Install dependencies if needed
if [ ! -d "node_modules" ]; then
    echo "📦 Installing dependencies..."
    npm install
fi

# Run e2e tests
echo "🚀 Starting e2e tests..."
npm run test:e2e

echo "✅ E2e tests completed!" 