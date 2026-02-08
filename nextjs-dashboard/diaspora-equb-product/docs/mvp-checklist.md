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
- [ ] Pool compensation from slashed funds

## Credit & Reputation
- [ ] On-chain credit score updates per round
- [ ] Tier upgrade rules enforced
- [ ] Default penalties reflected in eligibility

## Frontend
- [ ] Fayda verification screen
- [ ] Wallet binding flow
- [ ] Pool join + status screen
- [ ] Payout stream tracker
- [ ] Credit score + tier progress

## Backend
- [ ] Verify Fayda token endpoint
- [ ] Wallet binding endpoint
- [ ] Tier eligibility endpoint
- [ ] Pool join endpoint
- [ ] Notifications for missed payments

## Contracts
- [ ] EqubPool deployment
- [ ] PayoutStream deployment
- [ ] CollateralVault deployment
- [ ] CreditRegistry deployment
- [ ] IdentityRegistry deployment
