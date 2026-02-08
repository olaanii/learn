import { Controller, Get, Query } from '@nestjs/common';
import { TiersService } from './tiers.service';

@Controller('tiers')
export class TiersController {
  constructor(private readonly tiersService: TiersService) {}

  @Get('eligibility')
  eligibility(@Query('walletAddress') walletAddress: string) {
    return this.tiersService.getEligibility(walletAddress);
  }
}
