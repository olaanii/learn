import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { TierConfig } from '../entities/tier-config.entity';
import { CreditScore } from '../entities/credit-score.entity';
import { Web3Service } from '../web3/web3.service';

// Minimum credit scores required for each tier (fallback when chain is unreachable)
const TIER_SCORE_REQUIREMENTS: Record<number, number> = {
  0: 0, // Anyone can join Tier 0
  1: 5, // Need score >= 5 for Tier 1
  2: 20, // Need score >= 20 for Tier 2
  3: 50, // Need score >= 50 for Tier 3
};

@Injectable()
export class TiersService {
  private readonly logger = new Logger(TiersService.name);

  constructor(
    @InjectRepository(TierConfig)
    private readonly tierConfigRepo: Repository<TierConfig>,
    @InjectRepository(CreditScore)
    private readonly creditScoreRepo: Repository<CreditScore>,
    private readonly web3Service: Web3Service,
  ) {}

  /**
   * Check tier eligibility: tries on-chain TierRegistry + CreditRegistry first,
   * falls back to DB cache if the chain is unreachable.
   */
  async getEligibility(walletAddress: string) {
    this.logger.log(`Checking tier eligibility for ${walletAddress}`);

    let score = 0;
    let source = 'cache';

    // Try on-chain credit score
    try {
      const creditRegistry = this.web3Service.getCreditRegistry();
      const onChainScore: bigint =
        await creditRegistry.scoreOf(walletAddress);
      score = Number(onChainScore);
      source = 'on-chain';
    } catch (e) {
      this.logger.warn(
        `On-chain credit read failed, using DB: ${e.message}`,
      );
      const creditScore = await this.creditScoreRepo.findOne({
        where: { walletAddress },
      });
      score = creditScore?.score ?? 0;
    }

    // Determine highest eligible tier
    let eligibleTier = 0;
    for (const [tier, requiredScore] of Object.entries(
      TIER_SCORE_REQUIREMENTS,
    )) {
      const tierNum = Number(tier);
      if (score >= requiredScore) {
        eligibleTier = tierNum;
      }
    }

    // Try on-chain tier config
    let collateralRateBps = 0;
    let maxPoolSize = '0';

    try {
      const tierRegistry = this.web3Service.getTierRegistry();
      const config = await tierRegistry.tierConfig(eligibleTier);
      maxPoolSize = config.maxPoolSize.toString();
      collateralRateBps = Number(config.collateralRateBps);
    } catch (e) {
      this.logger.warn(
        `On-chain tier config read failed, using DB: ${e.message}`,
      );
      const tierConfig = await this.tierConfigRepo.findOne({
        where: { tier: eligibleTier },
      });
      collateralRateBps = tierConfig?.collateralRateBps ?? 0;
      maxPoolSize = tierConfig?.maxPoolSize ?? '0';
    }

    return {
      walletAddress,
      creditScore: score,
      eligibleTier,
      collateralRate: collateralRateBps,
      maxPoolSize,
      nextTier: eligibleTier < 3 ? eligibleTier + 1 : null,
      scoreForNextTier:
        eligibleTier < 3
          ? TIER_SCORE_REQUIREMENTS[eligibleTier + 1]
          : null,
      source,
    };
  }

  async getAllTiers() {
    // Try reading all 4 tiers from on-chain
    try {
      const tierRegistry = this.web3Service.getTierRegistry();
      const tiers = [];
      for (let i = 0; i <= 3; i++) {
        const config = await tierRegistry.tierConfig(i);
        tiers.push({
          tier: i,
          maxPoolSize: config.maxPoolSize.toString(),
          collateralRateBps: Number(config.collateralRateBps),
          enabled: config.enabled,
          source: 'on-chain',
        });
      }
      return tiers;
    } catch (e) {
      this.logger.warn(
        `On-chain tier configs read failed, using DB: ${e.message}`,
      );
    }

    return this.tierConfigRepo.find({ order: { tier: 'ASC' } });
  }
}
