import {
  Injectable,
  Logger,
  NotFoundException,
  ConflictException,
  BadRequestException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Pool } from '../entities/pool.entity';
import { PoolMember } from '../entities/pool-member.entity';
import { Contribution } from '../entities/contribution.entity';
import { PayoutStreamEntity } from '../entities/payout-stream.entity';
import { Web3Service, UnsignedTxDto } from '../web3/web3.service';

@Injectable()
export class PoolsService {
  private readonly logger = new Logger(PoolsService.name);

  constructor(
    @InjectRepository(Pool)
    private readonly poolRepo: Repository<Pool>,
    @InjectRepository(PoolMember)
    private readonly memberRepo: Repository<PoolMember>,
    @InjectRepository(Contribution)
    private readonly contributionRepo: Repository<Contribution>,
    @InjectRepository(PayoutStreamEntity)
    private readonly payoutStreamRepo: Repository<PayoutStreamEntity>,
    private readonly web3Service: Web3Service,
  ) {}

  // ─── TX Builder Methods (return unsigned calldata for client-side signing) ───

  /**
   * Build unsigned TX to create a new Equb pool on-chain.
   * The user signs this with their wallet via WalletConnect.
   *
   * @param token - ERC-20 token address for contributions.
   *                Pass '0x0000000000000000000000000000000000000000' or undefined for native CTC.
   */
  async buildCreatePool(
    tier: number,
    contributionAmount: string,
    maxMembers: number,
    treasury: string,
    token?: string,
  ): Promise<UnsignedTxDto> {
    const tokenAddress =
      token || '0x0000000000000000000000000000000000000000';
    this.logger.log(
      `Building createPool TX: tier=${tier}, contribution=${contributionAmount}, maxMembers=${maxMembers}, token=${tokenAddress}`,
    );

    const equbPool = this.web3Service.getEqubPool();
    // Use the v2 overload that includes the token parameter
    const data = equbPool.interface.encodeFunctionData(
      'createPool(uint8,uint256,uint256,address,address)',
      [tier, contributionAmount, maxMembers, treasury, tokenAddress],
    );
    const to = await equbPool.getAddress();

    return this.web3Service.buildUnsignedTx(to, data, '0', '500000');
  }

  /**
   * Build unsigned TX to join an existing pool on-chain.
   */
  async buildJoinPool(onChainPoolId: number): Promise<UnsignedTxDto> {
    this.logger.log(`Building joinPool TX: poolId=${onChainPoolId}`);

    const equbPool = this.web3Service.getEqubPool();
    const data = equbPool.interface.encodeFunctionData('joinPool', [
      onChainPoolId,
    ]);
    const to = await equbPool.getAddress();

    return this.web3Service.buildUnsignedTx(to, data, '0', '200000');
  }

  /**
   * Build unsigned TX to contribute to a pool round on-chain.
   *
   * For native CTC pools: `value` equals the contribution amount.
   * For ERC-20 pools: `value` is 0 (user must approve first via buildApproveToken).
   *
   * @param tokenAddress - If provided, this is an ERC-20 pool (value=0).
   *                       Pass undefined or zero address for native CTC.
   */
  async buildContribute(
    onChainPoolId: number,
    contributionAmount: string,
    tokenAddress?: string,
  ): Promise<UnsignedTxDto> {
    const isErc20 =
      tokenAddress &&
      tokenAddress !== '0x0000000000000000000000000000000000000000';

    this.logger.log(
      `Building contribute TX: poolId=${onChainPoolId}, amount=${contributionAmount}, erc20=${!!isErc20}`,
    );

    const equbPool = this.web3Service.getEqubPool();
    const data = equbPool.interface.encodeFunctionData('contribute', [
      onChainPoolId,
    ]);
    const to = await equbPool.getAddress();

    // For ERC-20 pools, value is 0; for native CTC pools, value = contributionAmount
    const value = isErc20 ? '0' : contributionAmount;

    return this.web3Service.buildUnsignedTx(to, data, value, '200000');
  }

  /**
   * Build unsigned TX to approve the EqubPool contract to spend ERC-20 tokens.
   * Must be signed and sent BEFORE contributing to an ERC-20 pool.
   */
  async buildApproveToken(
    tokenAddress: string,
    amount: string,
  ): Promise<UnsignedTxDto> {
    this.logger.log(
      `Building approve TX: token=${tokenAddress}, amount=${amount}`,
    );

    const { ethers } = await import('ethers');
    const erc20Iface = new ethers.Interface([
      'function approve(address spender, uint256 amount) external returns (bool)',
    ]);

    const equbPool = this.web3Service.getEqubPool();
    const equbPoolAddress = await equbPool.getAddress();

    const data = erc20Iface.encodeFunctionData('approve', [
      equbPoolAddress,
      amount,
    ]);

    return this.web3Service.buildUnsignedTx(
      tokenAddress,
      data,
      '0',
      '60000',
    );
  }

