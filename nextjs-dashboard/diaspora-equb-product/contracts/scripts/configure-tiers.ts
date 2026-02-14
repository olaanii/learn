import { ethers, network } from 'hardhat';
import * as fs from 'fs';
import * as path from 'path';

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log('Configuring tiers with account:', deployer.address);
  console.log('Network:', network.name);

  // Load deployment addresses
  const deploymentsPath = path.join(
    __dirname,
    '..',
    'deployments',
    `${network.name}.json`,
  );

  if (!fs.existsSync(deploymentsPath)) {
    throw new Error(`No deployment found for network ${network.name}. Run deploy first.`);
  }

  const deployment = JSON.parse(fs.readFileSync(deploymentsPath, 'utf-8'));
  const tierRegistryAddr = deployment.contracts.TierRegistry;

  const tierRegistry = await ethers.getContractAt('TierRegistry', tierRegistryAddr);

  // Tier 0: Small pools, no collateral (new users)
  console.log('\nConfiguring Tier 0 (Starter)...');
  let tx = await tierRegistry.configureTier(
    0,
    ethers.parseEther('1'),     // max pool size: 1 CTC
    0,                           // collateral rate: 0%
    true,
  );
  await tx.wait();
  console.log('  Max pool size: 1 CTC, Collateral: 0%');

  // Tier 1: Medium pools, partial collateral
  console.log('Configuring Tier 1 (Growing)...');
  tx = await tierRegistry.configureTier(
    1,
    ethers.parseEther('10'),    // max pool size: 10 CTC
    1000,                        // collateral rate: 10%
    true,
  );
  await tx.wait();
  console.log('  Max pool size: 10 CTC, Collateral: 10%');

  // Tier 2: Large pools, reduced collateral
  console.log('Configuring Tier 2 (Proven)...');
  tx = await tierRegistry.configureTier(
    2,
    ethers.parseEther('50'),    // max pool size: 50 CTC
    500,                         // collateral rate: 5%
    true,
  );
  await tx.wait();
  console.log('  Max pool size: 50 CTC, Collateral: 5%');

  // Tier 3: Very large pools, minimal collateral
  console.log('Configuring Tier 3 (Elite)...');
  tx = await tierRegistry.configureTier(
    3,
    ethers.parseEther('200'),   // max pool size: 200 CTC
    200,                         // collateral rate: 2%
    true,
  );
  await tx.wait();
  console.log('  Max pool size: 200 CTC, Collateral: 2%');

  console.log('\nAll tiers configured successfully!');
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
