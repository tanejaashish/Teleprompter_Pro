#!/bin/bash
set -euo pipefail

echo "Installing TelePrompt Pro dependencies..."

# Check Flutter
if ! command -v flutter &> /dev/null; then
    echo "Flutter is not installed. Please install Flutter first."
    echo "Visit: https://flutter.dev/docs/get-started/install"
    exit 1
fi

# Check Node.js
if ! command -v node &> /dev/null; then
    echo "Node.js is not installed. Please install Node.js first."
    echo "Visit: https://nodejs.org/"
    exit 1
fi

# Install Dart global packages
echo "Installing Dart global packages..."
dart pub global activate melos
dart pub global activate flutter_gen

# Install Flutter packages
echo "Installing Flutter packages..."
melos bootstrap

# Install Node packages
echo "Installing Node.js packages..."
npm ci

# Setup Git hooks
echo "Setting up Git hooks..."
npx husky install

# Create .env file if it doesn't exist
if [ ! -f .env ]; then
    echo "Creating .env file..."
    cp .env.example .env
    echo "Please edit .env with your configuration values."
fi

echo "✅ Dependencies installed successfully!"
echo ""
echo "Next steps:"
echo "1. Edit .env with your configuration"
echo "2. Run 'docker-compose up -d' to start backend services"
echo "3. Run 'flutter run' to start the application"
