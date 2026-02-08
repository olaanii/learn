import { Injectable } from '@nestjs/common';

@Injectable()
export class CreditService {
  updateScore(walletAddress: string, delta: number, reason?: string) {
    return {
      walletAddress,
      delta,
      reason,
      status: 'pending-onchain',
    };
  }
}
