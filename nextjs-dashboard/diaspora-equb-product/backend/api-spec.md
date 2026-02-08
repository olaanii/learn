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

### POST /wallet/store-onchain
- Input: identityHash, walletAddress
- Output: queued on-chain storage confirmation

### GET /tiers/eligibility
- Input: walletAddress
- Output: eligibleTier, collateralRate

### POST /pools/join
- Input: poolId, walletAddress
- Output: join status

### POST /pools/create
- Input: tier, contributionAmount, maxMembers, treasury
- Output: poolId, status

### POST /pools/rounds/close
- Input: poolId, round
- Output: status

### POST /pools/contributions
- Input: poolId, walletAddress, round
- Output: status

### POST /collateral/lock
- Input: walletAddress, amount, poolId
- Output: status

### POST /collateral/slash
- Input: walletAddress, amount, poolId
- Output: status

### POST /payouts/stream
- Input: poolId, beneficiary, total, upfrontPercent, totalRounds
- Output: status

### POST /credit/update
- Input: walletAddress, delta, reason
- Output: status

### POST /notifications/missed-payment
- Input: walletAddress, poolId, round
- Output: notification status
