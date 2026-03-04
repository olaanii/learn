# Diaspora Equb — UUPS Proxy Upgrade Guide

## Overview

The Diaspora Equb smart contracts are currently deployed as **plain (non-upgradeable)** contracts on the Creditcoin testnet. Before mainnet launch, the core contracts should be migrated to the **UUPS (Universal Upgradeable Proxy Standard)** proxy pattern so that bug fixes, feature additions, and parameter tuning can be applied without redeploying and losing on-chain state.

This guide documents the full upgrade path: what the current architecture looks like, what needs to change, how to refactor each contract, proxy deployment procedures, state migration strategy, and operational safeguards including a `TimelockController` for admin operations.

---

## Current Architecture

All contracts use Solidity constructors and are deployed as standalone bytecode. There are no proxies, no `initialize()` functions, and no storage gap reservations.

| Contract | Constructor Args | Key State |
|---|---|---|
| `IdentityRegistry` | none | identity bindings (address → DID) |
| `TierRegistry` | none | tier configs (tier level → params) |
| `CreditRegistry` | none | credit scores (address → score) |
| `CollateralVault` | none | collateral balances, locked balances |
| `PayoutStream` | none (`owner = msg.sender`) | streams per pool/beneficiary |
| `EqubPool` | PayoutStream, CollateralVault, CreditRegistry, IdentityRegistry, TierRegistry | pools, members, rounds, rules, seasons |
| `EqubGovernor` | EqubPool | proposals, votes, cooldown timestamps |
| `SwapRouter` | none | liquidity pools, shares, reserves |
| `AchievementBadge` | none | soulbound badge NFTs |

The deployment script (`scripts/deploy.ts`) deploys each contract sequentially and wires them together (e.g., `PayoutStream.setEqubPool()`, `EqubPool.setGovernor()`).

---

## Target Architecture

Each core contract sits behind an **ERC1967 proxy** using the UUPS pattern. The proxy holds all storage; the implementation contract holds only the logic. Upgrades replace the implementation address stored in the proxy without touching storage.

```
┌──────────┐          ┌─────────────────────┐
│  Caller  │ ──call──▶│  ERC1967Proxy       │
│          │          │  (storage lives here)│
└──────────┘          │  delegatecall ──────▶│  Implementation V1
                      └─────────────────────┘  (logic only)
                               │
                      upgrade  │  UUPS: _authorizeUpgrade()
                               ▼
                      ┌─────────────────────┐
                      │  Implementation V2  │
                      │  (new logic)        │
                      └─────────────────────┘
```

### Contracts to upgrade via UUPS

| Priority | Contract | Reason |
|---|---|---|
| **P0** | `EqubPool` | Core pool state — pools, members, contributions, rounds, rules |
| **P0** | `CollateralVault` | Holds real value (collateral and locked balances) |
| **P0** | `PayoutStream` | Active payout streams with financial obligations must survive upgrades |
| **P1** | `EqubGovernor` | Governance proposals and vote history should persist across upgrades |
| **P2** | `SwapRouter` | AMM liquidity pools and LP shares; lower risk but benefits from upgradeability |
| **P2** | `AchievementBadge` | Soulbound NFTs; lower complexity but should be upgradeable for adding new badge types |

`IdentityRegistry`, `TierRegistry`, and `CreditRegistry` are smaller and simpler. They can be upgraded too, but are lower priority because they have no complex financial state. The full deployment template in `scripts/deploy-upgradeable.ts` includes them for completeness.

---

## Step-by-Step Migration

### Step 1 — Install OpenZeppelin Upgradeable Libraries

```bash
cd contracts
npm install @openzeppelin/contracts-upgradeable @openzeppelin/hardhat-upgrades
```

Then add the plugin to `hardhat.config.ts`:

```typescript
import '@openzeppelin/hardhat-upgrades';
```

This gives you:
- `Initializable`, `UUPSUpgradeable`, `OwnableUpgradeable` base contracts
- The `upgrades.deployProxy()` and `upgrades.upgradeProxy()` helpers from Hardhat
- Automatic storage layout validation at deploy and upgrade time

