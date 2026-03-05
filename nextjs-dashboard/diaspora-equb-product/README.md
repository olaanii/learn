# Diaspora Equb — DeFi Rotating Savings on Creditcoin

**A Creditcoin Hackathon project.** Diaspora Equb is a non-custodial Web3 app that brings the traditional [equb](https://en.wikipedia.org/wiki/Equb) (rotating savings and credit association) on-chain. Members pool funds in cycles; each round one member receives the payout. Built for [Creditcoin](https://creditcoin.org/) (EVM), with a Flutter frontend and a NestJS backend that indexes the chain and never holds user funds.

---

## What is an Equb?

An **equb** (also *iddir*, *ekub*) is a group savings scheme: members contribute a fixed amount on a schedule (daily, weekly, or monthly). Each round, one member is selected to receive the full pot (by lottery, rotation, or bid). Rounds repeat until every member has received once; then a new season can start. Collateral and on-chain credit history keep the system honest and composable with DeFi.

This app digitizes that model on Creditcoin: **create or join pools**, **contribute in CTC or ERC-20**, **lock collateral**, and **govern pool rules** via DAO-style proposals—all without the backend ever custodying funds.

---

## How It Works

### High-level flow

1. **Creator** deploys or uses an existing pool (smart contract). Sets contribution amount, max members, token (native CTC or ERC-20), and rules (equb type, frequency, payout method).
2. **Members** join the pool and lock collateral (enforced on-chain). Each round they contribute; the contract holds the funds.
3. **Round end**: the pool creator (or designated role) triggers winner selection. For lottery pools, the contract picks a random eligible member (no one can win twice in the same season).
4. **Payout**: the winner receives the round pot (streamed via the PayoutStream contract when applicable). Contributions for the next round continue.
5. **Governance**: members can propose and vote on rule changes (e.g. frequency, grace period); the EqubGovernor contract executes approved proposals.

The **backend** (NestJS) indexes chain and pool state, serves pool list/detail, builds transaction payloads (e.g. approve, contribute, selectWinner), and handles auth (JWT after wallet sign-in). It does **not** hold private keys or custody funds. The **frontend** (Flutter) connects wallets via WalletConnect, signs transactions in the user’s wallet, and talks to the backend for data and tx building.

### Tech stack

| Layer        | Stack |
|-------------|--------|
| **Chain**   | Creditcoin (EVM), Solidity ^0.8.20, Hardhat |
| **Contracts** | EqubPool, CollateralVault, PayoutStream, CreditRegistry, IdentityRegistry, TierRegistry, EqubGovernor, AchievementBadge, SwapRouter |
| **Backend** | NestJS, TypeORM, PostgreSQL, optional Redis |
| **Frontend**| Flutter (Dart), WalletConnect v2 (Reown), go_router, Provider |

---

## Repository structure

```
diaspora-equb-product/
├── contracts/          # Solidity + Hardhat
│   ├── src/            # EqubPool, CollateralVault, PayoutStream, Governance, etc.
│   ├── scripts/        # deploy, upgrade
│   └── test/
├── backend/            # NestJS API
│   ├── src/            # auth, pools, collateral, tiers, token, analytics, governance, rules, …
│   └── vercel.json     # serverless deploy (Vercel)
├── frontend/           # Flutter app (web + Android)
│   ├── lib/            # screens, providers, services, config
│   └── vercel.json     # web deploy (Vercel)
├── .env.example        # env template
├── DEPLOY_ONLINE.md    # Full-stack deploy (contracts + backend + frontend)
└── README.md           # This file
```

---

## Quick start (local)

1. **Clone and install**

   ```bash
   git clone https://github.com/olaanii/learn.git
   cd learn/nextjs-dashboard/diaspora-equb-product
   ```

2. **Environment**

   Copy `.env.example` to `.env` and set at least:
   - `RPC_URL` (e.g. Creditcoin testnet)
   - `CHAIN_ID` (102031 testnet / 102030 mainnet)
   - Backend: `DATABASE_*` or `DATABASE_URL`, `JWT_SECRET`
   - Contract addresses (or deploy contracts first and paste them)

3. **Contracts** (optional if already deployed)

   ```bash
   cd contracts
   npm ci
   npx hardhat run scripts/deploy.ts --network creditcoinTestnet
   ```
   Update root `.env` (and backend) with the printed addresses.

4. **Backend**

   ```bash
   cd backend
   npm ci
   npm run start:dev
   ```
   API: `http://localhost:3001` (global prefix `/api`).

5. **Frontend**

   ```bash
   cd frontend
   flutter pub get
   flutter run -d chrome
   ```
   Set backend URL in app config or `.env` (e.g. `API_BASE_URL=http://localhost:3001/api`). For wallet connect you need a WalletConnect project ID (e.g. from [cloud.walletconnect.com](https://cloud.walletconnect.com)).

---

## Learning path for developers

This repo is a good reference for building a **DeFi app on an EVM chain** (here, Creditcoin): smart contracts, indexer-style backend, and a mobile-first frontend that uses WalletConnect and never sends private keys off-device.

### 1. Smart contracts (`contracts/`)

- **EqubPool.sol** — Core pool logic: join, contribute, select winner, round/season, rules (type, frequency, payout method). Supports native CTC and ERC-20.
- **CollateralVault.sol** — Lock collateral per pool; slashing if a member defaults.
- **PayoutStream.sol** — Stream payouts to the round winner.
- **CreditRegistry.sol** / **IdentityRegistry.sol** — On-chain identity and credit.
- **EqubGovernor.sol** — Proposal and vote execution for pool rule changes.
- **TierRegistry.sol** — Pool tiers and parameters.

Read `contracts/src/EqubPool.sol` first, then collateral and governance. Tests are in `contracts/test/`.

### 2. Backend (`backend/`)

- **Non-custodial**: no hot wallets; it builds and returns transaction payloads; the user signs in their wallet.
- **Modules**: `PoolsModule` (pool CRUD, eligible winners, build contribute/selectWinner tx), `CollateralModule`, `TokenModule`, `GovernanceModule`, `RulesModule`, `AnalyticsModule`, etc.
- **Web3**: `Web3Module` + contract wrappers for read calls and tx building (e.g. `buildContributeTx`, `buildSelectWinnerTx`).
- **Auth**: JWT after wallet connection and sign-in (e.g. SIWE-style challenge).

Start with `backend/src/pools/pools.service.ts` and `backend/src/web3/` to see how the API talks to the chain.

### 3. Frontend (`frontend/`)

- **Flutter**: one codebase for **web** and **Android**.
- **WalletConnect**: Reown Sign (WalletConnect v2); connect and sign in `lib/providers/auth_provider.dart` and `lib/services/wallet_service.dart`.
- **Screens**: home, pool browser, pool status, contribute, payout tracker (pick winner), collateral, governance, rules, swap, referrals, badges, profile.
- **Config**: `lib/config/app_config.dart` — API base URL, chain ID, RPC, WalletConnect project ID (compile-time or env).

Good entry points: `lib/providers/pool_provider.dart`, `lib/screens/pool_status_screen.dart`, and `lib/screens/payout_tracker_screen.dart` (lottery flow).

### 4. Deploying to production

- **Contracts**: deploy once per network; addresses go into backend and frontend env.
- **Backend**: Vercel (serverless) or Docker + Postgres. See `backend/VERCEL_DEPLOY.md` and `DEPLOY_ONLINE.md`.
- **Frontend**: Flutter web on Vercel; Android APK can be built locally and hosted (e.g. from `frontend/public/`). See `frontend/VERCEL_DEPLOY.md` and `DEPLOY_ONLINE.md`.

---

## Documentation

| Doc | Description |
|-----|-------------|
| [DEPLOY_ONLINE.md](./DEPLOY_ONLINE.md) | Deploy contracts, backend, and frontend (Vercel, Docker, env) |
| [backend/VERCEL_DEPLOY.md](./backend/VERCEL_DEPLOY.md) | Backend on Vercel (env, DB, Root Directory) |
| [frontend/VERCEL_DEPLOY.md](./frontend/VERCEL_DEPLOY.md) | Flutter web on Vercel (env, Root Directory, APK host) |
| [frontend/ANDROID_INSTALL.md](./frontend/ANDROID_INSTALL.md) | Android release build and “App not installed” fixes |

---

## Creditcoin & Hackathon

- **Creditcoin**: [creditcoin.org](https://creditcoin.org) — EVM-compatible L1 for credit and real-world assets.
- **RPC**: Testnet `https://rpc.cc3-testnet.creditcoin.network` (chain ID 102031); mainnet `https://mainnet3.creditcoin.network` (102030).
- This project was built as a **Creditcoin hackathon** submission: a full-stack DeFi app (contracts + backend + frontend) that demonstrates rotating savings, collateral, and on-chain governance on Creditcoin.

---

## License

MIT.
