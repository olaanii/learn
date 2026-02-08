import { Injectable } from '@nestjs/common';

@Injectable()
export class TiersService {
  getEligibility(walletAddress: string) {
    const score = this.mockScore(walletAddress);
    const tier = this.tierFromScore(score);

    return {
      walletAddress,
      eligibleTier: tier,
      collateralRate: this.collateralRateForTier(tier),
      score,
      reason: score < 0 ? 'default-penalty' : 'score-based',
    };
  }

  private mockScore(walletAddress: string) {
    return walletAddress ? 10 : 0;
  }

  private tierFromScore(score: number) {
    if (score < 0) {
      return 0;
    }
    if (score >= 50) {
      return 3;
    }
    if (score >= 25) {
      return 2;
    }
    if (score >= 10) {
      return 1;
    }
    return 0;
  }

  private collateralRateForTier(tier: number) {
    if (tier >= 3) {
      return 5;
    }
    if (tier === 2) {
      return 10;
    }
    if (tier === 1) {
      return 20;
    }
    return 30;
  }
}