### Step 2 — Refactor Each Contract

Every upgradeable contract must follow three rules:

1. **Replace the constructor with `initialize()`** — constructors run on the implementation contract's own storage, not the proxy's storage. Any state set in a constructor is invisible through the proxy. The `initialize()` function uses the `initializer` modifier from OpenZeppelin to ensure it can only be called once (mimicking constructor-like one-time execution).

2. **Inherit `Initializable` and `UUPSUpgradeable`** — `Initializable` provides the `initializer` modifier; `UUPSUpgradeable` provides the `_authorizeUpgrade()` hook that gates who can trigger an upgrade. Add `OwnableUpgradeable` if the contract needs an owner (most of ours do).

3. **Reserve storage gaps** — append `uint256[50] private __gap;` at the end of each contract so future versions can add new state variables without colliding with child contract storage slots. When you add N new `uint256`-sized variables in a future version, decrease `__gap` from `[50]` to `[50 - N]`.

Additionally, every implementation contract should have a constructor that calls `_disableInitializers()`. This prevents anyone from calling `initialize()` directly on the implementation (which would be a security issue — the implementation's own storage is irrelevant, but an attacker could use it to manipulate selfdestruct or delegatecall chains).

#### Example: EqubPool with UUPS

Below is a sketch of how `EqubPool` would look after refactoring. The diff focuses on structural changes — all business logic (createPool, contribute, closeRound, etc.) stays identical.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./PayoutStream.sol";
import "./CollateralVault.sol";
import "./CreditRegistry.sol";
import "./IdentityRegistry.sol";
import "./TierRegistry.sol";
import "./IERC20.sol";

contract EqubPoolV2 is Initializable, UUPSUpgradeable, OwnableUpgradeable {

    // All existing state variables stay in the SAME declaration order.
    // CRITICAL: never reorder, remove, or insert variables above existing ones.

    struct Pool { /* unchanged from current EqubPool */ }

    PayoutStream public payoutStream;
    CollateralVault public collateralVault;
    CreditRegistry public creditRegistry;
    IdentityRegistry public identityRegistry;
    TierRegistry public tierRegistry;

    mapping(uint256 => Pool) private pools;
    uint256 public poolCount;
    address public equbGovernor;
    // `owner` is now inherited from OwnableUpgradeable — remove the manual field.

    // Reserve 50 slots for future storage additions.
    uint256[50] private __gap;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        PayoutStream _payoutStream,
        CollateralVault _collateralVault,
        CreditRegistry _creditRegistry,
        IdentityRegistry _identityRegistry,
        TierRegistry _tierRegistry
    ) public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();

        payoutStream = _payoutStream;
        collateralVault = _collateralVault;
        creditRegistry = _creditRegistry;
        identityRegistry = _identityRegistry;
        tierRegistry = _tierRegistry;
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyOwner
    {}

    // ... rest of the contract logic (createPool, joinPool, contribute,
    //     closeRound, triggerDefault, schedulePayoutStream, etc.)
    //     remains UNCHANGED ...
}
```

Key changes from the original `EqubPool`:

| Before | After |
|---|---|
| `constructor(...)` sets state | `initialize(...)` with `initializer` modifier |
| Manual `address public owner` | Inherited from `OwnableUpgradeable` |
| No upgrade hook | `_authorizeUpgrade()` restricted to `onlyOwner` |
| No storage gap | `uint256[50] private __gap` reserved |
| No `_disableInitializers()` | Constructor calls `_disableInitializers()` to block implementation init |

#### Applying the same pattern to other contracts

**CollateralVault** — has no constructor args. The `initialize()` function only needs `__Ownable_init(msg.sender)` and `__UUPSUpgradeable_init()`. All existing mappings (`collateralBalances`, `lockedBalances`) stay in the same slot positions.

**PayoutStream** — currently sets `owner = msg.sender` in the constructor. Replace the manual `owner` field with `OwnableUpgradeable` and call `__Ownable_init(msg.sender)` inside `initialize()`. The `equbPool` address is set post-deployment via `setEqubPool()` so it does not need to be an init param.

**EqubGovernor** — takes `EqubPool` as constructor arg and sets `votingPeriod = 3 days` and `cooldownPeriod = 7 days`. Move to `initialize(EqubPool _equbPool)` and set those constants there. The `equbPool`, `votingPeriod`, and `cooldownPeriod` state variables keep their existing slot positions.

**SwapRouter** — has no constructor at all. Add `initialize()` with `__Ownable_init(msg.sender)` and `__UUPSUpgradeable_init()`. All pool/share mappings stay in place. The `receive()` function works normally through proxies.

**AchievementBadge** — soulbound NFT contract. Add `initialize()` similarly. If it inherits from an ERC-721 base, switch to the upgradeable variant (`ERC721Upgradeable`).

### Step 3 — Deploy Behind ERC1967 Proxies

Use the `@openzeppelin/hardhat-upgrades` plugin which handles proxy deployment automatically:

```typescript
import { ethers, upgrades } from 'hardhat';

