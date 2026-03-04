import { ethers, network } from 'hardhat';
import * as fs from 'fs';
import * as path from 'path';

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log('Deploying upgradeable contracts with account:', deployer.address);
  console.log('Network:', network.name);

  const balance = await ethers.provider.getBalance(deployer.address);
  console.log('Account balance:', ethers.formatEther(balance), 'CTC');

  // NOTE: This script requires @openzeppelin/contracts-upgradeable
  // Install: npm install @openzeppelin/contracts-upgradeable @openzeppelin/hardhat-upgrades
  // Then refactor contracts to use UUPSUpgradeable pattern
  // See UPGRADE_GUIDE.md for the full refactoring checklist

  console.log('\n=== UPGRADEABLE DEPLOYMENT (Template) ===');
  console.log('This script is a template for mainnet proxy deployment.');
  console.log('Steps before running:');
  console.log('1. npm install @openzeppelin/contracts-upgradeable @openzeppelin/hardhat-upgrades');
  console.log('2. Refactor contracts to use initialize() instead of constructor()');
  console.log('3. Add UUPSUpgradeable to each contract');
  console.log('4. Run this script with: npx hardhat run scripts/deploy-upgradeable.ts --network creditcoin');

  // ─────────────────────────────────────────────────────────────────────────
  // Template deployment flow — uncomment and adapt once contracts are
  // refactored. The `upgrades` import comes from @openzeppelin/hardhat-upgrades.
  //
  // import { upgrades } from 'hardhat';  // add this import at the top
  // ─────────────────────────────────────────────────────────────────────────

  // // 1. IdentityRegistry (no initialize args)
  // const IdentityRegistry = await ethers.getContractFactory('IdentityRegistryV2');
  // const identityRegistry = await upgrades.deployProxy(IdentityRegistry, [], { kind: 'uups' });
  // await identityRegistry.waitForDeployment();
  // const identityRegistryAddr = await identityRegistry.getAddress();
  // console.log('IdentityRegistry proxy:', identityRegistryAddr);

  // // 2. TierRegistry (no initialize args)
  // const TierRegistry = await ethers.getContractFactory('TierRegistryV2');
  // const tierRegistry = await upgrades.deployProxy(TierRegistry, [], { kind: 'uups' });
  // await tierRegistry.waitForDeployment();
  // const tierRegistryAddr = await tierRegistry.getAddress();
  // console.log('TierRegistry proxy:', tierRegistryAddr);

  // // 3. CreditRegistry (no initialize args)
  // const CreditRegistry = await ethers.getContractFactory('CreditRegistryV2');
  // const creditRegistry = await upgrades.deployProxy(CreditRegistry, [], { kind: 'uups' });
  // await creditRegistry.waitForDeployment();
  // const creditRegistryAddr = await creditRegistry.getAddress();
  // console.log('CreditRegistry proxy:', creditRegistryAddr);

  // // 4. CollateralVault (no initialize args)
  // const CollateralVault = await ethers.getContractFactory('CollateralVaultV2');
  // const collateralVault = await upgrades.deployProxy(CollateralVault, [], { kind: 'uups' });
  // await collateralVault.waitForDeployment();
  // const collateralVaultAddr = await collateralVault.getAddress();
  // console.log('CollateralVault proxy:', collateralVaultAddr);

  // // 5. PayoutStream (no initialize args; owner set inside initialize)
  // const PayoutStream = await ethers.getContractFactory('PayoutStreamV2');
  // const payoutStream = await upgrades.deployProxy(PayoutStream, [], { kind: 'uups' });
  // await payoutStream.waitForDeployment();
  // const payoutStreamAddr = await payoutStream.getAddress();
  // console.log('PayoutStream proxy:', payoutStreamAddr);

  // // 6. EqubPool (depends on all registries + vault + payout stream)
  // const EqubPool = await ethers.getContractFactory('EqubPoolV2');
  // const equbPool = await upgrades.deployProxy(
  //   EqubPool,
  //   [payoutStreamAddr, collateralVaultAddr, creditRegistryAddr, identityRegistryAddr, tierRegistryAddr],
  //   { kind: 'uups' },
  // );
  // await equbPool.waitForDeployment();
  // const equbPoolAddr = await equbPool.getAddress();
  // console.log('EqubPool proxy:', equbPoolAddr);

  // // 7. Wire PayoutStream -> EqubPool
  // const setEqubTx = await payoutStream.setEqubPool(equbPoolAddr);
  // await setEqubTx.wait();
  // console.log('PayoutStream wired to EqubPool');

  // // 8. EqubGovernor (depends on EqubPool)
  // const EqubGovernor = await ethers.getContractFactory('EqubGovernorV2');
  // const equbGovernor = await upgrades.deployProxy(
  //   EqubGovernor,
  //   [equbPoolAddr],
  //   { kind: 'uups' },
  // );
  // await equbGovernor.waitForDeployment();
  // const equbGovernorAddr = await equbGovernor.getAddress();
  // console.log('EqubGovernor proxy:', equbGovernorAddr);

  // // 9. Wire EqubPool -> EqubGovernor
  // const setGovTx = await equbPool.setGovernor(equbGovernorAddr);
  // await setGovTx.wait();
  // console.log('EqubPool governor set');

  // // 10. SwapRouter (no initialize args)
  // const SwapRouter = await ethers.getContractFactory('SwapRouterV2');
  // const swapRouter = await upgrades.deployProxy(SwapRouter, [], { kind: 'uups' });
  // await swapRouter.waitForDeployment();
  // const swapRouterAddr = await swapRouter.getAddress();
  // console.log('SwapRouter proxy:', swapRouterAddr);

  // // 11. AchievementBadge (no initialize args)
  // const AchievementBadge = await ethers.getContractFactory('AchievementBadgeV2');
  // const achievementBadge = await upgrades.deployProxy(AchievementBadge, [], { kind: 'uups' });
  // await achievementBadge.waitForDeployment();
  // const achievementBadgeAddr = await achievementBadge.getAddress();
  // console.log('AchievementBadge proxy:', achievementBadgeAddr);

  // Save deployment info
  const deployment = {
    network: network.name,
    chainId: network.config.chainId,
    deployer: deployer.address,
    timestamp: new Date().toISOString(),
    type: 'upgradeable-template',
    note: 'This is a template. Refactor contracts to UUPS before mainnet deployment.',
    contracts: {
      // Uncomment and populate after deployment:
      // IdentityRegistry: identityRegistryAddr,
      // TierRegistry: tierRegistryAddr,
      // CreditRegistry: creditRegistryAddr,
      // CollateralVault: collateralVaultAddr,
      // PayoutStream: payoutStreamAddr,
      // EqubPool: equbPoolAddr,
      // EqubGovernor: equbGovernorAddr,
      // SwapRouter: swapRouterAddr,
      // AchievementBadge: achievementBadgeAddr,
    },
  };

  const deploymentsDir = path.join(__dirname, '..', 'deployments');
  if (!fs.existsSync(deploymentsDir)) {
    fs.mkdirSync(deploymentsDir, { recursive: true });
  }
  const filePath = path.join(deploymentsDir, `${network.name}-upgradeable.json`);
  fs.writeFileSync(filePath, JSON.stringify(deployment, null, 2));
  console.log(`\nTemplate saved to ${filePath}`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
