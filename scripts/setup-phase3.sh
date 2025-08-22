#!/bin/bash

echo "Setting up Phase 3 - Platform Integration"

# Install backend dependencies
cd backend
npm install
npx prisma migrate dev --name phase3_init
npx prisma db seed

# Setup environment files
cp .env.example .env
echo "Please edit backend/.env with your credentials"

# Install Flutter dependencies
cd ../apps/mobile
flutter pub get

cd ../desktop
flutter pub get

cd ../web
flutter pub get

# Generate certificates for development
cd ../../scripts
./generate-certificates.sh

echo "Phase 3 setup complete!"
echo "Next steps:"
echo "1. Edit backend/.env with your API keys"
echo "2. Run 'npm run dev' in backend/"
echo "3. Run 'flutter run' in apps/[platform]"