import { Body, Controller, Post } from '@nestjs/common';
import { CreditService } from './credit.service';

@Controller('credit')
export class CreditController {
  constructor(private readonly creditService: CreditService) {}

  @Post('update')
  updateScore(@Body() body: { walletAddress: string; delta: number; reason?: string }) {
    return this.creditService.updateScore(body.walletAddress, body.delta, body.reason);
  }
}
