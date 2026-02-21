import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { ethers } from 'ethers';
import { Web3Service } from '../web3/web3.service';
import { IndexerService } from '../indexer/indexer.service';

// Standard ERC-20 ABI for balance and transfer
const ERC20_ABI = [
  'function balanceOf(address owner) view returns (uint256)',
  'function decimals() view returns (uint8)',
  'function symbol() view returns (string)',
  'function name() view returns (string)',
  'function transfer(address to, uint256 amount) returns (bool)',
  'function allowance(address owner, address spender) view returns (uint256)',
  'function approve(address spender, uint256 amount) returns (bool)',
  'function faucet(uint256 amount) external',
  'function mint(address to, uint256 amount) external',
  'event Transfer(address indexed from, address indexed to, uint256 value)',
];

@Injectable()
export class TokenService {
  private readonly logger = new Logger(TokenService.name);
  private chainId: number;
  private tokenAddresses: Record<string, string> = {};

  constructor(
    private readonly web3Service: Web3Service,
    private readonly configService: ConfigService,
    private readonly indexerService: IndexerService,
  ) {
    this.chainId = this.configService.get<number>('CHAIN_ID', 102031);

    // Read token addresses from environment (deployed on Creditcoin testnet)
    this.tokenAddresses = {
      USDC: this.configService.get<string>(
        'TEST_USDC_ADDRESS',
        '0x0000000000000000000000000000000000000000',
      ),
      USDT: this.configService.get<string>(
        'TEST_USDT_ADDRESS',
        '0x0000000000000000000000000000000000000000',
      ),
    };

    this.logger.log(
      `Token service initialized on chain ${this.chainId}: USDC=${this.tokenAddresses.USDC}, USDT=${this.tokenAddresses.USDT}`,
    );
  }

  private getTokenAddress(symbol: string): string {
    const addr = this.tokenAddresses[symbol.toUpperCase()];
    if (!addr || addr === '0x0000000000000000000000000000000000000000') {
      throw new Error(
        `Token ${symbol} not deployed yet on Creditcoin (chain ${this.chainId}). ` +
        `Deploy with: npx hardhat run scripts/deploy-test-tokens.ts --network creditcoin-testnet`,
      );
    }
    return addr;
  }

  private getTokenContract(symbol: string): ethers.Contract {
    const address = this.getTokenAddress(symbol);
    return new ethers.Contract(
      address,
      ERC20_ABI,
      this.web3Service.getProvider(),
    );
  }

  /**
   * Get the USDC/USDT balance for a wallet address.
   */
  async getBalance(
    walletAddress: string,
    tokenSymbol: string = 'USDC',
  ): Promise<{
    walletAddress: string;
    token: string;
    balance: string;
    formatted: string;
    decimals: number;
  }> {
    try {
      const contract = this.getTokenContract(tokenSymbol);
      const [balance, decimals] = await Promise.all([
        contract.balanceOf(walletAddress),
        contract.decimals(),
      ]);

      return {
        walletAddress,
        token: tokenSymbol.toUpperCase(),
        balance: balance.toString(),
        formatted: ethers.formatUnits(balance, decimals),
        decimals: Number(decimals),
      };
    } catch (error) {
      this.logger.warn(
        `Failed to fetch balance for ${walletAddress}: ${error.message}`,
      );
      // Return zero balance on error (e.g. token not deployed)
      return {
        walletAddress,
        token: tokenSymbol.toUpperCase(),
        balance: '0',
        formatted: '0.00',
        decimals: 6,
      };
    }
  }

  /**
   * Get token transfer history for a wallet from the blockchain only.
   * No DB/indexer — always reads real Transfer events from Creditcoin testnet
   * so that any connected wallet (including new WalletConnect) sees its full
   * on-chain history.
   */
  async getTransactions(
    walletAddress: string,
    tokenSymbol: string = 'USDC',
    limit: number = 50,
  ): Promise<any[]> {
    return this.getTransactionsFromChain(walletAddress, tokenSymbol, limit);
  }

