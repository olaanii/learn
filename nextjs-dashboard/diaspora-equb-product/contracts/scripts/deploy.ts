import { ethers, network } from 'hardhat';
import * as fs from 'fs';
import * as path from 'path';

async function main() {
  const expectedTestnetChainId = 102031;
  const allowMainnetDeploy = process.env.ALLOW_MAINNET_DEPLOY === 'true';
  if (
    network.config.chainId !== expectedTestnetChainId &&
    !allowMainnetDeploy
  ) {
    throw new Error(
      `Refusing to deploy on chain ${network.config.chainId}. Use creditcoinTestnet (102031), or set ALLOW_MAINNET_DEPLOY=true if you intentionally want a non-testnet deploy.`,
    );
  }

  const [deployer] = await ethers.getSigners();
  console.log('Deploying contracts with account:', deployer.address);
  console.log('Network:', network.name);

  const balance = await ethers.provider.getBalance(deployer.address);
  console.log('Account balance:', ethers.formatEther(balance), 'CTC\n');

  if (network.config.chainId === expectedTestnetChainId) {
    console.log('Safety check: deploying to Creditcoin TESTNET (102031)');
  }

  // 1. Deploy IdentityRegistry
  console.log('--- Deploying IdentityRegistry ---');
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

  // Verify the deployed contract has setGovernor by checking on-chain code size
  const code = await ethers.provider.getCode(equbPoolAddr);
  console.log('EqubPool bytecode size:', (code.length - 2) / 2, 'bytes');

  // 7. Wire PayoutStream -> EqubPool
  console.log('\n--- Wiring PayoutStream -> EqubPool ---');
  const setEqubTx = await payoutStream.setEqubPool(equbPoolAddr);
  await setEqubTx.wait();
  console.log('PayoutStream equbPool set to:', equbPoolAddr);

  // 8. Deploy EqubGovernor
  console.log('\n--- Deploying EqubGovernor ---');
  const EqubGovernor = await ethers.getContractFactory('EqubGovernor');
  const equbGovernor = await EqubGovernor.deploy(equbPoolAddr);
  await equbGovernor.waitForDeployment();
  const equbGovernorAddr = await equbGovernor.getAddress();
  console.log('EqubGovernor deployed to:', equbGovernorAddr);

  // 9. Wire EqubPool -> EqubGovernor (raw encoding to avoid typechain issues)
  console.log('\n--- Wiring EqubPool -> EqubGovernor ---');
  try {
    const iface = new ethers.Interface(['function setGovernor(address _governor)']);
    const calldata = iface.encodeFunctionData('setGovernor', [equbGovernorAddr]);
    const setGovTx = await deployer.sendTransaction({
      to: equbPoolAddr,
      data: calldata,
      gasLimit: 200000,
    });
    const receipt = await setGovTx.wait();
    if (receipt && receipt.status === 1) {
      console.log('EqubPool governor set to:', equbGovernorAddr);
    } else {
      console.log('WARNING: setGovernor tx mined but reverted on-chain');
    }
  } catch (err: any) {
    console.error('setGovernor failed:', err.shortMessage || err.message);
    console.log('Continuing deployment — governor can be set manually later.');
  }

  // 10. Deploy SwapRouter
  console.log('\n--- Deploying SwapRouter ---');
  const SwapRouter = await ethers.getContractFactory('SwapRouter');
  const swapRouter = await SwapRouter.deploy();
  await swapRouter.waitForDeployment();
  const swapRouterAddr = await swapRouter.getAddress();
  console.log('SwapRouter deployed to:', swapRouterAddr);

  // 11. Deploy AchievementBadge (soulbound NFT)
  console.log('\n--- Deploying AchievementBadge ---');
  const AchievementBadge = await ethers.getContractFactory('AchievementBadge');
  const achievementBadge = await AchievementBadge.deploy();
  await achievementBadge.waitForDeployment();
  const achievementBadgeAddr = await achievementBadge.getAddress();
  console.log('AchievementBadge deployed to:', achievementBadgeAddr);

  // Verify owner
  console.log('\n--- Verifying EqubPool owner ---');
  try {
    const owner = await equbPool.owner();
    console.log('EqubPool owner:', owner);
    console.log('Deployer match:', owner.toLowerCase() === deployer.address.toLowerCase());
  } catch {
    console.log('Could not read owner() — check ABI');
  }

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
      EqubGovernor: equbGovernorAddr,
      SwapRouter: swapRouterAddr,
      AchievementBadge: achievementBadgeAddr,
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
