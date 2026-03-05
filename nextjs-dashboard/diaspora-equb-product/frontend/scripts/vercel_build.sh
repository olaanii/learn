#!/usr/bin/env bash
set -e
# Run from frontend root; Vercel injects API_BASE_URL, WALLETCONNECT_PROJECT_ID, CHAIN_ID, RPC_URL, SENTRY_DSN
# --web-renderer was removed in Flutter 3.22+; default is used
./.flutter/bin/flutter build web --release \
  --dart-define=API_BASE_URL="${API_BASE_URL:-https://equb-db.netlify.app/api}" \
  --dart-define=WALLETCONNECT_PROJECT_ID="${WALLETCONNECT_PROJECT_ID:-}" \
  --dart-define=CHAIN_ID="${CHAIN_ID:-102031}" \
  --dart-define=RPC_URL="${RPC_URL:-https://rpc.cc3-testnet.creditcoin.network}" \
  --dart-define=SENTRY_DSN="${SENTRY_DSN:-}" \
  --dart-define=DEV_BYPASS_FAYDA=false

# Copy public assets (e.g. app-release.apk for Android download) into the web output
if [ -d public ] && [ "$(ls -A public 2>/dev/null)" ]; then
  cp -a public/. build/web/
fi
