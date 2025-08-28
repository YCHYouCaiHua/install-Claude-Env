#!/bin/bash

# Claude Relay P2 Installation Script
# This script runs the setup and starts the daemon service

set -e  # Exit on any error

echo "Starting Claude Relay P2 installation..."

# Run setup
echo "Running npm setup..."
npm run setup

# Start daemon service
echo "Starting daemon service..."
npm run service:start:daemon

# Check service status
echo "Checking service status..."
npm run service:status

echo "Installation completed successfully!"