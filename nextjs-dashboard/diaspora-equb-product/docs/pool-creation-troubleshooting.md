# Pool creation troubleshooting

If **Create pool** in the Equb app doesn’t seem to work, check the following.

## 1. Backend returns 201 but no pool appears

- **POST /api/pools/build/create 201** means the backend built the unsigned transaction successfully. The pool is **not** created until the user’s wallet **signs and sends** that transaction.

Possible causes:

| Symptom | Cause | What to do |
|--------|--------|------------|
| No wallet popup after clicking Create & Sign | Wallet not connected or WalletConnect session expired | Connect wallet (MetaMask / WalletConnect) and try again. |
| User rejects the transaction | User clicked Reject in MetaMask | Click Create again and approve the transaction. |
| "Transaction failed" or "rejected" in the app | Wrong network, insufficient gas, or RPC error | Switch MetaMask to **Creditcoin Testnet (chain ID 102031)**. Ensure the backend `RPC_URL` and `CHAIN_ID` match the app (e.g. testnet 102031). |
| Transaction succeeds (tx hash shown) but new pool not in list | Indexer has not processed the block yet | Wait a few seconds and pull-to-refresh the pool list. Ensure the **indexer is running** (backend `npm run start:dev` starts it). |

## 2. Indexer must be running

Pools that exist **on-chain** appear in the app only after the **indexer** has seen the `PoolCreated` event and inserted a row into the database. If the backend is running but the indexer is disabled or behind, new on-chain pools will not show up in **GET /api/pools** until the indexer catches up.

- Backend with indexer: when you run `npm run start:dev`, the indexer subscribes to contract events and writes to the DB.
- If the indexer fails (e.g. RPC errors, wrong contract address), new pools will not appear even if the transaction succeeded. Check backend logs for indexer errors.

## 3. Correct network (chain ID)

The app and backend are configured for **Creditcoin Testnet** (chain ID **102031**) by default. The wallet must be on the same network:

- In MetaMask: add network **Creditcoin Testnet**, chain ID **102031**, RPC e.g. `https://rpc.cc3-testnet.creditcoin.network`.
- The app now sends **chainId** in the transaction params so the wallet can switch or warn if the network is wrong.

## 4. Two types of “create” in the UI

- **Wallet connected** → **Create & Sign**: builds the TX via the API, then the user signs and sends it on-chain. The new pool appears in the list after the indexer processes `PoolCreated`.
- **Wallet not connected** → **Create**: legacy **DB-only** create (POST /pools/create). That pool has no on-chain ID and stays **pending-onchain** until a pool is created on-chain separately (same or different parameters). DB-only pools do not get an `onChainPoolId` from the indexer; only pools created via the contract do.

## 5. "Tier 0 is disabled on-chain" (400 from POST /api/pools/build/create)

The backend checks the on-chain **TierRegistry** before building a create-pool TX. If the tier you chose (e.g. tier 0) has never been configured, the API returns **400** with:

`Tier 0 is disabled on-chain. The network admin must call configureTier to enable this tier (contract: "tier disabled")`

**Fix for Creditcoin Testnet:** Configure the tiers once by running the contracts script (from the `contracts` folder, with a wallet that has CTC for gas):

```bash
cd contracts
npx hardhat run scripts/configure-tiers.ts --network creditcoinTestnet
```

This calls `configureTier` for tiers 0–3 on the deployed TierRegistry. After it succeeds, create pool again from the app. Tier 0 allows max contribution **1 CTC** per round; for larger pools use tier 1 (10 CTC) or higher.

If you use a different network, ensure a deployment file exists under `contracts/deployments/<network.name>.json` and run the script with `--network <network.name>`.

## 6. Transaction reverted on-chain

If the wallet sends the transaction but it **reverts** (e.g. "Transaction failed" with a tx hash), the contract rejected the call. Common revert reasons:

