#!/bin/bash

# Quick E2E test runner for debugging
set -e

echo "🎭 Running Quick E2E Test (Chromium only)..."

# Kill any existing dev servers
pkill -f "next dev" || true
pkill -f "playwright test" || true

# Start the dev server in background
echo "🚀 Starting dev server..."
npm run dev &
DEV_PID=$!

# Wait for server to be ready
sleep 5

# Wait for dev server to be accessible
echo "⏳ Waiting for server to be ready..."
timeout 30 bash -c 'until curl -s http://localhost:3000 > /dev/null; do sleep 1; done' || {
    echo "❌ Dev server failed to start"
    kill $DEV_PID 2>/dev/null || true
    exit 1
}

echo "✅ Dev server ready!"

# Run the test on chromium only
echo "🧪 Running E2E tests..."
npx playwright test --project=chromium --headed

# Cleanup
echo "🧹 Cleaning up..."
kill $DEV_PID 2>/dev/null || true

echo "✅ Quick E2E test complete!"