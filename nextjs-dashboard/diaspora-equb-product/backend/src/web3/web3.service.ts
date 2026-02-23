import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { ethers } from 'ethers';

// ABI fragments for the contracts we interact with
const IDENTITY_REGISTRY_ABI = [
  'function bindIdentity(address wallet, bytes32 identityHash) external',
  'function identityOf(address wallet) external view returns (bytes32)',
  'function walletOf(bytes32 identityHash) external view returns (address)',
  'event IdentityBound(address indexed wallet, bytes32 identityHash)',
];

const TIER_REGISTRY_ABI = [
  'function configureTier(uint8 tier, uint256 maxPoolSize, uint256 collateralRateBps, bool enabled) external',
  'function tierConfig(uint8 tier) external view returns (tuple(uint256 maxPoolSize, uint256 collateralRateBps, bool enabled))',
  'event TierConfigured(uint8 indexed tier, uint256 maxPoolSize, uint256 collateralRateBps, bool enabled)',
];

const CREDIT_REGISTRY_ABI = [
  'function updateScore(address user, int256 delta) external',
  'function scoreOf(address user) external view returns (int256)',
  'event ScoreUpdated(address indexed user, int256 newScore, int256 delta)',
];

const COLLATERAL_VAULT_ABI = [
  'function depositCollateral() external payable',
  'function lockCollateral(address user, uint256 amount) external',
  'function slashCollateral(address user, uint256 amount) external',
  'function slashLocked(address user, uint256 amount) external',
  'function compensatePool(address poolTreasury, address user, uint256 amount) external',
  'function releaseCollateral(address user, uint256 amount) external',
  'function collateralOf(address user) external view returns (uint256)',
  'function lockedOf(address user) external view returns (uint256)',
  'event CollateralDeposited(address indexed user, uint256 amount)',
  'event CollateralLocked(address indexed user, uint256 amount)',
  'event CollateralSlashed(address indexed user, uint256 amount)',
];

const PAYOUT_STREAM_ABI = [
  'function createStream(uint256 poolId, address beneficiary, uint256 total, uint256 upfrontPercent, uint256 totalRounds) external',
  'function releaseRound(uint256 poolId, address beneficiary) external',
  'function freezeRemaining(uint256 poolId, address beneficiary) external',
  'function streamDetails(uint256 poolId, address beneficiary) external view returns (tuple(uint256 total, uint256 upfrontPercent, uint256 roundAmount, uint256 totalRounds, uint256 releasedRounds, uint256 released, bool frozen))',
  'event StreamCreated(uint256 indexed poolId, address indexed beneficiary, uint256 total, uint256 upfrontPercent, uint256 roundAmount, uint256 totalRounds)',
  'event RoundReleased(uint256 indexed poolId, address indexed beneficiary, uint256 amount)',
  'event StreamFrozen(uint256 indexed poolId, address indexed beneficiary)',
];

const EQUB_POOL_ABI = [
  // v2: createPool now accepts a token address (address(0) = native CTC)
  'function createPool(uint8 tier, uint256 contributionAmount, uint256 maxMembers, address treasury, address token) external returns (uint256)',
  // Legacy overload (native CTC only)
  'function createPool(uint8 tier, uint256 contributionAmount, uint256 maxMembers, address treasury) external returns (uint256)',
  'function joinPool(uint256 poolId) external',
  'function contribute(uint256 poolId) external payable',
  'function triggerDefault(uint256 poolId, address member) external',
  'function closeRound(uint256 poolId) external',
  'function hasContributed(uint256 poolId, uint256 round, address member) external view returns (bool)',
  'function schedulePayoutStream(uint256 poolId, address beneficiary, uint256 total, uint256 upfrontPercent, uint256 totalRounds) external',
  'function rotatingWinnerForLastClosedRound(uint256 poolId) external view returns (uint256 round, address winner)',
  'function winnerScheduled(uint256 poolId, uint256 round) external view returns (bool)',
  'function currentRound(uint256 poolId) external view returns (uint256)',
  'function currentSeason(uint256 poolId) external view returns (uint256)',
  'function roundWinner(uint256 poolId, uint256 round) external view returns (address)',
  'function lockPartialCollateral(uint256 poolId, address member) external',
  'function poolCount() external view returns (uint256)',
  'function poolToken(uint256 poolId) external view returns (address)',
  'event PoolCreated(uint256 indexed poolId, uint256 contributionAmount, uint256 maxMembers, address token)',
  'event JoinedPool(uint256 indexed poolId, address indexed member)',
  'event ContributionReceived(uint256 indexed poolId, address indexed member, uint256 round)',
  'event DefaultTriggered(uint256 indexed poolId, address indexed member, uint256 round)',
  'event RoundClosed(uint256 indexed poolId, uint256 round)',
];

