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
import { Web3Service } from '../web3/web3.service';

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

  async createPool(
    tier: number,
    contributionAmount: string,
    maxMembers: number,
    treasury: string,
  ) {
    this.logger.log(`Creating pool: tier=${tier}, contribution=${contributionAmount}, maxMembers=${maxMembers}`);

    const pool = this.poolRepo.create({
      tier,
      contributionAmount,
      maxMembers,
      treasury,
      currentRound: 1,
      status: 'pending-onchain',
    });

    const saved = await this.poolRepo.save(pool);

    // In production, submit the on-chain transaction:
    // const contract = this.web3Service.getEqubPool();
    // const tx = await contract.createPool(tier, contributionAmount, maxMembers, treasury);
    // const receipt = await tx.wait();
    // saved.onChainPoolId = receipt.events[0].args.poolId;
    // saved.txHash = tx.hash;
    // saved.status = 'active';
    // await this.poolRepo.save(saved);

    return {
      id: saved.id,
      tier: saved.tier,
      contributionAmount: saved.contributionAmount,
      maxMembers: saved.maxMembers,
      treasury: saved.treasury,
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

  async recordContribution(poolId: string, walletAddress: string, round: number) {
    this.logger.log(`Recording contribution: pool=${poolId}, wallet=${walletAddress}, round=${round}`);

    const pool = await this.poolRepo.findOne({ where: { id: poolId } });
    if (!pool) {
      throw new NotFoundException(`Pool ${poolId} not found`);
    }

    const isMember = await this.memberRepo.findOne({
      where: { poolId, walletAddress },
    });
    if (!isMember) {
      throw new BadRequestException('Not a member of this pool');
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

    // Get all contributions for this round
    const contributions = await this.contributionRepo.find({
      where: { poolId, round },
    });
    const contributedAddresses = new Set(contributions.map((c) => c.walletAddress));

    const contributors: string[] = [];
    const defaulters: string[] = [];

    for (const member of pool.members) {
      if (contributedAddresses.has(member.walletAddress)) {
        contributors.push(member.walletAddress);
      } else {
        defaulters.push(member.walletAddress);
      }
    }

    // Advance the round
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
    this.logger.log(`Scheduling payout stream: pool=${poolId}, beneficiary=${beneficiary}`);

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

  async listPools(tier?: number) {
    const where = tier !== undefined ? { tier } : {};
    return this.poolRepo.find({
      where,
      relations: ['members'],
      order: { createdAt: 'DESC' },
    });
  }
}
