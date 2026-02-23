import { ethers, network } from 'hardhat';
import * as fs from 'fs';
import * as path from 'path';

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log('Deploying contracts with account:', deployer.address);
  console.log('Network:', network.name);

  const balance = await ethers.provider.getBalance(deployer.address);
  console.log('Account balance:', ethers.formatEther(balance), 'CTC');

  // 1. Deploy IdentityRegistry
  console.log('\n--- Deploying IdentityRegistry ---');
  const IdentityRegistry = await ethers.getContractFactory('IdentityRegistry');
  const identityRegistry = await IdentityRegistry.deploy();
  await identityRegistry.waitForDeployment();
  const identityRegistryAddr = await identityRegistry.getAddress();
  console.log('IdentityRegistry deployed to:', identityRegistryAddr);

  // 2. Deploy TierRegistry
  console.log('\n--- Deploying TierRegistry ---');
  const TierRegistry = await ethers.getContractFactory('TierRegistry');
  const tierRegistry = await TierRegistry.deploy();
  await tierRegistry.waitForDeployment();
  const tierRegistryAddr = await tierRegistry.getAddress();
  console.log('TierRegistry deployed to:', tierRegistryAddr);

  // 3. Deploy CreditRegistry
  console.log('\n--- Deploying CreditRegistry ---');
  const CreditRegistry = await ethers.getContractFactory('CreditRegistry');
  const creditRegistry = await CreditRegistry.deploy();
  await creditRegistry.waitForDeployment();
  const creditRegistryAddr = await creditRegistry.getAddress();
  console.log('CreditRegistry deployed to:', creditRegistryAddr);

  // 4. Deploy CollateralVault
  console.log('\n--- Deploying CollateralVault ---');
  const CollateralVault = await ethers.getContractFactory('CollateralVault');
  const collateralVault = await CollateralVault.deploy();
  await collateralVault.waitForDeployment();
  const collateralVaultAddr = await collateralVault.getAddress();
  console.log('CollateralVault deployed to:', collateralVaultAddr);

  // 5. Deploy PayoutStream
  console.log('\n--- Deploying PayoutStream ---');
  const PayoutStream = await ethers.getContractFactory('PayoutStream');
  const payoutStream = await PayoutStream.deploy();
  await payoutStream.waitForDeployment();
  const payoutStreamAddr = await payoutStream.getAddress();
  console.log('PayoutStream deployed to:', payoutStreamAddr);

  // 6. Deploy EqubPool (depends on all above)
  console.log('\n--- Deploying EqubPool ---');
  const EqubPool = await ethers.getContractFactory('EqubPool');
  const equbPool = await EqubPool.deploy(
    payoutStreamAddr,
    collateralVaultAddr,
    creditRegistryAddr,
    identityRegistryAddr,
    tierRegistryAddr,
  );
  await equbPool.waitForDeployment();
  const equbPoolAddr = await equbPool.getAddress();
  console.log('EqubPool deployed to:', equbPoolAddr);

  // 7. Wire PayoutStream to EqubPool (one-time)
  console.log('\n--- Wiring PayoutStream -> EqubPool ---');
  const setEqubTx = await payoutStream.setEqubPool(equbPoolAddr);
  await setEqubTx.wait();
  console.log('PayoutStream equbPool set to:', equbPoolAddr);

  // Save deployment addresses
  const deployment = {
    network: network.name,
    chainId: network.config.chainId,
    deployer: deployer.address,
    timestamp: new Date().toISOString(),
    contracts: {
      IdentityRegistry: identityRegistryAddr,
      TierRegistry: tierRegistryAddr,
      CreditRegistry: creditRegistryAddr,
      CollateralVault: collateralVaultAddr,
      PayoutStream: payoutStreamAddr,
      EqubPool: equbPoolAddr,
    },
  };

  const deploymentsDir = path.join(__dirname, '..', 'deployments');
  if (!fs.existsSync(deploymentsDir)) {
    fs.mkdirSync(deploymentsDir, { recursive: true });
  }

  const filePath = path.join(deploymentsDir, `${network.name}.json`);
  fs.writeFileSync(filePath, JSON.stringify(deployment, null, 2));
  console.log(`\nDeployment addresses saved to ${filePath}`);

  console.log('\n=== Deployment Summary ===');
  console.log(JSON.stringify(deployment.contracts, null, 2));
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