| Revert reason | Cause | Fix |
|---------------|--------|-----|
| **invalid contribution** | `contributionAmount` is 0 | Use a contribution amount &gt; 0. |
| **invalid members** | `maxMembers` ≤ 1 | Use max members &gt; 1. |
| **invalid treasury** | Treasury address is `0x0` | Set treasury to a valid wallet (e.g. connected wallet). |
| **tier disabled** | Tier is not enabled in the on-chain TierRegistry | The network admin must call `configureTier(tier, maxPoolSize, collateralRateBps, true)` on the TierRegistry contract. Until then, use a tier that is enabled, or ask the deployer to enable your tier. |
| **pool size exceeds tier** | `contributionAmount` &gt; tier’s `maxPoolSize` | Lower the contribution amount or use a higher tier that allows it. |

The backend now **validates** these before building the create-pool TX. If you get a **400** from **POST /api/pools/build/create** with a message like "Tier X is disabled on-chain" or "Contribution amount exceeds tier max pool size", fix the parameters or tier config; you will not be sent an unsigned TX that would revert.

To inspect a **failed** transaction:

1. Open [Creditcoin Testnet Blockscout](https://creditcoin-testnet.blockscout.com).
2. Paste the transaction hash (e.g. `0xfc3db45...`) in the search box.
3. Check **Status** (Failed) and the **Error** / **Revert reason** (if decoded).

That tells you exactly which `require` in the contract failed.

### "Failed 0xb39d8e65" or similar (4-byte selector)

If the app or wallet shows **Failed** followed by a short hex value like **0xb39d8e65**, that is a **custom error selector**: the first 4 bytes of the revert data. It identifies which custom error the contract (or a contract it calls) reverted with.

- **Our Equb contracts** use `require(..., "string")`, so they produce `Error(string)` (selector `0x08c379a0`), not custom selectors like `0xb39d8e65`.
- A selector like **0xb39d8e65** usually comes from:
  - An **ERC-20 token** (e.g. when contributing to a token pool: insufficient allowance, transfer failed, or token-specific rule).
  - Another **external contract** (e.g. TierRegistry, if it used custom errors on your network).

**What to do:**

1. **Look up the full tx** on [Blockscout](https://creditcoin-testnet.blockscout.com) (use the full transaction hash if you have it) and read the decoded **Revert reason** or **Internal transactions** to see which call reverted.
2. **Contribute (ERC-20 pool):** Ensure you’ve **approved** the token for the Equb pool contract and have enough balance; the token contract may revert with a custom error.
3. **Look up the selector:** Search for `0xb39d8e65` on [4byte.directory](https://www.4byte.directory/) or similar to see which error signature it matches (e.g. `InsufficientAllowance()`).

## 7. Contributing tCTC to a pool fails or is rejected

You must **contribute via the app’s Contribute button**, not by sending tCTC directly to the pool (or treasury) address. The Equb pool contract does not accept plain transfers; only the `contribute(poolId)` call with the exact `msg.value` is valid.

Common reasons contribution fails:

| Cause | Contract revert / behavior | What to do |
|--------|----------------------------|------------|
| **Not a member** | `"not member"` | Join the pool first (Join pool on-chain), then contribute. |
| **Already contributed this round** | `"already contributed"` | You can only contribute once per round. Wait for the next round or for the round to close. |
| **Wrong amount** | `"invalid amount"` | The tx must send exactly the pool’s contribution amount (in wei). The app sends this automatically when you use the Contribute button. If you created the pool with a human amount (e.g. 15 CTC), ensure creation used that in wei (e.g. 15×10¹⁸) so the pool’s on-chain amount matches what you expect. |
| **Sending tCTC directly to the pool** | Revert (no `receive()`) | Do not send tCTC from your wallet to the pool address. Use **Contribute** in the pool screen so the correct `contribute(poolId)` tx is built with the right value. |
| **ERC-20 pool** | `"do not send CTC for token pool"` or token error | For token pools, approve the token first, then contribute (the app’s “Approve & Contribute” flow). Do not send native tCTC. |

**Summary:** Join the pool → use the **Contribute** button on the pool screen → sign the transaction. Do not send tCTC directly to the pool address.

## Summary checklist

1. Wallet connected (MetaMask or WalletConnect).
2. Wallet on **Creditcoin Testnet (102031)**.
3. User approves the transaction (does not reject).
4. Backend and **indexer** are running; wait a few seconds and refresh the pool list after a successful tx.
5. If the tx reverts, check Blockscout for the revert reason; fix params or tier config and try again.
