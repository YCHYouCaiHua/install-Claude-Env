#!/bin/bash

# Claude Relay Service Installation Script for Ubuntu
# This script installs Node.js, Redis, and sets up the claude-relay-service

set -e  # Exit on any error

echo "Starting Claude Relay Service installation..."

# Install Node.js 18.x
echo "Installing Node.js 18.x..."
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# Update package list and install Redis
echo "Installing Redis server..."
sudo apt update
sudo apt install redis-server

# Start Redis service
echo "Starting Redis server..."
sudo systemctl start redis-server

# Clone the repository
echo "Cloning claude-relay-service repository..."
git clone https://github.com/Wei-Shaw//claude-relay-service.git
cd claude-relay-service

# Install npm dependencies
echo "Installing npm dependencies..."
npm install

# Copy configuration files
echo "Setting up configuration files..."
cp config/config.example.js config/config.js
cp .env.example .env

# Edit .env file with specific values
echo "Updating .env configuration..."
sed -i 's/JWT_SECRET=your-jwt-secret-here/JWT_SECRET=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ1c2VyLTEyMyIsInNjb3BlIjoicmVhZDphbGwiLCJpYXQiOjE2OTMyMjMxMTR9.rC4YHZh_jVbLOM6Vx7X4BNQZGeiEC7-Mp7khWnJHZu4/' .env
sed -i 's/API_KEY_PREFIX=cr_/API_KEY_PREFIX=ych_/' .env
sed -i 's/ENCRYPTION_KEY=your-encryption-key-here/ENCRYPTION_KEY=oPkxyIBrLPDnS-JaW7FPSHJY_DWerQ9hYgL80D-wiws=/' .env

# Install web dependencies and build
echo "Installing web dependencies and building..."
npm run install:web
npm run build:web

# Run setup
echo "Running setup..."
npm run setup

# Start daemon service
echo "Starting daemon service..."
npm run service:start:daemon

echo "Claude Relay Service installation completed successfully!"
echo "Service is now running in daemon mode."