#!/bin/bash

set -ex

cd backend/user-service

# Test basic proxymock command
echo "Testing basic proxymock command..."
proxymock version || echo "proxymock not found or failed"

# Test starting proxymock mock without the application
echo "Testing proxymock mock standalone..."
timeout 5 proxymock mock \
  --verbose \
  --in "${PROXYMOCK_DIR:-proxymock/recorded-complete}/" \
  --no-out \
  || echo "Proxymock mock test completed"

# Postgres mock listens on 5432 (ensure host :5432 is free)
echo "Checking if port 5432 is available..."
lsof -i :5432 || echo "Port 5432 is available"

# Check Java version
echo "Java version:"
java -version