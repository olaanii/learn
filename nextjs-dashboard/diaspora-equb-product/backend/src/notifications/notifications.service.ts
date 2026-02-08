import { Injectable } from '@nestjs/common';

@Injectable()
export class NotificationsService {
  missedPayment(walletAddress: string, poolId: string, round: number, channel?: string) {
    return {
      walletAddress,
      poolId,
      round,
      channel: channel ?? 'push',
      status: 'queued',
    };
  }
}
