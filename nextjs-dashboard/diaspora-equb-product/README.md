# Diaspora Equb DeFi — Product Skeleton (Creditcoin-Compatible)

This folder contains an isolated MVP product skeleton so it does not conflict with other projects in the repo. It includes:
- **docs/**: product requirements, user flows, and architecture.
- **contracts/**: Solidity contract skeletons for Creditcoin/EVM.
- **backend/**: API surface and data flow notes (non-custodial).
- **frontend/**: Flutter app structure and screens.

## Quick Start (Docs)
- Start with `docs/product-overview.md` and `docs/user-flows.md`.
- Contract responsibilities are defined in `contracts/`.
- Backend endpoints are specified in `backend/api-spec.md`.

## Design Goals
- Fayda-based identity verification and wallet binding.
- Streamed payouts for early beneficiaries to prevent exit.
- Partial collateral based on remaining obligation.
- Automated slashing and on-chain credit registry.

## Compatibility
- EVM-compatible Solidity contracts for Creditcoin.
- Identity hash on-chain and wallet binding enforced in contracts.
- On-chain credit score for transparent reputation.