  /**
   * On-chain query for ERC-20 Transfer events involving this wallet.
   * Scans a large block range on Creditcoin testnet so past history always shows.
   */
  private async getTransactionsFromChain(
    walletAddress: string,
    tokenSymbol: string,
    limit: number,
  ): Promise<any[]> {
    try {
      const contract = this.getTokenContract(tokenSymbol);
      const decimals = await contract.decimals();
      const provider = this.web3Service.getProvider();
      const currentBlock = await provider.getBlockNumber();

      // Creditcoin testnet: scan enough blocks for full past history (env override optional)
      const lookback = this.configService.get<number>(
        'TX_HISTORY_LOOKBACK_BLOCKS',
        1_000_000,
      );
      const scanStart = Math.max(0, currentBlock - lookback);

      this.logger.log(
        `[Chain] ${tokenSymbol} transfers for ${walletAddress} (blocks ${scanStart}..${currentBlock})`,
      );

      const sentFilter = contract.filters.Transfer(walletAddress, null);
      const receivedFilter = contract.filters.Transfer(null, walletAddress);

      // Smaller chunks = fewer RPC failures (Creditcoin node often rejects large ranges)
      const CHUNK = 10_000;
      const MAX_RETRIES = 2;

      const queryChunk = async (
        from: number,
        to: number,
      ): Promise<{ sent: any[]; received: any[] }> => {
        const [s, r] = await Promise.all([
          contract.queryFilter(sentFilter, from, to),
          contract.queryFilter(receivedFilter, from, to),
        ]);
        return { sent: s, received: r };
      };

      let allSent: any[] = [];
      let allReceived: any[] = [];

      for (let start = scanStart; start <= currentBlock; start += CHUNK) {
        const end = Math.min(start + CHUNK - 1, currentBlock);
        let lastErr: string | null = null;

        for (let attempt = 0; attempt <= MAX_RETRIES; attempt++) {
          try {
            const { sent, received } = await queryChunk(start, end);
            allSent = allSent.concat(sent);
            allReceived = allReceived.concat(received);
            lastErr = null;
            break;
          } catch (e: any) {
            lastErr = e?.message ?? String(e);
            if (attempt < MAX_RETRIES) {
              await new Promise((r) => setTimeout(r, 1000 * (attempt + 1)));
            }
          }
        }

        if (lastErr) {
          // Last resort: try two half-chunks (avoids losing whole range)
          const mid = start + Math.floor((end - start) / 2);
          for (const [a, b] of [
            [start, mid],
            [mid + 1, end],
          ] as [number, number][]) {
            if (a > b) continue;
            try {
              const { sent, received } = await queryChunk(a, b);
              allSent = allSent.concat(sent);
              allReceived = allReceived.concat(received);
            } catch (e2: any) {
              this.logger.warn(
                `Chunk ${a}-${b} failed for ${tokenSymbol}: ${e2?.message ?? e2}`,
              );
            }
          }
        }
      }

      const allEvents = [
        ...allSent.map((event: any) => ({
          type: 'sent',
          from: event.args[0],
          to: event.args[1],
          amount: ethers.formatUnits(event.args[2], decimals),
          rawAmount: event.args[2].toString(),
          token: tokenSymbol.toUpperCase(),
          txHash: event.transactionHash,
          blockNumber: event.blockNumber,
        })),
        ...allReceived.map((event: any) => ({
          type: 'received',
          from: event.args[0],
          to: event.args[1],
          amount: ethers.formatUnits(event.args[2], decimals),
          rawAmount: event.args[2].toString(),
          token: tokenSymbol.toUpperCase(),
          txHash: event.transactionHash,
          blockNumber: event.blockNumber,
        })),
      ];

      allEvents.sort((a, b) => b.blockNumber - a.blockNumber);
      const trimmed = allEvents.slice(0, limit);

      this.logger.log(
        `Found ${allEvents.length} ${tokenSymbol} events, returning top ${trimmed.length}`,
      );

      // Resolve timestamps for each unique block
      const uniqueBlocks = [...new Set(trimmed.map((t) => t.blockNumber))];
      const blockTimestamps: Record<number, number> = {};
      await Promise.all(
        uniqueBlocks.map(async (bn) => {
          try {
            const block = await provider.getBlock(bn);
            if (block) blockTimestamps[bn] = block.timestamp;
          } catch (_e) {
            // Non-fatal
          }
        }),
      );

      return trimmed.map((tx) => ({
        ...tx,
        timestamp: blockTimestamps[tx.blockNumber]
          ? blockTimestamps[tx.blockNumber] * 1000
          : null,
      }));
    } catch (error) {
      this.logger.warn(
        `Failed to fetch on-chain transactions for ${walletAddress}: ${error.message}`,
      );
      return [];
    }
  }

