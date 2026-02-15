import { Body, Controller, Post, Get, Query } from '@nestjs/common';
import {
  ApiTags,
  ApiOperation,
  ApiBearerAuth,
  ApiQuery,
} from '@nestjs/swagger';
import { CollateralService } from './collateral.service';
import { LockCollateralDto, SlashCollateralDto } from './dto/collateral.dto';

@ApiTags('Collateral')
@ApiBearerAuth()
@Controller('collateral')
export class CollateralController {
  constructor(private readonly collateralService: CollateralService) {}

  // ─── TX Builder Endpoints ───────────────────────────────────────────────────

  @Post('build/deposit')
  @ApiOperation({
    summary:
      'Build unsigned TX to deposit collateral into CollateralVault on-chain',
  })
  buildDeposit(@Body() body: { amount: string }) {
    return this.collateralService.buildDeposit(body.amount);
  }

  @Post('build/release')
  @ApiOperation({
    summary: 'Build unsigned TX to release collateral back to the user',
  })
  buildRelease(@Body() body: { userAddress: string; amount: string }) {
    return this.collateralService.buildRelease(body.userAddress, body.amount);
  }

  // ─── Read Endpoints ─────────────────────────────────────────────────────────

  @Get()
  @ApiOperation({
    summary: 'Get collateral balances (tries on-chain, falls back to cache)',
  })
  @ApiQuery({ name: 'walletAddress', description: 'EVM wallet address' })
  getCollateral(@Query('walletAddress') walletAddress: string) {
    return this.collateralService.getCollateral(walletAddress);
  }

  // ─── Legacy DB Endpoints ────────────────────────────────────────────────────

  @Post('lock')
  @ApiOperation({ summary: '[Legacy] Lock collateral in DB (dev/test)' })
  lock(@Body() dto: LockCollateralDto) {
    return this.collateralService.lock(
      dto.walletAddress,
      dto.amount,
      dto.poolId,
    );
  }

  @Post('slash')
  @ApiOperation({ summary: '[Legacy] Slash collateral in DB (dev/test)' })
  slash(@Body() dto: SlashCollateralDto) {
    return this.collateralService.slash(
      dto.walletAddress,
      dto.amount,
      dto.poolId,
    );
  }
}
