# MVP Completion Checklist

## Identity & Access
- [x] Fayda verification flow stubbed in backend
- [x] Identity hash stored on-chain (backend stub + IdentityRegistry contract)
- [x] Wallet bound to identity hash (one-to-one) in backend

## Equb Pool Operations
- [x] Pool creation with tier limits (contract + backend stub)
- [x] Streamed payout schedule (contract + backend stub)
- [x] Contribution tracking by round (contract + backend stub)
- [x] Auto-freeze on missed contributions (round close logic)

## Collateral & Slashing
- [x] Partial collateral based on remaining obligation (contract + backend stub)
- [x] Collateral slashing on default (contract + backend stub)
- [x] Pool compensation from slashed funds (contract stub)

## Credit & Reputation
- [x] On-chain credit score updates per round (contract + backend stub)
- [x] Tier upgrade rules enforced (backend eligibility stub)
- [x] Default penalties reflected in eligibility

## Frontend
- [x] Fayda verification screen (UI stub)
- [x] Wallet binding flow (UI stub)
- [x] Pool join + status screen (UI stub)
- [x] Payout stream tracker (UI stub)
- [x] Credit score + tier progress (UI stub)

## Backend
- [x] Verify Fayda token endpoint (backend stub)
- [x] Wallet binding endpoint (backend stub)
- [x] Tier eligibility endpoint (backend stub)
- [x] Pool join endpoint (backend stub)
- [x] Notifications for missed payments (backend stub)

## Contracts
- [x] EqubPool deployment (scripted)
- [x] PayoutStream deployment (scripted)
- [x] CollateralVault deployment (scripted)
- [x] CreditRegistry deployment (scripted)
- [x] IdentityRegistry deployment (scripted)
