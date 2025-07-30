#!/bin/bash

# Pre-commit hook script for E2E test validation
# This script can be used with git hooks or manually before commits

set -e

echo "🔍 Pre-commit E2E validation..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

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

# Check if there are any frontend changes
if [ -n "$(git diff --cached --name-only | grep -E '^frontend/')" ] || [ -n "$(git diff --name-only | grep -E '^frontend/')" ]; then
    print_warning "Frontend changes detected. Running E2E validation..."
    
    # Run the validation script
    if ./scripts/validate-e2e.sh; then
        print_status "E2E validation passed! ✅"
    else
        print_error "E2E validation failed! ❌"
        print_error "Please fix the failing tests before committing"
        exit 1
    fi
else
    print_status "No frontend changes detected. Skipping E2E validation."
fi

print_status "Pre-commit validation completed successfully!" 