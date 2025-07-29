#!/bin/bash

# Script to start backend services for e2e testing
set -e

echo "🚀 Starting backend services for e2e testing..."

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker and try again."
    exit 1
fi

# Stop any existing containers
echo "🛑 Stopping existing containers..."
docker-compose down

# Start only the backend services (no frontend)
echo "🔧 Starting backend services..."
docker-compose up -d postgres user-service accounts-service transactions-service api-gateway

# Wait for services to be healthy
echo "⏳ Waiting for services to be ready..."
timeout=120
elapsed=0

while [ $elapsed -lt $timeout ]; do
    if docker-compose ps | grep -q "healthy"; then
        echo "✅ All services are healthy!"
        break
    fi
    echo "⏳ Waiting for services to be healthy... ($elapsed/$timeout seconds)"
    sleep 5
    elapsed=$((elapsed + 5))
done

if [ $elapsed -ge $timeout ]; then
    echo "❌ Timeout waiting for services to be healthy"
    docker-compose logs
    exit 1
fi

echo "🎉 Backend services are ready for e2e testing!"
echo "📊 API Gateway: http://localhost:8080"
echo "👤 User Service: http://localhost:8081"
echo "💰 Accounts Service: http://localhost:8082"
echo "💳 Transactions Service: http://localhost:8083"
echo "🗄️  Database: localhost:5432" 