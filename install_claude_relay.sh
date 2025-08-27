#!/bin/bash

# Claude Relay Service Installation Script for Ubuntu
# This script installs Node.js 18, Redis, and sets up the claude-relay-service

set -e  # Exit on any error

echo "Starting Claude Relay Service installation..."

# Install Node.js 18
echo "Installing Node.js 18..."
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# Update package list and install Redis
echo "Installing Redis server..."
sudo apt update
sudo apt install -y redis-server

# Start Redis service
echo "Starting Redis server..."
sudo systemctl start redis-server

# Clone the repository
echo "Cloning claude-relay-service repository..."
git clone https://github.com/Wei-Shaw//claude-relay-service.git

# Enter the project directory
cd claude-relay-service

# Install npm dependencies
echo "Installing npm dependencies..."
npm install

# Copy configuration files
echo "Setting up configuration files..."
cp config/config.example.js config/config.js
cp .env.example .env

# Install web dependencies
echo "Installing web dependencies..."
npm run install:web

# Build web assets
echo "Building web assets..."
npm run build:web

# Run setup
echo "Running setup..."
npm run setup

# Start the service as daemon
echo "Starting service as daemon..."
npm run service:start:daemon

echo "Installation completed successfully!"
echo "Claude Relay Service is now running as a daemon."