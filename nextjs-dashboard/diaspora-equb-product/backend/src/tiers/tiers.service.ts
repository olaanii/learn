import { Injectable } from '@nestjs/common';

@Injectable()
export class TiersService {
  getEligibility(walletAddress: string) {
    return {
      walletAddress,
      eligibleTier: 0,
      collateralRate: 0,
    };
  }
}