// ERC-20 ABI fragment (for building approve TXs on the client)
const ERC20_ABI = [
  'function approve(address spender, uint256 amount) external returns (bool)',
  'function allowance(address owner, address spender) external view returns (uint256)',
  'function balanceOf(address account) external view returns (uint256)',
  'function transfer(address to, uint256 amount) external returns (bool)',
  'function transferFrom(address from, address to, uint256 amount) external returns (bool)',
  'event Transfer(address indexed from, address indexed to, uint256 value)',
  'event Approval(address indexed owner, address indexed spender, uint256 value)',
];

@Injectable()
export class Web3Service implements OnModuleInit {
  private readonly logger = new Logger(Web3Service.name);
  private provider: ethers.JsonRpcProvider;
  private deployerSigner: ethers.Wallet | null = null;
  private _chainId: number;

  private identityRegistry: ethers.Contract;
  private tierRegistry: ethers.Contract;
  private creditRegistry: ethers.Contract;
  private collateralVault: ethers.Contract;
  private payoutStream: ethers.Contract;
  private equbPool: ethers.Contract;

  constructor(private readonly configService: ConfigService) {}

  async onModuleInit() {
    const rpcUrl = this.configService.get<string>('RPC_URL');
    const chainId = this.configService.get<number>('CHAIN_ID', 102031);
    this._chainId = chainId;

    this.provider = new ethers.JsonRpcProvider(rpcUrl, chainId);

    // Initialize deployer signer if private key is available (for dev faucet minting)
    const deployerKey = this.configService.get<string>('DEPLOYER_PRIVATE_KEY');
    if (deployerKey && deployerKey !== '0x') {
      try {
        this.deployerSigner = new ethers.Wallet(deployerKey, this.provider);
        this.logger.log(`Deployer signer initialized: ${this.deployerSigner.address}`);
      } catch (e) {
        this.logger.warn(`Failed to init deployer signer: ${e.message}`);
      }
    }

    const zero = '0x0000000000000000000000000000000000000000';

    this.identityRegistry = new ethers.Contract(
      this.configService.get<string>('IDENTITY_REGISTRY_ADDRESS') ?? zero,
      IDENTITY_REGISTRY_ABI,
      this.provider,
    );

    this.tierRegistry = new ethers.Contract(
      this.configService.get<string>('TIER_REGISTRY_ADDRESS') ?? zero,
      TIER_REGISTRY_ABI,
      this.provider,
    );

    this.creditRegistry = new ethers.Contract(
      this.configService.get<string>('CREDIT_REGISTRY_ADDRESS') ?? zero,
      CREDIT_REGISTRY_ABI,
      this.provider,
    );

    this.collateralVault = new ethers.Contract(
      this.configService.get<string>('COLLATERAL_VAULT_ADDRESS') ?? zero,
      COLLATERAL_VAULT_ABI,
      this.provider,
    );

    this.payoutStream = new ethers.Contract(
      this.configService.get<string>('PAYOUT_STREAM_ADDRESS') ?? zero,
      PAYOUT_STREAM_ABI,
      this.provider,
    );

    this.equbPool = new ethers.Contract(
      this.configService.get<string>('EQUB_POOL_ADDRESS') ?? zero,
      EQUB_POOL_ABI,
      this.provider,
    );

    this.logger.log('Web3 provider and contracts initialized');
  }

  getProvider(): ethers.JsonRpcProvider {
    return this.provider;
  }

  getIdentityRegistry(): ethers.Contract {
    return this.identityRegistry;
  }

  getTierRegistry(): ethers.Contract {
    return this.tierRegistry;
  }

  getCreditRegistry(): ethers.Contract {
    return this.creditRegistry;
  }

  getCollateralVault(): ethers.Contract {
    return this.collateralVault;
  }

  getPayoutStream(): ethers.Contract {
    return this.payoutStream;
  }

  getEqubPool(): ethers.Contract {
    return this.equbPool;
  }

  /**
   * Returns the deployer wallet (for dev-only operations like minting test tokens).
   * Returns null if deployer key is not configured.
   */
  getDeployerSigner(): ethers.Wallet | null {
    return this.deployerSigner;
  }

  /** Returns the configured chain ID (e.g. 102031 for Creditcoin Testnet). */
  getChainId(): number {
    return this._chainId;
  }

  /**
   * Helper: build an unsigned transaction object from encoded calldata.
   * The Flutter client will prompt the user's wallet to sign this.
   */
  buildUnsignedTx(
    to: string,
    data: string,
    value = '0',
    estimatedGas = '300000',
  ): UnsignedTxDto {
    return {
      to,
      data,
      value,
      chainId: this._chainId,
      estimatedGas,
    };
  }

  async isRpcHealthy(): Promise<boolean> {
    try {
      await this.provider.getBlockNumber();
      return true;
    } catch {
      return false;
    }
  }
}

/** Shape returned to the client for every write operation. */
export interface UnsignedTxDto {
  to: string;
  data: string;
  value: string;
  chainId: number;
  estimatedGas: string;
}
