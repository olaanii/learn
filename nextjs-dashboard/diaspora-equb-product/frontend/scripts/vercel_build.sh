#!/usr/bin/env bash
set -e
# Run from frontend root; Vercel injects API_BASE_URL, WALLETCONNECT_PROJECT_ID, CHAIN_ID, RPC_URL, SENTRY_DSN
echo "[vercel_build] pwd=$(pwd)" >&2
echo "[vercel_build] ls -la:" >&2
ls -la >&2
if [ -d .flutter ]; then echo "[vercel_build] .flutter exists"; else echo "[vercel_build] .flutter MISSING"; fi >&2
echo "[vercel_build] running flutter --version" >&2
./.flutter/bin/flutter --version >&2
echo "[vercel_build] running flutter build web" >&2
./.flutter/bin/flutter build web --release --web-renderer canvaskit \
  --dart-define=API_BASE_URL="${API_BASE_URL:-http://localhost:3001/api}" \
  --dart-define=WALLETCONNECT_PROJECT_ID="${WALLETCONNECT_PROJECT_ID:-}" \
  --dart-define=CHAIN_ID="${CHAIN_ID:-102031}" \
  --dart-define=RPC_URL="${RPC_URL:-https://rpc.cc3-testnet.creditcoin.network}" \
  --dart-define=SENTRY_DSN="${SENTRY_DSN:-}" \
  --dart-define=DEV_BYPASS_FAYDA=false

# Copy public assets (e.g. app-release.apk for Android download) into the web output
if [ -d public ] && [ "$(ls -A public 2>/dev/null)" ]; then
  cp -a public/. build/web/
fi
