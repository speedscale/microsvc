#!/bin/bash

# Run Playwright E2E tests for the Banking Application
# This script simulates real user interactions across all frontend pages

set -e

echo "🎭 Starting Playwright E2E Tests..."
echo "=================================="

# Determine URLs based on environment
if [[ -n "$BASE_URL" ]]; then
    echo "🔗 Using BASE_URL: $BASE_URL"
    # Extract base URL for API health check (same as frontend in Kubernetes)
    API_CHECK_URL="${BASE_URL}/actuator/health"
else
    echo "🔗 Using default URLs (local development)"
    API_CHECK_URL="http://localhost:8080/actuator/health"
fi

# Check if backend services are running
if ! curl -s "$API_CHECK_URL" > /dev/null 2>&1; then
    echo "⚠️  Warning: Backend services not detected at $API_CHECK_URL"
    echo "   For Kubernetes: make sure port-forward is running: kubectl port-forward -n banking-app service/frontend-nodeport 30080:80"
    echo "   For local dev: make sure to run 'docker-compose up' first"
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Install Playwright browsers if needed
echo "📦 Ensuring Playwright browsers are installed..."
npx playwright install --with-deps chromium

# Run the tests (Chromium only)
echo "🚀 Running E2E tests (Chromium only)..."
npx playwright test

echo "✅ E2E tests complete!"
echo ""
echo "View test results:"
echo "  - HTML Report: npx playwright show-report"
echo "  - Test Videos: test-results/"