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
}