  /**
   * Build unsigned TX to close a round on-chain.
   */
  async buildCloseRound(onChainPoolId: number): Promise<UnsignedTxDto> {
    this.logger.log(`Building closeRound TX: poolId=${onChainPoolId}`);

    const equbPool = this.web3Service.getEqubPool();
    const data = equbPool.interface.encodeFunctionData('closeRound', [
      onChainPoolId,
    ]);
    const to = await equbPool.getAddress();

    return this.web3Service.buildUnsignedTx(to, data, '0', '500000');
  }

  /**
   * Build unsigned TX to schedule a payout stream on-chain.
   */
  async buildScheduleStream(
    onChainPoolId: number,
    beneficiary: string,
    total: string,
    upfrontPercent: number,
    totalRounds: number,
  ): Promise<UnsignedTxDto> {
    this.logger.log(
      `Building schedulePayoutStream TX: poolId=${onChainPoolId}, beneficiary=${beneficiary}`,
    );

    const equbPool = this.web3Service.getEqubPool();
    const data = equbPool.interface.encodeFunctionData(
      'schedulePayoutStream',
      [onChainPoolId, beneficiary, total, upfrontPercent, totalRounds],
    );
    const to = await equbPool.getAddress();

    return this.web3Service.buildUnsignedTx(to, data, '0', '400000');
  }

  // ─── Read Methods (from DB cache, populated by Event Indexer) ───────────────

  async getPool(poolId: string) {
    const pool = await this.poolRepo.findOne({
      where: { id: poolId },
      relations: ['members', 'contributions'],
    });
    if (!pool) {
      throw new NotFoundException(`Pool ${poolId} not found`);
    }
    return pool;
  }

  /**
   * Get the ERC-20 token info for a pool.
   * Returns isErc20: true with token details for ERC-20 pools,
   * or isErc20: false for native CTC pools.
   */
  async getPoolToken(poolId: string) {
    const pool = await this.poolRepo.findOne({ where: { id: poolId } });
    if (!pool) {
      throw new NotFoundException(`Pool ${poolId} not found`);
    }

    const zeroAddress = '0x0000000000000000000000000000000000000000';
    const isErc20 = pool.token && pool.token !== zeroAddress;

    if (!isErc20) {
      return {
        poolId: pool.id,
        isErc20: false,
        token: null,
        message: 'This pool uses native CTC for contributions',
      };
    }

    // Try to read token metadata from on-chain
    try {
      const { ethers } = await import('ethers');
      const erc20Abi = [
        'function symbol() view returns (string)',
        'function decimals() view returns (uint8)',
        'function name() view returns (string)',
      ];
      const provider = this.web3Service.getProvider();
      const tokenContract = new ethers.Contract(pool.token, erc20Abi, provider);

      const [symbol, decimals, name] = await Promise.all([
        tokenContract.symbol(),
        tokenContract.decimals(),
        tokenContract.name(),
      ]);

      return {
        poolId: pool.id,
        isErc20: true,
        token: {
          address: pool.token,
          symbol,
          decimals: Number(decimals),
          name,
        },
      };
    } catch {
      return {
        poolId: pool.id,
        isErc20: true,
        token: {
          address: pool.token,
          symbol: 'UNKNOWN',
          decimals: 18,
          name: 'Unknown Token',
        },
      };
    }
  }

  async listPools(tier?: number) {
    const tierNum =
      tier !== null && tier !== undefined ? Number(tier) : undefined;
    const where =
      tierNum !== undefined && !isNaN(tierNum) ? { tier: tierNum } : {};
    return this.poolRepo.find({
      where,
      relations: ['members'],
      order: { createdAt: 'DESC' },
    });
  }

  // ─── Legacy DB Methods (kept for dev/test; indexer replaces these in prod) ──

  async createPool(
    tier: number,
    contributionAmount: string,
    maxMembers: number,
    treasury: string,
    token?: string,
  ) {
    const tokenAddress =
      token || '0x0000000000000000000000000000000000000000';

    this.logger.log(
      `Creating pool (DB-only): tier=${tier}, contribution=${contributionAmount}, maxMembers=${maxMembers}, token=${tokenAddress}`,
    );

    const pool = this.poolRepo.create({
      tier,
      contributionAmount,
      maxMembers,
      treasury,
      token: tokenAddress,
      currentRound: 1,
      status: 'pending-onchain',
    });

    const saved = await this.poolRepo.save(pool);

    return {
      id: saved.id,
      tier: saved.tier,
      contributionAmount: saved.contributionAmount,
      maxMembers: saved.maxMembers,
      treasury: saved.treasury,
      token: saved.token,
      status: saved.status,
    };
  }

