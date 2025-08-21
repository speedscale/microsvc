#!/bin/bash

set -ex

cd backend/user-service

# Test basic proxymock command
echo "Testing basic proxymock command..."
proxymock --version || echo "proxymock not found or failed"

# Test starting proxymock mock without the application
echo "Testing proxymock mock standalone..."
timeout 5 proxymock mock \
  --verbose \
  --in proxymock/recorded-2025-08-13/ \
  --no-out \
  --service postgres=65432 || echo "Proxymock mock test completed"

# Check if port 65432 is available
echo "Checking if port 65432 is available..."
lsof -i :65432 || echo "Port 65432 is available"

# Check Java version
echo "Java version:"
java -version