// Deploy implementation + proxy in one step
const CollateralVault = await ethers.getContractFactory('CollateralVaultV2');
const vault = await upgrades.deployProxy(CollateralVault, [], { kind: 'uups' });
await vault.waitForDeployment();

// Deploy EqubPool with initializer args forwarded to initialize()
const EqubPool = await ethers.getContractFactory('EqubPoolV2');
const pool = await upgrades.deployProxy(
  EqubPool,
  [payoutStreamAddr, vaultAddr, creditAddr, identityAddr, tierAddr],
  { kind: 'uups' }
);
await pool.waitForDeployment();
```

The plugin automatically:
1. Deploys the implementation contract
2. Deploys an ERC1967Proxy pointing to the implementation
3. Calls `initialize(...)` on the proxy with your arguments
4. Validates storage layout compatibility

See `scripts/deploy-upgradeable.ts` for the full template deployment script.

### Step 4 — State Migration Strategy

**Testnet (current):** Existing contracts hold testnet data in non-proxy storage. This data does NOT need to be migrated — testnet deployments can be discarded and redeployed fresh with proxies.

**Mainnet (future):** Deploy fresh with proxies from day one. There is no legacy mainnet state to migrate since mainnet has not launched yet.

If you ever need to migrate state from a non-proxy deployment to a proxy deployment on the same network (e.g., moving a live testnet with real user testing data):

1. Write a migration script that reads all relevant state from the old contracts via view functions (pool data, collateral balances, payout streams, credit scores, identity bindings).
2. Add temporary `migrateBatch(...)` admin functions to the new proxy contracts that accept arrays of state to replay.
3. Call those migration functions from the deployer account, replaying state in batches to avoid gas limits.
4. Verify every piece of state matches by comparing view function outputs between old and new contracts.
5. Point the frontend/backend configuration to the new proxy addresses.
6. Remove or disable the migration functions in the next upgrade (V3) so they cannot be called again.

### Step 5 — TimelockController for Admin Operations

For mainnet, wrap the upgrade authority behind a **TimelockController** so that upgrades have a mandatory delay (e.g., 48 hours). This gives users time to react to pending upgrades — they can exit pools or withdraw collateral if they disagree with a proposed contract change.

```solidity
// In _authorizeUpgrade, the caller must be the Timelock:
function _authorizeUpgrade(address newImplementation)
    internal
    override
    onlyOwner // owner = TimelockController address
{}
```

Setup:

1. Deploy OpenZeppelin's `TimelockController` with a **48-hour minimum delay**.
2. Configure the deployer wallet as a **proposer** (can queue upgrades) and an **executor** (can execute after delay), but the Timelock itself is the only address that can actually call `upgradeTo()`.
3. **Transfer ownership** of every proxy to the `TimelockController` address.
4. To perform an upgrade: the proposer queues the `upgradeProxy()` call on the Timelock → 48 hours pass → the executor triggers the queued transaction.
5. Consider adding a **canceller** role for emergency abort of a queued upgrade.

This ensures no single wallet can unilaterally upgrade contracts — there is always a public waiting period.

---

## Performing an Upgrade

Once contracts are deployed behind proxies, upgrading is straightforward:

```typescript
import { ethers, upgrades } from 'hardhat';

