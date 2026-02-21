import { ethers, network } from 'hardhat';
import * as fs from 'fs';
import * as path from 'path';

/**
 * Deploy TestUSDC and TestUSDT on Creditcoin Testnet.
 *
 * Usage:
 *   npx hardhat run scripts/deploy-test-tokens.ts --network creditcoinTestnet
 *
 * After deploying, copy the printed addresses into your backend/.env:
 *   TEST_USDC_ADDRESS=0x...
 *   TEST_USDT_ADDRESS=0x...
 */
async function main() {
  const [deployer] = await ethers.getSigners();
  console.log('Deploying test tokens with account:', deployer.address);
  console.log('Network:', network.name, '(chain', network.config.chainId, ')');

  const balance = await ethers.provider.getBalance(deployer.address);
  console.log('Account balance:', ethers.formatEther(balance), 'CTC\n');

  if (balance === 0n) {
    console.error(
      'ERROR: Deployer has 0 CTC. Get testnet CTC from the Creditcoin Discord faucet:\n' +
      '  1. Join https://discord.gg/creditcoin\n' +
      '  2. Go to #token-faucet channel\n' +
      '  3. Type: /faucet address:' + deployer.address + '\n',
    );
    process.exit(1);
  }

  // Deploy TestUSDC (6 decimals, like real USDC)
  console.log('--- Deploying TestUSDC ---');
  const TestToken = await ethers.getContractFactory('TestToken');
  const usdc = await TestToken.deploy('Test USDC', 'USDC', 6);
  await usdc.waitForDeployment();
  const usdcAddr = await usdc.getAddress();
  console.log('TestUSDC deployed to:', usdcAddr);

  // Mint 1,000,000 USDC to deployer for testing
  const mintAmount = ethers.parseUnits('1000000', 6); // 1M USDC
  const mintTx = await usdc.mint(deployer.address, mintAmount);
  await mintTx.wait();
  console.log('Minted 1,000,000 USDC to deployer');

  // Deploy TestUSDT (6 decimals, like real USDT)
  console.log('\n--- Deploying TestUSDT ---');
  const usdt = await TestToken.deploy('Test USDT', 'USDT', 6);
  await usdt.waitForDeployment();
  const usdtAddr = await usdt.getAddress();
  console.log('TestUSDT deployed to:', usdtAddr);

  // Mint 1,000,000 USDT to deployer
  const mintTx2 = await usdt.mint(deployer.address, mintAmount);
  await mintTx2.wait();
  console.log('Minted 1,000,000 USDT to deployer');

  // Save deployment info
  const deployment = {
    network: network.name,
    chainId: network.config.chainId,
    deployer: deployer.address,
    timestamp: new Date().toISOString(),
    tokens: {
      TestUSDC: { address: usdcAddr, symbol: 'USDC', decimals: 6 },
      TestUSDT: { address: usdtAddr, symbol: 'USDT', decimals: 6 },
    },
  };

  const deploymentsDir = path.join(__dirname, '..', 'deployments');
  if (!fs.existsSync(deploymentsDir)) {
    fs.mkdirSync(deploymentsDir, { recursive: true });
  }
  const filePath = path.join(deploymentsDir, `${network.name}-tokens.json`);
  fs.writeFileSync(filePath, JSON.stringify(deployment, null, 2));

  console.log('\n========================================');
  console.log('  TEST TOKENS DEPLOYED SUCCESSFULLY');
  console.log('========================================');
  console.log(`  TestUSDC: ${usdcAddr}`);
  console.log(`  TestUSDT: ${usdtAddr}`);
  console.log('========================================');
  console.log('\nAdd these to your backend/.env:');
  console.log(`  TEST_USDC_ADDRESS=${usdcAddr}`);
  console.log(`  TEST_USDT_ADDRESS=${usdtAddr}`);
  console.log('\nExplorer links:');
  console.log(`  USDC: https://creditcoin-testnet.blockscout.com/address/${usdcAddr}`);
  console.log(`  USDT: https://creditcoin-testnet.blockscout.com/address/${usdtAddr}`);
  console.log('\nTo give test tokens to other wallets:');
  console.log('  - Anyone can call faucet(amount) to get up to 10,000 tokens');
  console.log('  - Or the deployer can call mint(address, amount) for larger amounts');
  console.log(`\nDeployment saved to: ${filePath}`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