  async joinPool(poolId: string, walletAddress: string) {
    this.logger.log(`User ${walletAddress} joining pool ${poolId}`);

    const pool = await this.poolRepo.findOne({
      where: { id: poolId },
      relations: ['members'],
    });
    if (!pool) {
      throw new NotFoundException(`Pool ${poolId} not found`);
    }

    if (pool.members.length >= pool.maxMembers) {
      throw new ConflictException('Pool is full');
    }

    const existingMember = await this.memberRepo.findOne({
      where: { poolId, walletAddress },
    });
    if (existingMember) {
      throw new ConflictException('Already a member of this pool');
    }

    const member = this.memberRepo.create({ poolId, walletAddress });
    await this.memberRepo.save(member);

    return {
      poolId,
      walletAddress,
      status: 'joined',
      memberCount: pool.members.length + 1,
    };
  }

  async recordContribution(
    poolId: string,
    walletAddress: string,
    round: number,
  ) {
    this.logger.log(
      `Recording contribution: pool=${poolId}, wallet=${walletAddress}, round=${round}`,
    );

    const pool = await this.poolRepo.findOne({ where: { id: poolId } });
    if (!pool) {
      throw new NotFoundException(`Pool ${poolId} not found`);
    }

    let isMember = await this.memberRepo.findOne({
      where: { poolId, walletAddress },
    });
    if (!isMember) {
      this.logger.log(
        `Recording contribution: wallet ${walletAddress} not in pool_members (e.g. joined on-chain); adding member for pool ${poolId}`,
      );
      const member = this.memberRepo.create({ poolId, walletAddress });
      await this.memberRepo.save(member);
      isMember = member;
    }

    const existing = await this.contributionRepo.findOne({
      where: { poolId, walletAddress, round },
    });
    if (existing) {
      throw new ConflictException('Already contributed for this round');
    }

    const contribution = this.contributionRepo.create({
      poolId,
      walletAddress,
      round,
      status: 'pending-onchain',
    });
    await this.contributionRepo.save(contribution);

    return {
      poolId,
      walletAddress,
      round,
      status: 'pending-onchain',
    };
  }

  async closeRound(poolId: string, round: number) {
    this.logger.log(`Closing round ${round} for pool ${poolId}`);

    const pool = await this.poolRepo.findOne({
      where: { id: poolId },
      relations: ['members'],
    });
    if (!pool) {
      throw new NotFoundException(`Pool ${poolId} not found`);
    }

    const contributions = await this.contributionRepo.find({
      where: { poolId, round },
    });
    const contributedAddresses = new Set(
      contributions.map((c) => c.walletAddress),
    );

    const contributors: string[] = [];
    const defaulters: string[] = [];

    for (const member of pool.members) {
      if (contributedAddresses.has(member.walletAddress)) {
        contributors.push(member.walletAddress);
      } else {
        defaulters.push(member.walletAddress);
      }
    }

    pool.currentRound = round + 1;
    await this.poolRepo.save(pool);

    return {
      poolId,
      round,
      contributors,
      defaulters,
      nextRound: round + 1,
      status: 'round-closed',
    };
  }

  async scheduleStream(
    poolId: string,
    beneficiary: string,
    total: string,
    upfrontPercent: number,
    totalRounds: number,
  ) {
    this.logger.log(
      `Scheduling payout stream: pool=${poolId}, beneficiary=${beneficiary}`,
    );

    const pool = await this.poolRepo.findOne({ where: { id: poolId } });
    if (!pool) {
      throw new NotFoundException(`Pool ${poolId} not found`);
    }

    if (upfrontPercent > 30) {
      throw new BadRequestException('Upfront percent cannot exceed 30%');
    }

    const totalNum = BigInt(total);
    const upfront = (totalNum * BigInt(upfrontPercent)) / BigInt(100);
    const remaining = totalNum - upfront;
    const roundAmount = remaining / BigInt(totalRounds);

    const stream = this.payoutStreamRepo.create({
      poolId,
      beneficiary,
      total,
      upfrontPercent,
      roundAmount: roundAmount.toString(),
      totalRounds,
      releasedRounds: 0,
      released: upfront.toString(),
      frozen: false,
    });
    await this.payoutStreamRepo.save(stream);

    return {
      poolId,
      beneficiary,
      total,
      upfrontPercent,
      roundAmount: roundAmount.toString(),
      totalRounds,
      status: 'stream-created',
    };
  }
}
