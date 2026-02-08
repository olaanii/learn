# Product Overview — Diaspora Equb DeFi (MVP)

## Goal
Enable diaspora + local users to join Equb pools where early beneficiaries cannot exit, enforced by Fayda identity, collateral logic, and smart contracts.

## Architecture
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

## Core Protections
1. **Streamed payout:** 20–30% upfront, remaining released per round.
2. **Partial collateral:** covers remaining obligations only.
3. **Smart slashing:** automatic freeze + collateral slash on default.
4. **On-chain credit:** permanent reputation updates.

## Tiered Equb Model
| Tier | Max Pool Size | Collateral | Who Can Join |
|------|---------------|------------|-------------|
| Tier 0 | Small | None / Minimal | New users |
| Tier 1 | Medium | Partial | Completed Tier 0 |
| Tier 2 | Large | Reduced | Proven users |
| Tier 3 | Very Large | Minimal | Elite users |

**Rule:** You cannot jump tiers. Trust is earned.
