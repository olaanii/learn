import { Body, Controller, Post } from '@nestjs/common';
import { NotificationsService } from './notifications.service';

@Controller('notifications')
export class NotificationsController {
  constructor(private readonly notificationsService: NotificationsService) {}

  @Post('missed-payment')
  missedPayment(
    @Body() body: { walletAddress: string; poolId: string; round: number; channel?: string }
  ) {
    return this.notificationsService.missedPayment(
      body.walletAddress,
      body.poolId,
      body.round,
      body.channel
    );
  }
}
