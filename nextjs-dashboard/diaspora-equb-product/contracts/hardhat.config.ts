import { HardhatUserConfig } from 'hardhat/config';
import '@nomicfoundation/hardhat-toolbox';
import * as dotenv from 'dotenv';

dotenv.config({ path: '../.env' });

const DEPLOYER_PRIVATE_KEY = process.env.DEPLOYER_PRIVATE_KEY || '0x0000000000000000000000000000000000000000000000000000000000000001';

const config: HardhatUserConfig = {
  solidity: {
    version: '0.8.20',
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  paths: {
    sources: './src',
    tests: './test',
    scripts: './scripts',
    cache: './cache',
    artifacts: './artifacts',
  },
  networks: {
    hardhat: {
      chainId: 31337,
    },
    localhost: {
      url: 'http://127.0.0.1:8545',
    },
    creditcoin: {
      url: process.env.RPC_URL || 'https://rpc.creditcoin.org',
      chainId: Number(process.env.CHAIN_ID) || 102030,
      accounts: [DEPLOYER_PRIVATE_KEY],
    },
    creditcoinTestnet: {
      url: 'https://rpc.cc3-testnet.creditcoin.network',
      chainId: 102031,
      accounts: [DEPLOYER_PRIVATE_KEY],
    },
  },
  etherscan: {
    apiKey: {
      creditcoin: 'no-api-key-needed',
      creditcoinTestnet: 'no-api-key-needed',
    },
    customChains: [
      {
        network: 'creditcoin',
        chainId: 102030,
        urls: {
          apiURL: 'https://creditcoin.blockscout.com/api',
          browserURL: 'https://creditcoin.blockscout.com',
        },
      },
      {
        network: 'creditcoinTestnet',
        chainId: 102031,
        urls: {
          apiURL: 'https://creditcoin-testnet.blockscout.com/api',
          browserURL: 'https://creditcoin-testnet.blockscout.com',
        },
      },
    ],
  },
  gasReporter: {
    enabled: process.env.REPORT_GAS === 'true',
    currency: 'USD',
  },
  typechain: {
    outDir: 'typechain-types',
    target: 'ethers-v6',
  },
};

export default config;
