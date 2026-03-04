import { Injectable, Logger, NotFoundException, ForbiddenException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Pool } from '../entities/pool.entity';
import { EqubRulesEntity } from '../entities/equb-rules.entity';
import { Web3Service } from '../web3/web3.service';
import { CreateEqubRulesDto, UpdateEqubRulesDto } from './dto/equb-rules.dto';

@Injectable()
export class RulesService {
  private readonly logger = new Logger(RulesService.name);

  constructor(
    @InjectRepository(Pool)
    private readonly poolRepo: Repository<Pool>,
    @InjectRepository(EqubRulesEntity)
    private readonly rulesRepo: Repository<EqubRulesEntity>,
    private readonly web3Service: Web3Service,
  ) {}

  /**
   * Get rules for a pool. Fetches from DB if present, otherwise from chain (getRules).
   */
  async getRules(poolId: string, walletAddress?: string): Promise<Record<string, unknown>> {
    const pool = await this.poolRepo.findOne({ where: { id: poolId } });
    if (!pool) throw new NotFoundException(`Pool ${poolId} not found`);

    let rules = await this.rulesRepo.findOne({ where: { poolId } });
    if (!rules && pool.onChainPoolId != null) {
      try {
        const onChain = await this.fetchRulesFromChain(pool.onChainPoolId);
        if (onChain) {
          rules = await this.upsertRulesFromChain(poolId, pool.onChainPoolId, onChain);
          if (pool.equbType == null) {
            await this.poolRepo.update(poolId, { equbType: onChain.equbType, frequency: onChain.frequency });
          }
        }
      } catch (e) {
        this.logger.warn(`Could not fetch rules from chain for pool ${poolId}: ${e?.message ?? e}`);
      }
    }

    if (!rules) {
      return {
        equbType: 0,
        frequency: 1,
        payoutMethod: 0,
        gracePeriodSeconds: 604800,
        penaltySeverity: 10,
        roundDurationSeconds: 2592000,
        lateFeePercent: 0,
        source: 'default',
      };
    }

    return {
      equbType: rules.equbType,
      frequency: rules.frequency,
      payoutMethod: rules.payoutMethod,
      gracePeriodSeconds: rules.gracePeriodSeconds,
      penaltySeverity: rules.penaltySeverity,
      roundDurationSeconds: rules.roundDurationSeconds,
      lateFeePercent: rules.lateFeePercent,
      source: 'db',
    };
  }

  /**
   * Set rules for a pool (creator only). Creates or overwrites rules in DB.
   * On-chain rules are set at pool creation; updateRules on-chain requires EqubGovernor (P1).
   */
  async setRules(poolId: string, dto: CreateEqubRulesDto, walletAddress: string): Promise<EqubRulesEntity> {
    const pool = await this.poolRepo.findOne({ where: { id: poolId } });
    if (!pool) throw new NotFoundException(`Pool ${poolId} not found`);
    if (pool.createdBy?.toLowerCase() !== walletAddress.toLowerCase()) {
      throw new ForbiddenException('Only the pool creator can set rules');
    }

    let rules = await this.rulesRepo.findOne({ where: { poolId } });
    const data = {
      equbType: dto.equbType,
      frequency: dto.frequency,
      payoutMethod: dto.payoutMethod,
      gracePeriodSeconds: dto.gracePeriodSeconds ?? 604800,
      penaltySeverity: dto.penaltySeverity ?? 10,
      roundDurationSeconds: dto.roundDurationSeconds ?? 2592000,
      lateFeePercent: dto.lateFeePercent ?? 0,
    };

    if (rules) {
      Object.assign(rules, data);
      await this.rulesRepo.save(rules);
    } else {
      rules = this.rulesRepo.create({ poolId, ...data });
      await this.rulesRepo.save(rules);
    }

    await this.poolRepo.update(poolId, { equbType: dto.equbType, frequency: dto.frequency });
    this.logger.log(`Rules set for pool ${poolId} by ${walletAddress}`);
    return rules;
  }