const EqubPoolV3 = await ethers.getContractFactory('EqubPoolV3');
const upgraded = await upgrades.upgradeProxy(PROXY_ADDRESS, EqubPoolV3);
console.log('EqubPool upgraded to V3 at:', await upgraded.getAddress());
```

See `scripts/upgrade.ts` for a full template.

### Pre-upgrade checklist

- [ ] New version compiles and passes all existing tests.
- [ ] Storage layout is compatible — the upgrades plugin validates automatically and will reject incompatible changes.
- [ ] No state variable reordering or removal in the new version.
- [ ] New variables added only after existing ones (or consuming slots from `__gap`).
- [ ] `__gap` size decreased by the number of new slots added.
- [ ] `_authorizeUpgrade` access control is unchanged or intentionally updated.
- [ ] Upgrade tested on a local Hardhat fork and on testnet before mainnet.
- [ ] If using TimelockController, the upgrade is scheduled and the delay has elapsed.
- [ ] Frontend/backend ABI files updated if function signatures changed.

---

## Storage Layout Safety Rules

These rules must be followed for every future version of every upgradeable contract:

1. **Never remove or reorder** existing state variables.
2. **Never change the type** of an existing variable (e.g., `uint256` to `uint128`, or `address` to `bytes32`).
3. **Never insert a new variable** between existing ones — always add at the end, before `__gap`.
4. **Decrease `__gap` size** by the number of new slots consumed (e.g., adding 2 new `uint256` variables means changing `__gap` from `[50]` to `[48]`).
5. **Never add state variables to a base contract** after it has been deployed — this shifts all child contract storage slots.
6. **Structs and mappings** are safe to extend with new fields only if appended at the end (struct fields) or using new mapping keys.
7. **Constants and immutables** do not occupy storage slots and can be freely added, removed, or reordered.

The `@openzeppelin/upgrades-core` package validates storage layout compatibility at deploy/upgrade time and will reject incompatible changes with a clear error message.

---

## Common Pitfalls

| Pitfall | Consequence | Prevention |
|---|---|---|
| Setting state in constructor | State only exists on implementation, not proxy | Use `initialize()` with `initializer` modifier |
| Forgetting `_disableInitializers()` | Attacker initializes implementation directly | Add `constructor() { _disableInitializers(); }` |
| Reordering state variables | Storage corruption — reads/writes hit wrong slots | Never reorder; append only |
| No `__gap` reservation | Future versions can't add state without collision | Always end with `uint256[50] private __gap;` |
| Calling `initialize()` twice | State overwritten or corrupted | `initializer` modifier prevents re-initialization |
| Missing `_authorizeUpgrade` | Anyone can upgrade the contract | Always implement with `onlyOwner` |

---

## File Reference

| File | Purpose |
|---|---|
| `scripts/deploy.ts` | Current non-upgradeable deployment (testnet) |
| `scripts/deploy-upgradeable.ts` | Template for deploying contracts behind UUPS proxies |
| `scripts/upgrade.ts` | Template for upgrading a deployed proxy to a new implementation |
| `UPGRADE_GUIDE.md` | This document |

---

## Timeline Recommendation

| Phase | Action |
|---|---|
| **Now (testnet)** | Continue with plain contracts for rapid iteration and feature development |
| **Pre-mainnet** | Install OZ upgradeable libraries, refactor all contracts, run full test suite with proxy deployments |
| **Mainnet launch** | Deploy all contracts behind UUPS proxies with TimelockController |
| **Post-launch** | Use `scripts/upgrade.ts` for subsequent upgrades behind the Timelock |
