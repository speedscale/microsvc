#!/bin/bash

# Script to test frontend logging
# This script helps debug frontend logging issues by port forwarding and making test requests

set -e

echo "🔍 Testing Frontend Logging"
echo "=========================="

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl is not installed or not in PATH"
    exit 1
fi

# Check if the frontend pod exists
echo "📋 Checking frontend pod status..."
if ! kubectl get pods -n banking-app -l app=frontend | grep -q "Running"; then
    echo "❌ Frontend pod is not running. Please ensure the application is deployed."
    echo "   Run: kubectl get pods -n banking-app"
    exit 1
fi

echo "✅ Frontend pod is running"

# Check if the frontend ConfigMap exists
echo "📋 Checking frontend ConfigMap..."
if ! kubectl get configmap frontend-config -n banking-app &> /dev/null; then
    echo "❌ Frontend ConfigMap not found. Please ensure the ConfigMap is applied."
    echo "   Run: kubectl apply -f kubernetes/base/configmaps/app-config.yaml"
    exit 1
fi

echo "✅ Frontend ConfigMap exists"

# Display ConfigMap contents for debugging
echo "📄 Frontend ConfigMap contents:"
kubectl get configmap frontend-config -n banking-app -o yaml | grep -A 20 "data:"

# Get the frontend pod name
FRONTEND_POD=$(kubectl get pods -n banking-app -l app=frontend -o jsonpath='{.items[0].metadata.name}')
echo "🎯 Using frontend pod: $FRONTEND_POD"

echo ""
echo "🚀 Starting port forward to frontend pod..."
echo "   Local port: 3000"
echo "   Pod port: 3000"
echo "   Press Ctrl+C to stop port forwarding"
echo ""

# Function to cleanup port forward on exit
cleanup() {
    echo ""
    echo "🛑 Stopping port forward..."
    kill $PORT_FORWARD_PID 2>/dev/null || true
    exit 0
}

# Set up trap to cleanup on script exit
trap cleanup EXIT INT TERM

# Start port forward in background
kubectl port-forward -n banking-app $FRONTEND_POD 3000:3000 &
PORT_FORWARD_PID=$!

# Wait a moment for port forward to establish
sleep 3

echo "✅ Port forward established"
echo ""
echo "📝 Now you can:"
echo "   1. Check logs in another terminal: kubectl logs -n banking-app $FRONTEND_POD -f"
echo "   2. Access the frontend at: http://localhost:3000"
echo "   3. Make requests to trigger logging"
echo ""

# Verify environment variables are set in the pod
echo "🔍 Verifying environment variables in pod..."
kubectl exec -n banking-app $FRONTEND_POD -- env | grep -E "(NODE_ENV|OTEL_SERVICE_NAME|BACKEND_API_URL)" || echo "⚠️  Some environment variables not found"

echo ""
echo "🔍 Making test request to trigger logging..."

# Make a test request to trigger logging
if command -v curl &> /dev/null; then
    echo "📡 Making test request to http://localhost:3000..."
    curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" http://localhost:3000 || echo "⚠️  Request failed (this might be expected if the app is still starting)"
else
    echo "⚠️  curl not available, skipping test request"
fi

echo ""
echo "⏳ Waiting for port forward (press Ctrl+C to stop)..."
echo "   Check the logs in another terminal with:"
echo "   kubectl logs -n banking-app $FRONTEND_POD -f"

# Wait for port forward to continue running
wait $PORT_FORWARD_PID 