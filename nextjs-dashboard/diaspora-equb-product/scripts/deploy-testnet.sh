#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────
#  Diaspora Equb — Full Testnet Deployment
#
#  Deploys everything from scratch on Creditcoin Testnet:
#    1. Contracts (core + test tokens + tier config)
#    2. Backend (Docker Compose)
#    3. Smoke test
#
#  Prerequisites:
#    - .env at project root with DEPLOYER_PRIVATE_KEY funded on testnet
#    - Node 20+, npm, Docker, Docker Compose
#    - Creditcoin testnet CTC (faucet: Discord #token-faucet)
#
#  Usage:
#    ./scripts/deploy-testnet.sh
#    ./scripts/deploy-testnet.sh --skip-contracts   # redeploy backend only
#    ./scripts/deploy-testnet.sh --contracts-only    # deploy contracts only
# ──────────────────────────────────────────────────────────

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SKIP_CONTRACTS=false
CONTRACTS_ONLY=false

for arg in "$@"; do
  case $arg in
    --skip-contracts) SKIP_CONTRACTS=true ;;
    --contracts-only) CONTRACTS_ONLY=true ;;
  esac
done

green()  { printf "\033[32m%s\033[0m\n" "$*"; }
red()    { printf "\033[31m%s\033[0m\n" "$*"; }
bold()   { printf "\033[1m%s\033[0m\n" "$*"; }

bold "═══════════════════════════════════════════════════════"
bold "  Diaspora Equb — Testnet Deployment"
bold "  $(date)"
bold "═══════════════════════════════════════════════════════"

# Verify .env exists
if [ ! -f "$ROOT_DIR/.env" ]; then
  red "ERROR: No .env file found at project root."
  red "Copy .env.example to .env and fill in your values."
  exit 1
fi

# Source .env for later use
set -a
source "$ROOT_DIR/.env"
set +a

# ── Step 1: Contracts ───────────────────────────────────
if [ "$SKIP_CONTRACTS" = false ]; then
  bold ""
  bold "Step 1/4: Deploying Smart Contracts to Creditcoin Testnet"

  cd "$ROOT_DIR/contracts"
  npm ci --silent

  bold "  1a. Compiling contracts..."
  npx hardhat compile

  bold "  1b. Deploying core contracts..."
  npx hardhat run scripts/deploy.ts --network creditcoinTestnet

  bold "  1c. Deploying test tokens (USDC, USDT)..."
  npx hardhat run scripts/deploy-test-tokens.ts --network creditcoinTestnet

  bold "  1d. Configuring tiers..."
  npx hardhat run scripts/configure-tiers.ts --network creditcoinTestnet

  # Read deployed addresses and print them
  if [ -f "$ROOT_DIR/contracts/deployments/creditcoinTestnet.json" ]; then
    green "  Core contracts deployed!"
    bold "  Update your .env with the addresses from:"
    bold "    contracts/deployments/creditcoinTestnet.json"
    bold "    contracts/deployments/creditcoinTestnet-tokens.json"
    echo ""
    bold "  ┌──────────────────────────────────────────────────┐"
    bold "  │  IMPORTANT: Update .env with deployed addresses  │"
    bold "  │  before continuing to the backend step.          │"
    bold "  │                                                  │"
    bold "  │  Press Enter after updating .env, or Ctrl+C to   │"
    bold "  │  abort and update manually.                      │"
    bold "  └──────────────────────────────────────────────────┘"
    read -rp "  Press Enter to continue..."
  fi

  cd "$ROOT_DIR"
fi

if [ "$CONTRACTS_ONLY" = true ]; then
  green "Contracts deployed. Exiting (--contracts-only mode)."
  exit 0
fi

# ── Step 2: Backend + Database ──────────────────────────
bold ""
bold "Step 2/4: Starting Backend (Docker Compose)"

cd "$ROOT_DIR"

docker compose down 2>/dev/null || true
docker compose up -d --build

bold "  Waiting for backend to become healthy..."
for i in $(seq 1 30); do
  if curl -sf http://localhost:3001/api/health > /dev/null 2>&1; then
    green "  Backend is healthy!"
    break
  fi
  if [ "$i" = "30" ]; then
    red "  Backend did not become healthy within 60 seconds."
    red "  Check logs: docker compose logs backend"
    exit 1
  fi
  sleep 2
done

# ── Step 3: Smoke Test ──────────────────────────────────
bold ""
bold "Step 3/4: Running Smoke Tests"

bash "$SCRIPT_DIR/smoke-test.sh" "http://localhost:3001/api"

# ── Step 4: Summary ─────────────────────────────────────
bold ""
bold "═══════════════════════════════════════════════════════"
green "  Testnet Deployment Complete!"
bold "═══════════════════════════════════════════════════════"
bold ""
bold "  Backend:  http://localhost:3001/api"
bold "  Swagger:  http://localhost:3001/api/docs"
bold "  Health:   http://localhost:3001/api/health"
bold ""
bold "  Next steps:"
bold "    1. (Optional) Start ngrok: ./scripts/ngrok-dev.sh"
bold "    2. Build Flutter APK:"
bold "       cd frontend && flutter build apk --release --split-per-abi \\"
bold "         --dart-define=API_BASE_URL=http://localhost:3001/api \\"
bold "         --dart-define=DEV_BYPASS_FAYDA=true \\"
bold "         --dart-define=WALLETCONNECT_PROJECT_ID=your_id"
bold ""
bold "  To rerun smoke tests:"
bold "    ./scripts/smoke-test.sh"
bold ""
