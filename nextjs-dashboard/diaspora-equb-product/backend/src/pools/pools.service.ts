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
}
