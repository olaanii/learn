@echo off
REM Expose local backend (port 3001) via ngrok for mobile testing.
REM Prerequisites: install ngrok from https://ngrok.com and run `ngrok config add-authtoken YOUR_TOKEN`
REM
REM Usage:
REM   1. Start backend:   cd backend && npm run start:dev
REM   2. Run this script:  scripts\ngrok-dev.bat
REM   3. Copy the https://xxxx.ngrok-free.app URL
REM   4. Build Flutter with: flutter run --dart-define=API_BASE_URL=https://xxxx.ngrok-free.app/api

echo Starting ngrok tunnel to localhost:3001 ...
echo.
echo After ngrok starts, copy the Forwarding URL (https://xxxx.ngrok-free.app)
echo and use it as API_BASE_URL when running the Flutter app:
echo.
echo   flutter run --dart-define=API_BASE_URL=https://xxxx.ngrok-free.app/api
echo.

ngrok http 3001
