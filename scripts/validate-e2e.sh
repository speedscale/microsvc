#!/bin/bash

# Script to validate E2E tests locally using the same configuration as CI
# This ensures that what works locally will work in the pipeline

set -e

echo "🧪 Validating E2E tests with CI configuration..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check if we're in the right directory
if [ ! -f "frontend/package.json" ]; then
    print_error "This script must be run from the project root directory"
    exit 1
fi

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    print_error "Node.js is not installed"
    exit 1
fi

# Check if npm is installed
if ! command -v npm &> /dev/null; then
    print_error "npm is not installed"
    exit 1
fi

print_status "Prerequisites check passed"

# Change to frontend directory
cd frontend

# Check if dependencies are installed
if [ ! -d "node_modules" ]; then
    print_warning "Dependencies not found. Installing..."
    npm ci
else
    print_status "Dependencies already installed"
fi

# Check if Playwright is installed
if [ ! -d "node_modules/@playwright" ]; then
    print_warning "Playwright not found. Installing..."
    npx playwright install --with-deps chromium
else
    print_status "Playwright already installed"
fi

# Create test results directory
mkdir -p test-results

print_status "Starting E2E tests with CI configuration..."

# Run the tests with the same configuration as CI
if npm run test:e2e:ci; then
    print_status "E2E tests passed! ✅"
    print_status "Your changes are ready for CI"
    
    # Show test results summary
    if [ -f "test-results/results.json" ]; then
        echo ""
        print_status "Test Results Summary:"
        echo "======================"
        # Extract and display test summary from results.json
        if command -v jq &> /dev/null; then
            jq -r '.stats | "Total: \(.total), Passed: \(.passed), Failed: \(.failed), Skipped: \(.skipped)"' test-results/results.json
        else
            echo "Install jq to see detailed test results"
        fi
    fi
    
    exit 0
else
    print_error "E2E tests failed! ❌"
    print_error "Please fix the failing tests before committing"
    
    # Show helpful information
    echo ""
    print_warning "Debugging tips:"
    echo "1. Run 'npm run test:e2e:headed' to see the browser"
    echo "2. Run 'npm run test:e2e:ui' for interactive debugging"
    echo "3. Check the test results in frontend/playwright-report/"
    echo "4. Check the test results in frontend/test-results/"
    
    exit 1
fi 