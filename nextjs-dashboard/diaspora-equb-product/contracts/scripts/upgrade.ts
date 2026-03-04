// Template for upgrading Diaspora Equb contracts via UUPS proxy.
//
// Usage:
//   npx hardhat run scripts/upgrade.ts --network creditcoin
//
// Prerequisites:
//   - @openzeppelin/hardhat-upgrades installed and configured
//   - Contracts deployed with deploy-upgradeable.ts
//   - New contract version compiled (e.g. EqubPoolV3)

import { ethers, network } from 'hardhat';
import * as fs from 'fs';
import * as path from 'path';

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log('Upgrading contracts with account:', deployer.address);
  console.log('Network:', network.name);

  // Load existing proxy deployment
  const deploymentsDir = path.join(__dirname, '..', 'deployments');
  const filePath = path.join(deploymentsDir, `${network.name}-upgradeable.json`);

  if (!fs.existsSync(filePath)) {
    console.error('No upgradeable deployment found. Deploy with deploy-upgradeable.ts first.');
    process.exit(1);
  }

  const deployment = JSON.parse(fs.readFileSync(filePath, 'utf8'));
  console.log('Loaded deployment from:', filePath);
  console.log('Deployed at:', deployment.timestamp);
  console.log('Existing deployment:', JSON.stringify(deployment.contracts, null, 2));

  // ─────────────────────────────────────────────────────────────────────────
  // Template upgrade flow — uncomment and adapt for your specific upgrade.
  //
  // import { upgrades } from 'hardhat';  // add this import at the top
  //
  // The OpenZeppelin upgrades plugin automatically:
  //   1. Validates storage layout compatibility
  //   2. Deploys the new implementation
  //   3. Calls upgradeTo() on the proxy
  // ─────────────────────────────────────────────────────────────────────────

  // // Example: Upgrade EqubPool from V2 to V3
  // const equbPoolProxy = deployment.contracts.EqubPool;
  // console.log(`\nUpgrading EqubPool at proxy ${equbPoolProxy}...`);
  // const EqubPoolV3 = await ethers.getContractFactory('EqubPoolV3');
  // const upgraded = await upgrades.upgradeProxy(equbPoolProxy, EqubPoolV3);
  // await upgraded.waitForDeployment();
  // console.log('EqubPool upgraded to V3');

  // // Example: Upgrade CollateralVault
  // const vaultProxy = deployment.contracts.CollateralVault;
  // const CollateralVaultV3 = await ethers.getContractFactory('CollateralVaultV3');
  // const upgradedVault = await upgrades.upgradeProxy(vaultProxy, CollateralVaultV3);
  // await upgradedVault.waitForDeployment();
  // console.log('CollateralVault upgraded');

  // // Example: Upgrade PayoutStream
  // const payoutProxy = deployment.contracts.PayoutStream;
  // const PayoutStreamV3 = await ethers.getContractFactory('PayoutStreamV3');
  // const upgradedPayout = await upgrades.upgradeProxy(payoutProxy, PayoutStreamV3);
  // await upgradedPayout.waitForDeployment();
  // console.log('PayoutStream upgraded');

  // // Example: Upgrade EqubGovernor
  // const govProxy = deployment.contracts.EqubGovernor;
  // const EqubGovernorV3 = await ethers.getContractFactory('EqubGovernorV3');
  // const upgradedGov = await upgrades.upgradeProxy(govProxy, EqubGovernorV3);
  // await upgradedGov.waitForDeployment();
  // console.log('EqubGovernor upgraded');

  // ─────────────────────────────────────────────────────────────────────────
  // Post-upgrade: update the deployment record
  // ─────────────────────────────────────────────────────────────────────────

  // deployment.lastUpgrade = {
  //   timestamp: new Date().toISOString(),
  //   upgrader: deployer.address,
  //   contracts: ['EqubPool'],
  //   fromVersion: 'V2',
  //   toVersion: 'V3',
  // };
  // fs.writeFileSync(filePath, JSON.stringify(deployment, null, 2));
  // console.log('Deployment record updated.');

  console.log('\n=== UPGRADE TEMPLATE ===');
  console.log('Uncomment and modify the upgrade commands above for your specific upgrade.');
  console.log('Always test upgrades on testnet before mainnet.');
  console.log('');
  console.log('Pre-upgrade checklist:');
  console.log('  [ ] New contract version compiles and passes all tests');
  console.log('  [ ] Storage layout is compatible (plugin validates automatically)');
  console.log('  [ ] No state variable reordering or removal');
  console.log('  [ ] New variables added only at the end, within __gap slots');
  console.log('  [ ] Tested on testnet before mainnet');
  console.log('  [ ] If using TimelockController, schedule and wait for delay');
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