  /**
   * Build unsigned transfer transaction data (non-custodial).
   * The client will sign and broadcast this.
   */
  async buildTransfer(
    from: string,
    to: string,
    amount: string,
    tokenSymbol: string = 'USDC',
  ): Promise<{
    to: string;
    data: string;
    value: string;
    chainId: number;
    tokenAddress: string;
    estimatedGas: string;
  }> {
    const tokenAddress = this.getTokenAddress(tokenSymbol);
    const contract = this.getTokenContract(tokenSymbol);
    const decimals = await contract.decimals();
    const amountWei = ethers.parseUnits(amount, decimals);

    // Encode the transfer function call
    const iface = new ethers.Interface(ERC20_ABI);
    const data = iface.encodeFunctionData('transfer', [to, amountWei]);

    // Estimate gas
    let estimatedGas = '60000'; // Default fallback
    try {
      const gasEstimate = await this.web3Service
        .getProvider()
        .estimateGas({
          from,
          to: tokenAddress,
          data,
        });
      estimatedGas = gasEstimate.toString();
    } catch (_e) {
      this.logger.warn('Gas estimation failed, using default');
    }

    return {
      to: tokenAddress,
      data,
      value: '0',
      chainId: this.chainId,
      tokenAddress,
      estimatedGas,
    };
  }

  /**
   * Mint test tokens directly to a wallet using the deployer's private key.
   * The deployer is the owner of TestToken contracts and can call mint(to, amount).
   * This executes on-chain — tokens appear in the user's balance immediately after confirmation.
   */
  async mintFaucetTokens(
    walletAddress: string,
    amount: number = 1000,
    tokenSymbol: string = 'USDC',
  ): Promise<{
    success: boolean;
    txHash?: string;
    tokenSymbol: string;
    amount: string;
    walletAddress: string;
    message: string;
  }> {
    const signer = this.web3Service.getDeployerSigner();
    if (!signer) {
      throw new Error(
        'Deployer private key not configured. Set DEPLOYER_PRIVATE_KEY in .env to use the faucet.',
      );
    }

    const tokenAddress = this.getTokenAddress(tokenSymbol);
    const contract = new ethers.Contract(tokenAddress, ERC20_ABI, signer);
    const decimals = await contract.decimals();
    const amountWei = ethers.parseUnits(amount.toString(), decimals);

    this.logger.log(
      `[FAUCET] Minting ${amount} ${tokenSymbol} to ${walletAddress} via deployer ${signer.address}...`,
    );

    try {
      // Call mint(address to, uint256 amount) — only the deployer/owner can do this
      const tx = await contract.mint(walletAddress, amountWei);
      this.logger.log(`[FAUCET] Tx sent: ${tx.hash} — waiting for confirmation...`);

      const receipt = await tx.wait();
      this.logger.log(
        `[FAUCET] Confirmed in block ${receipt.blockNumber}. ${amount} ${tokenSymbol} minted to ${walletAddress}`,
      );

      return {
        success: true,
        txHash: tx.hash,
        tokenSymbol: tokenSymbol.toUpperCase(),
        amount: amount.toString(),
        walletAddress,
        message: `${amount} ${tokenSymbol} minted to your wallet!`,
      };
    } catch (error) {
      this.logger.error(`[FAUCET] Mint failed: ${error.message}`);
      throw new Error(
        `Faucet mint failed: ${error.shortMessage || error.message}. Make sure the deployer has CTC for gas.`,
      );
    }
  }

  /**
   * Get exchange rates (mock for MVP, integrate CoinGecko/similar in prod).
   */
  async getExchangeRates(): Promise<{
    base: string;
    rates: Record<string, number>;
    updatedAt: string;
  }> {
    // For MVP: return hardcoded rates. In production, call CoinGecko API.
    return {
      base: 'USD',
      rates: {
        EUR: 0.95,
        GBP: 0.79,
        CHF: 1.10,
        ETB: 57.5,
        KES: 153.0,
      },
      updatedAt: new Date().toISOString(),
    };
  }

  /**
   * Get supported tokens for this chain.
   */
  getSupportedTokens(): { symbol: string; address: string }[] {
    return Object.entries(this.tokenAddresses)
      .filter(
        ([, addr]) => addr !== '0x0000000000000000000000000000000000000000',
      )
      .map(([symbol, address]) => ({ symbol, address }));
  }
}