  /**
   * Update rules (creator only). PATCH - partial update.
   * In P0, updates DB only; on-chain update via EqubGovernor in P1.
   */
  async updateRules(poolId: string, dto: UpdateEqubRulesDto, walletAddress: string): Promise<EqubRulesEntity> {
    const pool = await this.poolRepo.findOne({ where: { id: poolId } });
    if (!pool) throw new NotFoundException(`Pool ${poolId} not found`);
    if (pool.createdBy?.toLowerCase() !== walletAddress.toLowerCase()) {
      throw new ForbiddenException('Only the pool creator can update rules');
    }

    let rules = await this.rulesRepo.findOne({ where: { poolId } });
    if (!rules) {
      rules = this.rulesRepo.create({
        poolId,
        equbType: 0,
        frequency: 1,
        payoutMethod: 0,
        gracePeriodSeconds: 604800,
        penaltySeverity: 10,
        roundDurationSeconds: 2592000,
        lateFeePercent: 0,
      });
    }

    if (dto.equbType !== undefined) rules.equbType = dto.equbType;
    if (dto.frequency !== undefined) rules.frequency = dto.frequency;
    if (dto.payoutMethod !== undefined) rules.payoutMethod = dto.payoutMethod;
    if (dto.gracePeriodSeconds !== undefined) rules.gracePeriodSeconds = dto.gracePeriodSeconds;
    if (dto.penaltySeverity !== undefined) rules.penaltySeverity = dto.penaltySeverity;
    if (dto.roundDurationSeconds !== undefined) rules.roundDurationSeconds = dto.roundDurationSeconds;
    if (dto.lateFeePercent !== undefined) rules.lateFeePercent = dto.lateFeePercent;

    await this.rulesRepo.save(rules);
    if (dto.equbType !== undefined || dto.frequency !== undefined) {
      await this.poolRepo.update(poolId, {
        ...(dto.equbType !== undefined && { equbType: dto.equbType }),
        ...(dto.frequency !== undefined && { frequency: dto.frequency }),
      });
    }
    this.logger.log(`Rules updated for pool ${poolId} by ${walletAddress}`);
    return rules;
  }

  /**
   * Fetch rules from chain. Returns null if contract does not support getRules.
   */
  async fetchRulesFromChain(onChainPoolId: number): Promise<{
    equbType: number;
    frequency: number;
    payoutMethod: number;
    gracePeriodSeconds: number;
    penaltySeverity: number;
    roundDurationSeconds: number;
    lateFeePercent: number;
  } | null> {
    try {
      const equbPool = this.web3Service.getEqubPool();
      const raw = await equbPool.getRules(onChainPoolId);
      if (!raw) return null;
      return {
        equbType: Number(raw[0] ?? 0),
        frequency: Number(raw[1] ?? 1),
        payoutMethod: Number(raw[2] ?? 0),
        gracePeriodSeconds: Number(raw[3] ?? 604800),
        penaltySeverity: Number(raw[4] ?? 10),
        roundDurationSeconds: Number(raw[5] ?? 2592000),
        lateFeePercent: Number(raw[6] ?? 0),
      };
    } catch {
      return null;
    }
  }

  /**
   * Upsert rules from chain (used by indexer and getRules when fetching from chain).
   */
  async upsertRulesFromChain(
    poolId: string,
    onChainPoolId: number,
    rules: {
      equbType: number;
      frequency: number;
      payoutMethod: number;
      gracePeriodSeconds: number;
      penaltySeverity: number;
      roundDurationSeconds: number;
      lateFeePercent: number;
    },
  ): Promise<EqubRulesEntity> {
    let entity = await this.rulesRepo.findOne({ where: { poolId } });
    if (entity) {
      Object.assign(entity, rules);
    } else {
      entity = this.rulesRepo.create({ poolId, ...rules });
    }
    await this.rulesRepo.save(entity);
    await this.poolRepo.update(poolId, { equbType: rules.equbType, frequency: rules.frequency });
    return entity;
  }
}
