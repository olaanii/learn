import { Body, Controller, Post } from '@nestjs/common';
import { CollateralService } from './collateral.service';

@Controller('collateral')
export class CollateralController {
  constructor(private readonly collateralService: CollateralService) {}

  @Post('lock')
  lock(@Body() body: { walletAddress: string; amount: number; poolId?: string }) {
    return this.collateralService.lock(body.walletAddress, body.amount, body.poolId);
  }

  @Post('slash')
  slash(@Body() body: { walletAddress: string; amount: number; poolId?: string }) {
    return this.collateralService.slash(body.walletAddress, body.amount, body.poolId);
  }
}
