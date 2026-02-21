#!/usr/bin/env node
const ethers = require("ethers");
const path = require('path');
require('dotenv').config();
// If running from `backend` cwd, try loading project's root .env
if (!process.env.RPC_URL || !process.env.TIER_REGISTRY_ADDRESS) {
  const rootEnv = path.join(__dirname, '..', '..', '.env');
  require('dotenv').config({ path: rootEnv });
}

const RPC = process.env.RPC_URL || 'https://rpc.cc3-testnet.creditcoin.network';
const JsonRpcProvider = (ethers.providers && ethers.providers.JsonRpcProvider) || ethers.JsonRpcProvider;
if (!JsonRpcProvider) {
  console.error('Cannot find JsonRpcProvider in ethers. Please ensure ethers is installed.');
  process.exit(1);
}
const provider = new JsonRpcProvider(RPC);

async function main() {
  const txHash = process.argv[2];
  if (!txHash) {
    console.error('Usage: node backend/scripts/decode-revert.js <txHash>');
    process.exit(1);
  }

  const tx = await provider.getTransaction(txHash);
  const receipt = await provider.getTransactionReceipt(txHash);
  if (!tx) {
    console.error('Transaction not found:', txHash);
    process.exit(1);
  }

  // Try to decode transaction input to gather context (e.g., createPool params)
  let decoded = null;
  try {
    const iface = new ethers.Interface([
      'function createPool(uint8,uint256,uint256,address,address) external returns (uint256)',
      'function createPool(uint8,uint256,uint256,address) external returns (uint256)'
    ]);
    decoded = iface.parseTransaction({ data: tx.data });
    if (decoded && decoded.name && decoded.name.startsWith('createPool')) {
      console.log('Decoded call:', decoded.name, decoded.args);
      // If we have a tier arg, fetch on-chain tier config
      const tierArg = decoded.args[0];
      const tierRegistryAddr = process.env.TIER_REGISTRY_ADDRESS;
      if (tierRegistryAddr) {
        try {
          const tierIface = new ethers.Interface(['function tierConfig(uint8) external view returns (uint256,uint256,bool)']);
          const tierContract = new ethers.Contract(tierRegistryAddr, tierIface, provider);
          const cfg = await tierContract.tierConfig(tierArg);
          console.log('On-chain tier config:', cfg);
        } catch (e) {
          console.warn('Failed to fetch tier config:', e.message || e);
        }
      }
    }
  } catch (e) {
    // ignore parse errors
  }

  // If the tx targets the known EqubPool address, fetch its stored `tierRegistry` pointer
  const equbPoolAddr = process.env.EQUB_POOL_ADDRESS;
  if (equbPoolAddr && tx.to && tx.to.toLowerCase() === equbPoolAddr.toLowerCase()) {
    try {
      const poolIface = new ethers.Interface(['function tierRegistry() external view returns (address)']);
      const poolContract = new ethers.Contract(equbPoolAddr, poolIface, provider);
      const onchainTierRegistry = await poolContract.tierRegistry();
      console.log('EqubPool.tierRegistry (on-chain):', onchainTierRegistry);
    } catch (e) {
      console.warn('Failed to read EqubPool.tierRegistry:', e.message || e);
    }
  }

  try {
    // Simulate the transaction as a call at the same block to capture revert data
    await provider.call({ to: tx.to, data: tx.data, from: tx.from, value: tx.value || 0 }, receipt ? receipt.blockNumber : 'latest');
    console.log('Call succeeded (no revert returned by simulation)');
  } catch (err) {
    // Try to extract revert data from common error shapes
    let revertData = null;
    if (err && err.error && err.error.data) revertData = err.error.data;
    else if (err && err.data) revertData = err.data;
    else if (err && err.body) {
      try {
        const body = JSON.parse(err.body);
        if (body && body.error && body.error.data) revertData = body.error.data;
      } catch (e) {
        // ignore
      }
    }
    if (!revertData && typeof err === 'string' && err.startsWith('0x')) revertData = err;

    if (!revertData) {
      console.error('No revert data found in error. Full error:');
      console.error(err);
      process.exit(1);
    }

    // Standard Solidity revert reason is encoded as: 0x08c379a0 + abi.encode(string)
    // Decode manually to avoid ethers version ABI differences.
    const hex = revertData.startsWith('0x') ? revertData.slice(2) : revertData;
    if (hex.startsWith('08c379a0')) {
      // payload = offset (32 bytes) + length (32 bytes) + string
      const payload = hex.slice(8);
      const lengthHex = payload.slice(64, 128);
      const length = parseInt(lengthHex, 16);
      const stringHex = payload.slice(128, 128 + length * 2);
      const reason = Buffer.from(stringHex, 'hex').toString('utf8');
      console.log('Revert reason:', reason);
    } else {
      console.log('Revert data (hex):', revertData);
    }
  }
}

main().catch(e => {
  console.error(e);
  process.exit(1);
});
