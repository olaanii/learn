import { ethers } from 'hardhat';

async function main() {
  const [deployer] = await ethers.getSigners();

  const IdentityRegistry = await ethers.getContractFactory('IdentityRegistry');
  const identityRegistry = await IdentityRegistry.deploy();
  await identityRegistry.waitForDeployment();

  const CreditRegistry = await ethers.getContractFactory('CreditRegistry');
  const creditRegistry = await CreditRegistry.deploy();
  await creditRegistry.waitForDeployment();

  const CollateralVault = await ethers.getContractFactory('CollateralVault');
  const collateralVault = await CollateralVault.deploy();
  await collateralVault.waitForDeployment();

  const PayoutStream = await ethers.getContractFactory('PayoutStream');
  const payoutStream = await PayoutStream.deploy();
  await payoutStream.waitForDeployment();

  const TierRegistry = await ethers.getContractFactory('TierRegistry');
  const tierRegistry = await TierRegistry.deploy();
  await tierRegistry.waitForDeployment();

  const EqubPool = await ethers.getContractFactory('EqubPool');
  const equbPool = await EqubPool.deploy(
    payoutStream.getAddress(),
    collateralVault.getAddress(),
    creditRegistry.getAddress(),
    identityRegistry.getAddress(),
    tierRegistry.getAddress()
  );
  await equbPool.waitForDeployment();

  const addresses = {
    deployer: deployer.address,
    identityRegistry: await identityRegistry.getAddress(),
    creditRegistry: await creditRegistry.getAddress(),
    collateralVault: await collateralVault.getAddress(),
    payoutStream: await payoutStream.getAddress(),
    tierRegistry: await tierRegistry.getAddress(),
    equbPool: await equbPool.getAddress(),
  };

  // eslint-disable-next-line no-console
  console.log('Deployed contracts:', addresses);
}

main().catch((error) => {
  // eslint-disable-next-line no-console
  console.error(error);
  process.exitCode = 1;
});
