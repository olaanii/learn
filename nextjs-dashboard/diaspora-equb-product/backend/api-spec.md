# Backend API Spec (Non-Custodial)

## Responsibilities
- Fayda verification and hash receipt
- Tier eligibility checks
- Fiat ↔ crypto on/off-ramp integration
- Notifications for missed payments

**Backend never controls funds.**

## Endpoints (MVP)
### POST /auth/fayda/verify
- Input: Fayda verification token
- Output: identityHash (sha256 hash), walletBindingStatus

### POST /wallet/bind
- Input: identityHash, walletAddress
- Output: binding confirmation

### GET /tiers/eligibility
- Input: walletAddress
- Output: eligibleTier, collateralRate

### POST /pools/join
- Input: poolId, walletAddress
- Output: join status

### POST /notifications/missed-payment
- Input: walletAddress, poolId, round
- Output: notification status
