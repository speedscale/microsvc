#!/bin/bash
set -e

# Install Proxymock for CI environments
# This script installs and initializes proxymock following the Speedscale pattern

echo "Installing Proxymock..."

# Create .speedscale directory
mkdir -p .speedscale

# Download and install proxymock
curl -Lfs https://downloads.speedscale.com/proxymock/install-proxymock | sh

# Add to PATH for GitHub Actions
if [ -n "$GITHUB_PATH" ]; then
    echo "$HOME/.speedscale" >> $GITHUB_PATH
fi

# Initialize proxymock if API key is provided
if [ -n "$PROXYMOCK_API_KEY" ]; then
    echo "Initializing Proxymock with API key..."
    $HOME/.speedscale/proxymock init --api-key "$PROXYMOCK_API_KEY"
else
    echo "Warning: PROXYMOCK_API_KEY not set. Skipping initialization."
fi

# Verify installation
if [ -f "$HOME/.speedscale/proxymock" ]; then
    echo "Proxymock installed successfully at: $HOME/.speedscale/proxymock"
    $HOME/.speedscale/proxymock version
else
    echo "Error: Proxymock installation failed"
    exit 1
fi