#!/usr/bin/env bash
set -euo pipefail

# Run from frontend root. Vercel injects env vars at build time and this script
# forwards them into Flutter via dart-defines so no Firebase secrets or config
# files need to be committed.

readonly flutter_bin="./.flutter/bin/flutter"
readonly dart_bin="./.flutter/bin/dart"
readonly landing_dir="seo_landing"
readonly landing_asset_dir="$landing_dir/web/assets"
readonly flutter_output_dir="build/web"
readonly deploy_output_dir="build/site"
readonly flutter_mount_dir="$deploy_output_dir/app"

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

rm -rf "$deploy_output_dir"
mkdir -p "$landing_asset_dir"

cp assets/logo.png "$landing_asset_dir/logo.png"
cp assets/landing-mobile-preview.png "$landing_asset_dir/landing-mobile-preview.png"

pushd "$landing_dir" >/dev/null
../.flutter/bin/dart pub get
../.flutter/bin/dart pub global run jaspr_cli:jaspr build --verbose \
  --sitemap-domain="${SITE_URL:-https://e-equb.vercel.app}"
popd >/dev/null

# --web-renderer was removed in Flutter 3.22+; default is used
"$flutter_bin" build web --release \
  --base-href /app/ \
  --dart-define=API_BASE_URL="${API_BASE_URL:-https://equb-db.netlify.app/api}" \
  --dart-define=PRIVY_APP_ID="${PRIVY_APP_ID:-}" \
  --dart-define=PRIVY_APP_CLIENT_ID="${PRIVY_APP_CLIENT_ID:-}" \
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

mkdir -p "$deploy_output_dir"
cp -a "$landing_dir/build/jaspr/." "$deploy_output_dir/"

mkdir -p "$flutter_mount_dir"
cp -a "$flutter_output_dir/." "$flutter_mount_dir/"

# Copy public assets (e.g. app-release.apk for Android download) into the final deploy output.
if [ -d public ] && [ "$(ls -A public 2>/dev/null)" ]; then
  cp -a public/. "$deploy_output_dir/"
fi
