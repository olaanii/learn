# Creditcoin Testing Guide (MVP)

This guide shows how to deploy the MVP contracts to a Creditcoin EVM network for smoke testing.

## Prerequisites
- Node.js 18+
- A funded Creditcoin EVM account for deployments

## Setup
1. Copy the environment file:
   ```bash
   cp contracts/.env.example contracts/.env
   ```
2. Set the values:
   - `CREDITCOIN_RPC_URL`: Creditcoin RPC endpoint
   - `CREDITCOIN_PRIVATE_KEY`: Deployer private key

## Deploy
```bash
cd contracts
npm install
npm run deploy:creditcoin
```

## Expected Output
The deploy script prints contract addresses:
- `IdentityRegistry`
- `CreditRegistry`
- `CollateralVault`
- `PayoutStream`
- `TierRegistry`
- `EqubPool`

## Next Steps
- Configure tier limits using `TierRegistry.configureTier`.
- Bind identities in `IdentityRegistry`.
- Create pools via `EqubPool.createPool`.
