@echo off
REM ──────────────────────────────────────────────────────────
REM  Diaspora Equb — Full Testnet Deployment (Windows)
REM
REM  Deploys everything from scratch on Creditcoin Testnet:
REM    1. Contracts (core + test tokens + tier config)
REM    2. Backend (Docker Compose)
REM    3. Smoke test
REM
REM  Prerequisites:
REM    - .env at project root with DEPLOYER_PRIVATE_KEY funded on testnet
REM    - Node 20+, npm, Docker Desktop (free), Docker Compose
REM    - Creditcoin testnet CTC (faucet: Discord #token-faucet)
REM
REM  Usage:
REM    scripts\deploy-testnet.bat
REM    scripts\deploy-testnet.bat --skip-contracts
REM    scripts\deploy-testnet.bat --contracts-only
REM ──────────────────────────────────────────────────────────

setlocal enabledelayedexpansion

set SCRIPT_DIR=%~dp0
set ROOT_DIR=%SCRIPT_DIR%..
set SKIP_CONTRACTS=false
set CONTRACTS_ONLY=false

if "%~1"=="--skip-contracts" set SKIP_CONTRACTS=true
if "%~1"=="--contracts-only" set CONTRACTS_ONLY=true

echo.
echo ═══════════════════════════════════════════════════════
echo  Diaspora Equb — Testnet Deployment
echo  %DATE% %TIME%
echo ═══════════════════════════════════════════════════════

REM Verify .env exists
if not exist "%ROOT_DIR%\.env" (
    echo ERROR: No .env file found at project root.
    echo Copy .env.example to .env and fill in your values.
    exit /b 1
)

REM ── Step 1: Contracts ──────────────────────────────────
if "%SKIP_CONTRACTS%"=="true" goto :skip_contracts

echo.
echo Step 1/4: Deploying Smart Contracts to Creditcoin Testnet

cd /d "%ROOT_DIR%\contracts"
call npm ci --silent

echo   1a. Compiling contracts...
call npx hardhat compile

echo   1b. Deploying core contracts...
call npx hardhat run scripts/deploy.ts --network creditcoinTestnet

echo   1c. Deploying test tokens (USDC, USDT)...
call npx hardhat run scripts/deploy-test-tokens.ts --network creditcoinTestnet

echo   1d. Configuring tiers...
call npx hardhat run scripts/configure-tiers.ts --network creditcoinTestnet

echo.
echo   ┌──────────────────────────────────────────────────┐
echo   │  IMPORTANT: Update .env with deployed addresses  │
echo   │  from contracts\deployments\ before continuing.  │
echo   └──────────────────────────────────────────────────┘
echo.
pause

:skip_contracts
cd /d "%ROOT_DIR%"

if "%CONTRACTS_ONLY%"=="true" (
    echo Contracts deployed. Exiting --contracts-only mode.
    exit /b 0
)

REM ── Step 2: Backend + Database ─────────────────────────
echo.
echo Step 2/4: Starting Backend (Docker Compose)

docker compose down 2>nul
docker compose up -d --build

echo   Waiting for backend to become healthy...
set RETRIES=0
:wait_loop
if %RETRIES% GEQ 30 (
    echo   Backend did not become healthy within 60 seconds.
    echo   Check logs: docker compose logs backend
    exit /b 1
)
curl -sf http://localhost:3001/api/health >nul 2>&1
if %errorlevel% equ 0 (
    echo   Backend is healthy!
    goto :backend_ready
)
set /a RETRIES+=1
timeout /t 2 /nobreak >nul
goto :wait_loop

:backend_ready

REM ── Step 3: Smoke Test ─────────────────────────────────
echo.
echo Step 3/4: Running Smoke Tests
call "%SCRIPT_DIR%smoke-test.bat" "http://localhost:3001/api"

REM ── Step 4: Summary ────────────────────────────────────
echo.
echo ═══════════════════════════════════════════════════════
echo   Testnet Deployment Complete!
echo ═══════════════════════════════════════════════════════
echo.
echo   Backend:  http://localhost:3001/api
echo   Swagger:  http://localhost:3001/api/docs
echo   Health:   http://localhost:3001/api/health
echo.
echo   Next steps:
echo     1. (Optional) Start ngrok: scripts\ngrok-dev.bat
echo     2. Build Flutter APK:
echo        cd frontend
echo        flutter build apk --release --split-per-abi ^
echo          --dart-define=API_BASE_URL=http://localhost:3001/api ^
echo          --dart-define=DEV_BYPASS_FAYDA=true ^
echo          --dart-define=WALLETCONNECT_PROJECT_ID=your_id
echo.
echo   To rerun smoke tests:
echo     scripts\smoke-test.bat
echo.

endlocal
