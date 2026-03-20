import { ethers, network } from 'hardhat';
import * as fs from 'fs';
import * as path from 'path';

async function main() {
  const expectedTestnetChainId = 102031;
  if (network.config.chainId !== expectedTestnetChainId) {
    throw new Error(
      `Refusing to deploy SwapRouter on chain ${network.config.chainId}. This script is testnet-only and must run on creditcoinTestnet (102031).`,
    );
  }

  const [deployer] = await ethers.getSigners();
  console.log('Deploying SwapRouter with account:', deployer.address);
  console.log('Network:', network.name, '(chain', network.config.chainId, ')');

  const balance = await ethers.provider.getBalance(deployer.address);
  console.log('Account balance:', ethers.formatEther(balance), 'CTC');
  console.log('Safety check: deploying router to Creditcoin TESTNET (102031)');

  if (balance === 0n) {
    throw new Error(
      `Deployer ${deployer.address} has 0 CTC on testnet. Fund it from the Creditcoin faucet before deploying.`,
    );
  }

  const SwapRouter = await ethers.getContractFactory('SwapRouter');
  const swapRouter = await SwapRouter.deploy();
  await swapRouter.waitForDeployment();
  const swapRouterAddress = await swapRouter.getAddress();

  console.log('SwapRouter deployed to:', swapRouterAddress);

  const deployment = {
    network: network.name,
    chainId: network.config.chainId,
    deployer: deployer.address,
    timestamp: new Date().toISOString(),
    contract: {
      SwapRouter: swapRouterAddress,
    },
  };

  const deploymentsDir = path.join(__dirname, '..', 'deployments');
  if (!fs.existsSync(deploymentsDir)) {
    fs.mkdirSync(deploymentsDir, { recursive: true });
  }

  const filePath = path.join(deploymentsDir, `${network.name}-swap-router.json`);
  fs.writeFileSync(filePath, JSON.stringify(deployment, null, 2));

  console.log(`Deployment saved to ${filePath}`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });