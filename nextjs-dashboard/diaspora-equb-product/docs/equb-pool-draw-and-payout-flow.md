# Equb Pool: Draw and Payout Flow

This document describes how the Equb pool works on-chain and who is responsible for starting the draw and sending the payout to the round winner.

---

## 1. Contracts involved

| Contract       | Role |
|----------------|------|
| **EqubPool**   | Pool lifecycle (create, join, contribute), round closing, credit updates, scheduling payout streams. Holds contributed tokens (ERC-20) or CTC. |
| **PayoutStream** | Tracks payout streams per (poolId, beneficiary): upfront amount, round amount, released rounds. **Does not hold or transfer funds** — accounting only. |
| **CollateralVault** | Locks collateral; used to compensate the pool when a member defaults. |
| **CreditRegistry**  | Score +/- on contribute/default. |

---

## 2. Who can call what

- **closeRound(poolId)**  
  **Anyone** can call (no `onlyTreasury` or `onlyCreator`).  
  In practice, the **pool creator (treasury)** or a designated keeper is expected to call it when the round period ends.

- **schedulePayoutStream(poolId, beneficiary, total, upfrontPercent, totalRounds)**  
  **Anyone** can call.  
  Requirement: `beneficiary` must be a **pool member**.  
  In practice, the **pool creator** calls it after deciding who won the round (the “draw”).

- **releaseRound(poolId, beneficiary)** (on PayoutStream)  
  **Anyone** can call.  
  Updates stream state (released amount, released rounds). Does **not** transfer tokens.

---

## 3. Intended flow (pool creator “starts the draw”)

1. **Pool creator** creates the pool with `createPool(..., treasury, token)`.  
   `treasury` is the address that receives pool-related funds (e.g. collateral compensation). It is often the pool creator.

2. Members **join** and **contribute** each round.  
   Contributions sit in the **EqubPool** contract (for ERC-20 they are `transferFrom`’d into the contract).

3. When the round period ends, the **pool creator** (or keeper):
   - Calls **closeRound(poolId)** on EqubPool.
   - Effects:
     - For each member who **did not** contribute: default logic runs (PayoutStream freeze, CollateralVault compensates pool/treasury, credit −10).
     - For each member who **did** contribute: credit +1.
     - `currentRound` is incremented.
   - The contract **does not** choose a winner or send any payout.

4. **Draw (off-chain)**  
   The pool creator (or app) decides **who wins this round** (e.g. rotation order, random draw, or other rule).  
   There is **no on-chain “draw” function**; winner selection is off-chain.

5. **Register the winner’s payout stream**  
   The pool creator (or anyone) calls:
   ```text
   EqubPool.schedulePayoutStream(poolId, winnerAddress, total, upfrontPercent, totalRounds)
   ```
   - `total`: total payout for that winner (e.g. `contributionAmount * memberCount`).
   - `upfrontPercent`: 0–30; share paid “upfront”.
   - Remaining is paid over `totalRounds` (e.g. one “round” of payout per pool round).  
   This only **registers** the stream in **PayoutStream** (upfront + per-round amounts). It does **not** move funds.

6. **Sending money to the winner**  
   - **EqubPool** holds the contributions; there is **no** on-chain function that transfers from the pool balance to the winner.
   - **PayoutStream** only updates internal state when `releaseRound` is called; it does **not** hold or send tokens.
   - So in the current implementation, **actual payment** to the winner (upfront + each release) must be done **off-chain** by the pool creator/treasury (e.g. send USDC/CTC to the winner when they schedule the stream and each time they call `releaseRound`), or by a future contract that pulls from the pool and sends to the beneficiary.

7. **Releasing stream rounds**  
   When a new pool round is released, someone (typically pool creator) calls:
   ```text
   PayoutStream.releaseRound(poolId, beneficiary)
   ```
   This updates the stream’s `released` and `releasedRounds`. The **same party** is expected to send the corresponding token amount to the winner off-chain (unless a future contract automates this).

---

## 4. Summary

| Step | Who does it | On-chain action |
|------|-------------|------------------|
| Create pool | Pool creator | `EqubPool.createPool(..., treasury, token)` |
| Join / Contribute | Members | `joinPool`, `contribute` |
| End round (start draw) | **Pool creator** (or keeper) | `EqubPool.closeRound(poolId)` |
| Choose winner | **Pool creator** (or app) | Off-chain (no contract call) |
| Register winner’s payout | **Pool creator** (or anyone) | `EqubPool.schedulePayoutStream(poolId, winner, total, upfront%, rounds)` |
| Send money to winner | **Pool creator / treasury** | Off-chain transfer (current design); PayoutStream only does accounting |
| Release next payout round | Anyone (e.g. pool creator) | `PayoutStream.releaseRound(poolId, beneficiary)` |

So: **the pool creator (or designated keeper) is the one who “starts the draw”** by calling **closeRound**, then chooses the winner off-chain and registers them with **schedulePayoutStream**. The same party is responsible for actually sending the payout to the winner (current contracts do not transfer pool funds to the beneficiary on-chain).

---

## 5. Backend / app support

- **Close round (on-chain)**  
  Backend builds the tx; frontend signs and sends:
  - `POST /api/pools/build/close-round` → returns unsigned `closeRound(poolId)` tx.
- **Schedule stream (on-chain)**  
  Backend builds the tx; frontend signs and sends:
  - `POST /api/pools/build/schedule-stream` with `onChainPoolId`, `beneficiary`, `total`, `upfrontPercent`, `totalRounds`.
- **Release round**  
  Backend does **not** expose `buildReleaseRound` yet. To support “release one round of payout” for a beneficiary, the backend would need to add an endpoint that builds `PayoutStream.releaseRound(poolId, beneficiary)` (and the actual transfer to the winner would still be off-chain unless a new contract is added).
