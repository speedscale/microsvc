#!/bin/bash

# Deploy Banking Application to Minikube
echo "🚀 Deploying Banking Application to Minikube..."

# Check if minikube is running
if ! minikube status &> /dev/null; then
    echo "❌ Minikube is not running. Please start minikube first:"
    echo "   minikube start"
    exit 1
fi

# Set docker environment to use minikube's docker daemon
echo "🔧 Setting up Docker environment for minikube..."
eval $(minikube docker-env)

# Build Docker images
echo "🏗️  Building Docker images..."
cd ../backend

# Build all services
echo "Building user-service..."
cd user-service && docker build -t banking-user-service:latest . && cd ..

echo "Building accounts-service..."
cd accounts-service && docker build -t banking-accounts-service:latest . && cd ..

echo "Building transactions-service..."
cd transactions-service && docker build -t banking-transactions-service:latest . && cd ..

echo "Building api-gateway..."
cd api-gateway && docker build -t banking-api-gateway:latest . && cd ..

cd ../kubernetes

# Apply Kubernetes manifests
echo "📦 Applying Kubernetes manifests..."
kubectl apply -k base/

# Wait for database to be ready
echo "⏳ Waiting for PostgreSQL to be ready..."
kubectl wait --for=condition=ready pod -l app=postgres -n banking-app --timeout=300s

# Wait for services to be ready
echo "⏳ Waiting for services to be ready..."
kubectl wait --for=condition=ready pod -l app=user-service -n banking-app --timeout=300s
kubectl wait --for=condition=ready pod -l app=accounts-service -n banking-app --timeout=300s
kubectl wait --for=condition=ready pod -l app=transactions-service -n banking-app --timeout=300s
kubectl wait --for=condition=ready pod -l app=api-gateway -n banking-app --timeout=300s

# Get service URL
echo "🌐 Getting service URL..."
API_GATEWAY_URL=$(minikube service api-gateway -n banking-app --url)

echo ""
echo "✅ Deployment completed successfully!"
echo ""
echo "🔗 Access the API Gateway at: $API_GATEWAY_URL"
echo ""
echo "📊 Useful commands:"
echo "   kubectl get pods -n banking-app"
echo "   kubectl get services -n banking-app"
echo "   kubectl logs -f deployment/api-gateway -n banking-app"
echo "   minikube service api-gateway -n banking-app --url"
echo ""
echo "🧹 To cleanup:"
echo "   kubectl delete namespace banking-app"