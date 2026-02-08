import { Injectable } from '@nestjs/common';

@Injectable()
export class CollateralService {
  lock(walletAddress: string, amount: number, poolId?: string) {
    return {
      walletAddress,
      amount,
      poolId,
      status: 'pending-onchain',
    };
  }

  slash(walletAddress: string, amount: number, poolId?: string) {
    return {
      walletAddress,
      amount,
      poolId,
      status: 'pending-onchain',
    };
  }
}
