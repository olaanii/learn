import { config as dotenvConfig } from 'dotenv';
import { HardhatUserConfig } from 'hardhat/config';
import '@nomicfoundation/hardhat-toolbox';

dotenvConfig();

const CREDITCOIN_RPC_URL = process.env.CREDITCOIN_RPC_URL ?? '';
const CREDITCOIN_PRIVATE_KEY = process.env.CREDITCOIN_PRIVATE_KEY ?? '';

const config: HardhatUserConfig = {
  solidity: '0.8.20',
  networks: {
    creditcoin: {
      url: CREDITCOIN_RPC_URL,
      accounts: CREDITCOIN_PRIVATE_KEY ? [CREDITCOIN_PRIVATE_KEY] : [],
    },
    localhost: {
      url: 'http://127.0.0.1:8545',
    },
  },
};

export default config;
