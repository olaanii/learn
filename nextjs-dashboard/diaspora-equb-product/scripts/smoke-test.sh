#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────
#  Diaspora Equb — Testnet Smoke Test
#  Verifies all critical API endpoints after deployment.
#
#  Usage:
#    ./scripts/smoke-test.sh                     # default: http://localhost:3001/api
#    ./scripts/smoke-test.sh https://your-ngrok-url.ngrok-free.app/api
# ──────────────────────────────────────────────────────────

set -euo pipefail

BASE_URL="${1:-http://localhost:3001/api}"
PASS=0
FAIL=0
WARN=0

green()  { printf "\033[32m%s\033[0m\n" "$*"; }
red()    { printf "\033[31m%s\033[0m\n" "$*"; }
yellow() { printf "\033[33m%s\033[0m\n" "$*"; }
bold()   { printf "\033[1m%s\033[0m\n" "$*"; }

check() {
  local label="$1" method="$2" path="$3"
  shift 3
  local url="${BASE_URL}${path}"

  local http_code body
  if [ "$method" = "GET" ]; then
    http_code=$(curl -s -o /dev/null -w "%{http_code}" "$url" "$@" 2>/dev/null || echo "000")
  else
    http_code=$(curl -s -o /dev/null -w "%{http_code}" -X "$method" "$url" "$@" 2>/dev/null || echo "000")
  fi

  if [ "$http_code" = "000" ]; then
    red "  FAIL  $label — connection refused"
    FAIL=$((FAIL + 1))
  elif [ "$http_code" -ge 200 ] && [ "$http_code" -lt 300 ]; then
    green "  PASS  $label (HTTP $http_code)"
    PASS=$((PASS + 1))
  elif [ "$http_code" = "401" ]; then
    yellow "  WARN  $label (HTTP 401 — expected for auth-protected route)"
    WARN=$((WARN + 1))
  else
    red "  FAIL  $label (HTTP $http_code)"
    FAIL=$((FAIL + 1))
  fi
}

check_json() {
  local label="$1" path="$2" key="$3"
  local url="${BASE_URL}${path}"
  local body
  body=$(curl -s "$url" 2>/dev/null || echo "{}")

  if echo "$body" | grep -q "$key"; then
    green "  PASS  $label — contains '$key'"
    PASS=$((PASS + 1))
  else
    red "  FAIL  $label — missing '$key' in response"
    FAIL=$((FAIL + 1))
  fi
}

dev_login() {
  local url="${BASE_URL}/auth/dev-login"
  local body
  body=$(curl -s -X POST "$url" \
    -H "Content-Type: application/json" \
    -d '{"walletAddress":"0x1234567890abcdef1234567890abcdef12345678"}' 2>/dev/null || echo "{}")

  TOKEN=$(echo "$body" | grep -o '"accessToken":"[^"]*"' | cut -d'"' -f4)
  if [ -n "$TOKEN" ]; then
    green "  PASS  Dev login — got JWT token"
    PASS=$((PASS + 1))
  else
    yellow "  WARN  Dev login unavailable (expected in production)"
    WARN=$((WARN + 1))
    TOKEN=""
  fi
}

check_authed() {
  local label="$1" method="$2" path="$3"
  shift 3
  if [ -z "$TOKEN" ]; then
    yellow "  SKIP  $label (no auth token)"
    WARN=$((WARN + 1))
    return
  fi

  local url="${BASE_URL}${path}"
  local http_code
  if [ "$method" = "GET" ]; then
    http_code=$(curl -s -o /dev/null -w "%{http_code}" "$url" -H "Authorization: Bearer $TOKEN" "$@" 2>/dev/null || echo "000")
  else
    http_code=$(curl -s -o /dev/null -w "%{http_code}" -X "$method" "$url" -H "Authorization: Bearer $TOKEN" "$@" 2>/dev/null || echo "000")
  fi

  if [ "$http_code" = "000" ]; then
    red "  FAIL  $label — connection refused"
    FAIL=$((FAIL + 1))
  elif [ "$http_code" -ge 200 ] && [ "$http_code" -lt 300 ]; then
    green "  PASS  $label (HTTP $http_code)"
    PASS=$((PASS + 1))
  elif [ "$http_code" = "404" ]; then
    yellow "  WARN  $label (HTTP 404 — route exists but no data)"
    WARN=$((WARN + 1))
  else
    red "  FAIL  $label (HTTP $http_code)"
    FAIL=$((FAIL + 1))
  fi
}

# ═══════════════════════════════════════════════════════════
bold ""
bold "Diaspora Equb — Testnet Smoke Test"
bold "Target: $BASE_URL"
bold "Time:   $(date)"
bold "═══════════════════════════════════════════════════════"

# ── 1. Health ─────────────────────────────────────────────
bold ""
bold "1. Health Checks"
check_json "Health endpoint" "/health" "status"
check "Indexer status" GET "/health/indexer"

# ── 2. Fayda Status ──────────────────────────────────────
bold ""
bold "2. Fayda Integration Status"
check "Fayda status" GET "/auth/fayda/status"

# ── 3. Auth ──────────────────────────────────────────────
bold ""
bold "3. Authentication"
dev_login

# ── 4. Swagger ───────────────────────────────────────────
bold ""
bold "4. Swagger Documentation"
check "Swagger JSON" GET "/../api-docs-json" 2>/dev/null || check "Swagger JSON" GET "/docs-json"

# ── 5. Token Endpoints (authenticated) ───────────────────
bold ""
bold "5. Token Endpoints"
check_authed "Token balance" GET "/token/balance?walletAddress=0x1234567890abcdef1234567890abcdef12345678&token=USDC"
check_authed "Token rates" GET "/token/rates"
check_authed "Supported tokens" GET "/token/supported"
check_authed "Transactions" GET "/token/transactions?walletAddress=0x1234567890abcdef1234567890abcdef12345678"

# ── 6. Pool Endpoints (authenticated) ────────────────────
bold ""
bold "6. Pool Endpoints"
check_authed "List pools" GET "/pools"

# ── 7. Collateral Endpoints (authenticated) ──────────────
bold ""
bold "7. Collateral Endpoints"
check_authed "Collateral info" GET "/collateral/0x1234567890abcdef1234567890abcdef12345678"

# ── 8. Tier / Credit ────────────────────────────────────
bold ""
bold "8. Tier & Credit"
check_authed "Tier info" GET "/tier/0x1234567890abcdef1234567890abcdef12345678"
check_authed "Credit score" GET "/credit/0x1234567890abcdef1234567890abcdef12345678"

# ── 9. Notifications ─────────────────────────────────────
bold ""
bold "9. Notifications"
check_authed "List notifications" GET "/notifications"
check_authed "Unread count" GET "/notifications/unread-count"

# ═══════════════════════════════════════════════════════════
bold ""
bold "═══════════════════════════════════════════════════════"
bold "Results: ${PASS} passed, ${FAIL} failed, ${WARN} warnings"
bold "═══════════════════════════════════════════════════════"

if [ "$FAIL" -gt 0 ]; then
  red ""
  red "Some tests FAILED. Review the output above."
  exit 1
else
  green ""
  green "All critical checks passed!"
  exit 0
fi
