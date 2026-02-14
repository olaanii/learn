import { Controller, Get, Query } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiQuery, ApiBearerAuth } from '@nestjs/swagger';
import { TiersService } from './tiers.service';

@ApiTags('Tiers')
@ApiBearerAuth()
@Controller('tiers')
export class TiersController {
  constructor(private readonly tiersService: TiersService) {}

  @Get('eligibility')
  @ApiOperation({ summary: 'Check tier eligibility for a wallet address' })
  @ApiQuery({ name: 'walletAddress', description: 'EVM wallet address' })
  eligibility(@Query('walletAddress') walletAddress: string) {
    return this.tiersService.getEligibility(walletAddress);
  }

  @Get()
  @ApiOperation({ summary: 'Get all tier configurations' })
  getAllTiers() {
    return this.tiersService.getAllTiers();
  }
}
