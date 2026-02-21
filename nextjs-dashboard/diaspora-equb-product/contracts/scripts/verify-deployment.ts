import { ethers, network } from 'hardhat';
import * as fs from 'fs';
import * as path from 'path';

/**
 * Verify that all contracts are deployed and configured correctly on testnet.
 *
 * Usage:
 *   npx hardhat run scripts/verify-deployment.ts --network creditcoinTestnet
 */
async function main() {
  const [deployer] = await ethers.getSigners();
  console.log('Verifying deployment on:', network.name);
  console.log('Deployer:', deployer.address);

  let pass = 0;
  let fail = 0;

  const check = (label: string, ok: boolean) => {
    if (ok) {
      console.log(`  ✓ ${label}`);
      pass++;
    } else {
      console.log(`  ✗ ${label}`);
      fail++;
    }
  };

  // Load deployment files
  const deploymentsDir = path.join(__dirname, '..', 'deployments');
  const coreFile = path.join(deploymentsDir, `${network.name}.json`);
  const tokensFile = path.join(deploymentsDir, `${network.name}-tokens.json`);

  if (!fs.existsSync(coreFile)) {
    console.error(`No core deployment found: ${coreFile}`);
    console.error('Run deploy.ts first.');
    process.exit(1);
  }

  const core = JSON.parse(fs.readFileSync(coreFile, 'utf-8'));
  const contracts = core.contracts;

  console.log('\n── 1. Contract Code Exists ──────────────────');
  for (const [name, addr] of Object.entries(contracts) as [string, string][]) {
    const code = await ethers.provider.getCode(addr);
    check(`${name} (${addr})`, code !== '0x' && code.length > 2);
  }

  if (fs.existsSync(tokensFile)) {
    console.log('\n── 2. Test Tokens ──────────────────────────');
    const tokens = JSON.parse(fs.readFileSync(tokensFile, 'utf-8'));
    for (const [name, info] of Object.entries(tokens.tokens) as [string, any][]) {
      const code = await ethers.provider.getCode(info.address);
      check(`${name} (${info.address})`, code !== '0x' && code.length > 2);

      const token = await ethers.getContractAt('TestToken', info.address);
      const symbol = await token.symbol();
      check(`${name} symbol = ${symbol}`, symbol === info.symbol);

      const decimals = await token.decimals();
      check(`${name} decimals = ${decimals}`, Number(decimals) === info.decimals);
    }
  }

  console.log('\n── 3. TierRegistry Configuration ───────────');
  const tierRegistry = await ethers.getContractAt('TierRegistry', contracts.TierRegistry);

  for (let tier = 0; tier <= 3; tier++) {
    try {
      const config = await tierRegistry.getTier(tier);
      const isActive = config.active !== undefined ? config.active : true;
      check(`Tier ${tier} is configured (maxPoolSize > 0)`, config.maxPoolSize > 0n);
    } catch (e) {
      check(`Tier ${tier} readable`, false);
    }
  }

  console.log('\n── 4. EqubPool Constructor Links ───────────');
  const equbPool = await ethers.getContractAt('EqubPool', contracts.EqubPool);
  try {
    const payoutAddr = await equbPool.payoutStream();
    check(`EqubPool.payoutStream = ${payoutAddr}`, payoutAddr.toLowerCase() === contracts.PayoutStream.toLowerCase());
  } catch {
    check('EqubPool.payoutStream readable', false);
  }

  console.log('\n── 5. Deployer Balance ─────────────────────');
  const balance = await ethers.provider.getBalance(deployer.address);
  const bal = ethers.formatEther(balance);
  check(`Deployer has CTC (${bal} CTC)`, balance > 0n);

  // Summary
  console.log('\n════════════════════════════════════════════');
  console.log(`  Results: ${pass} passed, ${fail} failed`);
  console.log('════════════════════════════════════════════');

  if (fail > 0) {
    process.exit(1);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
