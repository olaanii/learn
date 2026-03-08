#!/usr/bin/env bash
set -e

# Run from frontend root. Vercel injects env vars at build time and this script
# forwards them into Flutter via dart-defines so no Firebase secrets or config
# files need to be committed.

readonly firebase_api_key="${FIREBASE_API_KEY:-}"
readonly firebase_app_id="${FIREBASE_APP_ID:-}"
readonly firebase_sender_id="${FIREBASE_MESSAGING_SENDER_ID:-}"
readonly firebase_project_id="${FIREBASE_PROJECT_ID:-}"

if [[ -n "$firebase_api_key" || -n "$firebase_app_id" || -n "$firebase_sender_id" || -n "$firebase_project_id" ]]; then
  if [[ -z "$firebase_api_key" || -z "$firebase_app_id" || -z "$firebase_sender_id" || -z "$firebase_project_id" ]]; then
    echo "Firebase env vars are partially configured. Set FIREBASE_API_KEY, FIREBASE_APP_ID, FIREBASE_MESSAGING_SENDER_ID, and FIREBASE_PROJECT_ID together in Vercel." >&2
    exit 1
  fi
fi

# --web-renderer was removed in Flutter 3.22+; default is used
./.flutter/bin/flutter build web --release \
  --dart-define=API_BASE_URL="${API_BASE_URL:-https://equb-db.netlify.app/api}" \
  --dart-define=WALLETCONNECT_PROJECT_ID="${WALLETCONNECT_PROJECT_ID:-}" \
  --dart-define=CHAIN_ID="${CHAIN_ID:-102031}" \
  --dart-define=RPC_URL="${RPC_URL:-https://rpc.cc3-testnet.creditcoin.network}" \
  --dart-define=SENTRY_DSN="${SENTRY_DSN:-}" \
  --dart-define=FIREBASE_API_KEY="$firebase_api_key" \
  --dart-define=FIREBASE_APP_ID="$firebase_app_id" \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID="$firebase_sender_id" \
  --dart-define=FIREBASE_PROJECT_ID="$firebase_project_id" \
  --dart-define=FIREBASE_AUTH_DOMAIN="${FIREBASE_AUTH_DOMAIN:-}" \
  --dart-define=FIREBASE_STORAGE_BUCKET="${FIREBASE_STORAGE_BUCKET:-}" \
  --dart-define=FIREBASE_IOS_BUNDLE_ID="${FIREBASE_IOS_BUNDLE_ID:-}" \
  --dart-define=FIREBASE_ANDROID_CLIENT_ID="${FIREBASE_ANDROID_CLIENT_ID:-}" \
  --dart-define=FIREBASE_IOS_CLIENT_ID="${FIREBASE_IOS_CLIENT_ID:-}" \
  --dart-define=FIREBASE_MEASUREMENT_ID="${FIREBASE_MEASUREMENT_ID:-}" \
  --dart-define=GOOGLE_WEB_CLIENT_ID="${GOOGLE_WEB_CLIENT_ID:-}" \
  --dart-define=DEV_BYPASS_FAYDA=false

# Copy public assets (e.g. app-release.apk for Android download) into the web output
if [ -d public ] && [ "$(ls -A public 2>/dev/null)" ]; then
  cp -a public/. build/web/
fi
