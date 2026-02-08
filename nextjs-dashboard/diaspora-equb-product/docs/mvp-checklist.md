# MVP Completion Checklist

## Identity & Access
- [ ] Fayda verification flow integrated
- [ ] Identity hash stored on-chain
- [ ] Wallet bound to identity hash (one-to-one)

## Equb Pool Operations
- [ ] Pool creation with tier limits
- [ ] Streamed payout schedule
- [ ] Contribution tracking by round
- [ ] Auto-freeze on missed contributions

## Collateral & Slashing
- [ ] Partial collateral based on remaining obligation
- [ ] Collateral slashing on default
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
