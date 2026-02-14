import { Body, Controller, Post, Get, Query } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth, ApiQuery } from '@nestjs/swagger';
import { CollateralService } from './collateral.service';
import { LockCollateralDto, SlashCollateralDto } from './dto/collateral.dto';

@ApiTags('Collateral')
@ApiBearerAuth()
@Controller('collateral')
export class CollateralController {
  constructor(private readonly collateralService: CollateralService) {}

  @Post('lock')
  @ApiOperation({ summary: 'Lock collateral for a pool' })
  lock(@Body() dto: LockCollateralDto) {
    return this.collateralService.lock(dto.walletAddress, dto.amount, dto.poolId);
  }

  @Post('slash')
  @ApiOperation({ summary: 'Slash collateral on default' })
  slash(@Body() dto: SlashCollateralDto) {
    return this.collateralService.slash(dto.walletAddress, dto.amount, dto.poolId);
  }

  @Get()
  @ApiOperation({ summary: 'Get collateral balances for a wallet' })
  @ApiQuery({ name: 'walletAddress', description: 'EVM wallet address' })
  getCollateral(@Query('walletAddress') walletAddress: string) {
    return this.collateralService.getCollateral(walletAddress);
  }
}
