import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { TierConfig } from '../entities/tier-config.entity';
import { CreditScore } from '../entities/credit-score.entity';
import { Web3Service } from '../web3/web3.service';

// Minimum credit scores required for each tier
const TIER_SCORE_REQUIREMENTS: Record<number, number> = {
  0: 0,    // Anyone can join Tier 0
  1: 5,    // Need score >= 5 for Tier 1
  2: 20,   // Need score >= 20 for Tier 2
  3: 50,   // Need score >= 50 for Tier 3
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

  async getEligibility(walletAddress: string) {
    this.logger.log(`Checking tier eligibility for ${walletAddress}`);

    // Get user's credit score
    const creditScore = await this.creditScoreRepo.findOne({
      where: { walletAddress },
    });
    const score = creditScore?.score ?? 0;

    // Determine highest eligible tier
    let eligibleTier = 0;
    for (const [tier, requiredScore] of Object.entries(TIER_SCORE_REQUIREMENTS)) {
      const tierNum = Number(tier);
      if (score >= requiredScore) {
        eligibleTier = tierNum;
      }
    }

    // Get collateral rate for the eligible tier
    const tierConfig = await this.tierConfigRepo.findOne({
      where: { tier: eligibleTier },
    });

    return {
      walletAddress,
      creditScore: score,
      eligibleTier,
      collateralRate: tierConfig?.collateralRateBps ?? 0,
      maxPoolSize: tierConfig?.maxPoolSize ?? '0',
      nextTier: eligibleTier < 3 ? eligibleTier + 1 : null,
      scoreForNextTier: eligibleTier < 3
        ? TIER_SCORE_REQUIREMENTS[eligibleTier + 1]
        : null,
    };
  }

  async getAllTiers() {
    return this.tierConfigRepo.find({ order: { tier: 'ASC' } });
  }
}
