# Robust MVP Design — Diaspora Equb DeFi (Creditcoin-Compatible)

## 1) MVP Scope (No Fluff)
**Goal:** Enable diaspora + local users to join Equb pools where early beneficiaries cannot exit, using identity, collateral logic, and smart contracts.

## 2) System Architecture (High Level)
```
Mobile/Web App (Flutter)
        ↓
Backend API (Node / NestJS)
        ↓
Identity Layer (Fayda e-ID)
        ↓
Smart Contracts (Creditcoin / EVM)
        ↓
Credit & Reputation Registry
```

## 3) Authentication & Identity (Fayda-Based, Non-Negotiable)
**Why Fayda?**
- Prevents Sybil attacks
- Stops fake accounts
- Enables real-world accountability

**Auth Flow**
1. User signs up
2. Redirected to Fayda e-ID verification
3. Backend receives:
   - Verified user hash (not raw data)
   - Wallet bound to one Fayda ID
4. Identity hash stored on-chain

**Guarantees**
- One person = one identity
- Privacy preserved
- Replaces “elders & social pressure” with cryptographic identity

## 4) Tiered Equb Model (Anti-Exclusion)
**Rule:** You cannot jump tiers. Trust is earned.

| Tier | Max Pool Size | Collateral | Who Can Join |
|------|---------------|------------|-------------|
| Tier 0 | Small | None / Minimal | New users |
| Tier 1 | Medium | Partial | Completed Tier 0 |
| Tier 2 | Large | Reduced | Proven users |
| Tier 3 | Very Large | Minimal | Elite users |

## 5) Solving the “First User Leaves” Problem (Core Logic)
### Layer 1 — Streamed Payout (Primary)
- First beneficiary does **not** receive 100% instantly
- Payout schedule:
  - 20–30% unlocked immediately
  - Remaining released per round
- If user stops contributing:
  - Remaining funds auto-frozen (no manual action)

### Layer 2 — Partial Collateral (Fair & Inclusive)
- Collateral only covers remaining unpaid rounds (not full pool size)
- Example:
  - Pool: 1M birr
  - First payout unlocked: 200k
  - Remaining obligation: 800k
  - Required collateral: 200–300k (tier-dependent)

### Layer 3 — Smart Slashing Logic
Smart contract rules:
- If contribution missed:
  - Freeze unreleased payout
  - Slash collateral
  - Compensate pool
  - Update credit score

No admin control. No discretion. Only math.

### Layer 4 — Credit & Reputation (Creditcoin Advantage)
Each user has:
- On-chain credit score
- Updated every round

Effects:
- Default → locked out of future Equbs
- Good behavior → lower collateral, bigger pools

## 6) Smart Contract Modules (MVP)
**Contracts Needed**
- `EqubPool.sol` — Handles contributions & payouts
- `PayoutStream.sol` — Manages gradual release
- `CollateralVault.sol` — Locks & slashes collateral
- `CreditRegistry.sol` — Tracks reputation (Creditcoin-friendly)

## 7) Backend Logic (Off-chain, Simple)
Backend handles:
- Fayda verification
- Tier eligibility checks
- Fiat ↔ crypto on/off-ramp integration
- Notifications (missed payment warnings)

**Backend never controls funds.**

## 8) User Flow (Judge-Friendly)
**New User**
1. Verify with Fayda
2. Create wallet
3. Join Tier 0 Equb
4. No early payout risk

**Proven User**
1. Tier upgrade approved automatically
2. Lower collateral
3. Eligible for large Equbs

**If First User Defaults**
- Smart contract freezes funds
- Pool protected
- User reputation damaged permanently

## 9) Why Regular Banks Can’t Do This
Banks rely on legal enforcement and centralized control. This system enforces Equb rules automatically using smart contracts, identity, and on-chain credit—without requiring trust or intermediaries.

## 10) MVP Tech Stack (Realistic)
| Layer | Tech |
|------|------|
| Frontend | Flutter (Web + Mobile) |
| Backend | Node.js / NestJS |
| Blockchain | Creditcoin / EVM |
| Identity | Fayda |
| Wallet | Embedded / WalletConnect |
| Storage | IPFS (optional) |

## 11) Creditcoin Compatibility Notes
- Use EVM-compatible smart contracts (Solidity) deployed on Creditcoin.
- Store Fayda identity hash on-chain and bind wallet-to-identity for Sybil resistance.
- Keep credit score on-chain in `CreditRegistry.sol` for transparency and interoperability.
- Ensure payout streaming and collateral slashing are contract-enforced (no custodial backend).
