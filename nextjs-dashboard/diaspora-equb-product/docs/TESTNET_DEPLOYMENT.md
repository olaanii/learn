# Diaspora Equb — Testnet Deployment Guide

**Network:** Creditcoin Testnet (Chain ID: 102031)
**Version:** 0.9.0
**Date:** February 2026

---

## Prerequisites

| Tool           | Required Version | Check Command        |
| -------------- | ---------------- | -------------------- |
| Node.js        | 20+              | `node -v`            |
| npm            | 9+               | `npm -v`             |
| Docker Desktop | Free / CE        | `docker -v`          |
| Flutter        | 3.22+            | `flutter --version`  |
| MetaMask       | Latest           | Browser extension    |
| Git            | 2.x              | `git --version`      |

---

## Step 0: Generate JWT Secret

Your `.env` needs a real `JWT_SECRET` (min 32 chars). Run this:

```bash
node -e "console.log(require('crypto').randomBytes(48).toString('hex'))"
```

Copy the output and paste it as `JWT_SECRET` in your `.env` file.

---

## Step 1: Verify Contracts on Testnet

Your contracts are already deployed. Let's verify they're still live.

```bash
cd contracts
npm ci
npx hardhat run scripts/verify-deployment.ts --network creditcoinTestnet
```

**Expected:** All checks pass (contract code exists, tiers configured, tokens verified).

If any contract is missing, redeploy:
```bash
# Full redeploy (core + tokens + tiers)
npm run deploy:full-testnet
```

Then update `.env` with the new addresses from `contracts/deployments/`.

---

## Step 2: Install Backend Dependencies

```bash
cd backend
npm ci
```

---

## Step 3: Start PostgreSQL

**Option A: Docker (recommended)**
```bash
# From project root
docker compose up -d postgres
```

**Option B: Local PostgreSQL**
Make sure PostgreSQL is running and the `diaspora_equb` database exists:
```sql
CREATE DATABASE diaspora_equb;
```

---

## Step 4: Start the Backend

**Option A: Development mode (with hot-reload)**
```bash
cd backend
npm run start:dev
```

**Option B: Docker Compose (full stack)**
```bash
# From project root
docker compose up -d
```

Wait for the health check:
```bash
curl http://localhost:3001/api/health
```

Expected response:
```json
{"status":"ok","info":{"database":{"status":"up"},"rpc":{"status":"up"}},"error":{},"details":{...}}
```

---

## Step 5: Run Smoke Tests

```bash
# Windows
scripts\smoke-test.bat

# Linux/Mac
bash scripts/smoke-test.sh
```

Or with a custom URL (e.g., ngrok):
```bash
scripts\smoke-test.bat https://your-ngrok-url.ngrok-free.app/api
```

---

## Step 6: Verify via Swagger

Open in your browser: **http://localhost:3001/api/docs**

Test these endpoints manually:
1. `POST /api/auth/dev-login` with body `{"walletAddress":"0xYOUR_METAMASK_ADDRESS"}`
2. Copy the `accessToken` from the response
3. Click "Authorize" in Swagger and paste the token
4. `GET /api/pools` — should return `[]` or your pools
5. `GET /api/token/balance?walletAddress=0x...&token=USDC`
6. `GET /api/health` — should return `{"status":"ok"}`

---

## Step 7: Start ngrok (for Mobile Testing)

To test the Flutter app on a real device, expose the backend:

```bash
# Windows
scripts\ngrok-dev.bat

# Linux/Mac
bash scripts/ngrok-dev.sh
```

Note the ngrok URL (e.g., `https://abc123.ngrok-free.app`).

---

## Step 8: Run Flutter App

**Debug mode (emulator or device):**
```bash
cd frontend
flutter run --dart-define=API_BASE_URL=http://localhost:3001/api --dart-define=DEV_BYPASS_FAYDA=true --dart-define=WALLETCONNECT_PROJECT_ID=10aaa86fb2c0d5a86ee20ce532834485
```

**With ngrok (real device):**
```bash
flutter run --dart-define=API_BASE_URL=https://your-ngrok-url.ngrok-free.app/api --dart-define=DEV_BYPASS_FAYDA=true --dart-define=WALLETCONNECT_PROJECT_ID=10aaa86fb2c0d5a86ee20ce532834485
```

---

## Step 9: Build Release APK

