import { Injectable } from '@nestjs/common';

@Injectable()
export class PoolsService {
  joinPool(poolId: string, walletAddress: string) {
    return {
      poolId,
      walletAddress,
      status: 'pending-onchain',
    };
  }

  createPool(tier: number, contributionAmount: number, maxMembers: number) {
    return {
      poolId: 'pending',
      tier,
      contributionAmount,
      maxMembers,
      status: 'pending-onchain',
    };
  }

  scheduleStream(
    poolId: string,
    beneficiary: string,
    total: number,
    upfrontPercent: number,
    totalRounds: number
  ) {
    return {
      poolId,
      beneficiary,
      total,
      upfrontPercent,
      totalRounds,
      status: 'pending-onchain',
    };
  }
}
