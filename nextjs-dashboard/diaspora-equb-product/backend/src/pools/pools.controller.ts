import { Body, Controller, Post } from '@nestjs/common';
import { PoolsService } from './pools.service';

@Controller('pools')
export class PoolsController {
  constructor(private readonly poolsService: PoolsService) {}

  @Post('join')
  joinPool(@Body() body: { poolId: string; walletAddress: string }) {
    return this.poolsService.joinPool(body.poolId, body.walletAddress);
  }

  @Post('create')
  createPool(@Body() body: { tier: number; contributionAmount: number; maxMembers: number }) {
    return this.poolsService.createPool(body.tier, body.contributionAmount, body.maxMembers);
  }

  @Post('payouts/stream')
  scheduleStream(
    @Body()
    body: {
      poolId: string;
      beneficiary: string;
      total: number;
      upfrontPercent: number;
      totalRounds: number;
    }
  ) {
    return this.poolsService.scheduleStream(
      body.poolId,
      body.beneficiary,
      body.total,
      body.upfrontPercent,
      body.totalRounds
    );
  }

  @Post('rounds/close')
  closeRound(@Body() body: { poolId: string; round: number }) {
    return this.poolsService.closeRound(body.poolId, body.round);
  }

  @Post('contributions')
  recordContribution(@Body() body: { poolId: string; walletAddress: string; round: number }) {
    return this.poolsService.recordContribution(body.poolId, body.walletAddress, body.round);
  }
}
