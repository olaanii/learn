#!/usr/bin/env bash
# Expose local backend (port 3001) via ngrok for mobile testing.
# Prerequisites: install ngrok from https://ngrok.com and run `ngrok config add-authtoken YOUR_TOKEN`
#
# Usage:
#   1. Start backend:   cd backend && npm run start:dev
#   2. Run this script:  ./scripts/ngrok-dev.sh
#   3. Copy the https://xxxx.ngrok-free.app URL
#   4. Build Flutter with: flutter run --dart-define=API_BASE_URL=https://xxxx.ngrok-free.app/api

set -e

echo "Starting ngrok tunnel to localhost:3001 ..."
echo ""
echo "After ngrok starts, copy the Forwarding URL (https://xxxx.ngrok-free.app)"
echo "and use it as API_BASE_URL when running the Flutter app:"
echo ""
echo "  flutter run --dart-define=API_BASE_URL=https://xxxx.ngrok-free.app/api"
echo ""

ngrok http 3001