```bash
cd frontend
flutter build apk --release --split-per-abi --obfuscate --split-debug-info=build/debug-info --dart-define=API_BASE_URL=https://your-ngrok-url.ngrok-free.app/api --dart-define=DEV_BYPASS_FAYDA=true --dart-define=WALLETCONNECT_PROJECT_ID=10aaa86fb2c0d5a86ee20ce532834485 --dart-define=CHAIN_ID=102031 --dart-define=RPC_URL=https://rpc.cc3-testnet.creditcoin.network --dart-define=TEST_USDC_ADDRESS=0xE7737c6152917b14eC82C81De4cA1C8851B995d1 --dart-define=TEST_USDT_ADDRESS=0xF8F273671D2CeBF9d2B5cF130c5aCFF1943826d7
```

APK location: `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` (~25-30 MB)

---

## Step 10: End-to-End Test Checklist

Run through this manually on the device/emulator:

| # | Action                           | Expected Result                          | Pass? |
|---|----------------------------------|------------------------------------------|-------|
| 1 | Open app                         | Onboarding screen appears                | [ ]   |
| 2 | Dev-login (or Fayda tab)         | Logged in, redirected to home            | [ ]   |
| 3 | Home screen loads                | Balance shows, TESTNET badge visible     | [ ]   |
| 4 | Connect wallet (WalletConnect)   | MetaMask opens, connects                 | [ ]   |
| 5 | Request test USDC from faucet    | Balance increases                        | [ ]   |
| 6 | View token transactions          | Transaction list populated               | [ ]   |
| 7 | Navigate to Collateral screen    | Shows collateral options                 | [ ]   |
| 8 | Navigate to Pool Status          | Shows pools (empty or populated)         | [ ]   |
| 9 | Navigate to Notifications        | Shows notification list                  | [ ]   |
| 10| Pull-to-refresh on home          | Balances refresh                         | [ ]   |
| 11| Check Swagger docs               | All endpoints documented                 | [ ]   |
| 12| Health endpoint returns OK       | `{"status":"ok"}`                        | [ ]   |

---

## Troubleshooting

### Backend won't start
- Check `.env` has `JWT_SECRET` at least 32 chars
- Check PostgreSQL is running: `docker compose ps`
- Check logs: `docker compose logs backend` or terminal output

### Contracts verification fails
- Check deployer has testnet CTC: https://creditcoin-testnet.blockscout.com/address/YOUR_ADDRESS
- Redeploy: `cd contracts && npm run deploy:full-testnet`

### Flutter app can't connect
- Verify `API_BASE_URL` is correct
- If using ngrok, check the tunnel is active
- Check CORS: in development mode, all origins are allowed

### MetaMask not connecting
- Ensure MetaMask is on Creditcoin Testnet (Chain ID: 102031)
- Add network manually: RPC URL `https://rpc.cc3-testnet.creditcoin.network`, Symbol: `CTC`
- Get testnet CTC from Discord faucet

---

## Explorer Links

- **Contracts:** Check any contract at `https://creditcoin-testnet.blockscout.com/address/CONTRACT_ADDRESS`
- **Your deployed contracts:**
  - IdentityRegistry: https://creditcoin-testnet.blockscout.com/address/0x56050273Bca0e86fC8B3e289C9E1b9BD5978eece
  - TierRegistry: https://creditcoin-testnet.blockscout.com/address/0xF6A8dBcC6C1eA72776AcF20ca66422DEcAC294cE
  - CreditRegistry: https://creditcoin-testnet.blockscout.com/address/0x64AE5370987Ed5318A00e7FB88a18f6A890190fB
  - CollateralVault: https://creditcoin-testnet.blockscout.com/address/0x21F154eA8ade6C384F44947Ff705437821D0dDc1
  - PayoutStream: https://creditcoin-testnet.blockscout.com/address/0x4fE169b73d212Ea8eACaB75edfA5d1ae0E914F97
  - EqubPool: https://creditcoin-testnet.blockscout.com/address/0xcADa53528e1b04E2370b2694b6c9a60e79d67203
  - TestUSDC: https://creditcoin-testnet.blockscout.com/address/0xE7737c6152917b14eC82C81De4cA1C8851B995d1
  - TestUSDT: https://creditcoin-testnet.blockscout.com/address/0xF8F273671D2CeBF9d2B5cF130c5aCFF1943826d7
