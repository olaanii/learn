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

  // ─── Native CTC TX Builder Endpoints ──────────────────────────────────────

  @Post('build/deposit')
  @ApiOperation({
    summary: 'Build unsigned TX to deposit CTC collateral on-chain',
  })
  buildDeposit(@Body() body: { amount: string }) {
    return this.collateralService.buildDeposit(body.amount);
  }

  @Post('build/release')
  @ApiOperation({
    summary: 'Build unsigned TX to release CTC collateral on-chain',
  })
  buildRelease(@Body() body: { userAddress: string; amount: string }) {
    return this.collateralService.buildRelease(body.userAddress, body.amount);
  }

  // ─── ERC-20 Token Collateral Endpoints ────────────────────────────────────

  @Post('build/deposit-token')
  @ApiOperation({
    summary:
      'Build unsigned ERC-20 transfer TX to deposit USDC/USDT as collateral',
  })
  buildDepositToken(
    @Body() body: { amount: string; tokenSymbol?: string },
  ) {
    return this.collateralService.buildDepositToken(
      body.amount,
      body.tokenSymbol ?? 'USDC',
    );
  }

  @Post('deposit-token/confirm')
  @ApiOperation({
    summary:
      'Confirm on-chain token deposit and record collateral in DB',
  })
  confirmTokenDeposit(
    @Body()
    body: {
      walletAddress: string;
      amount: string;
      tokenSymbol: string;
      txHash: string;
    },
  ) {
    return this.collateralService.confirmTokenDeposit(
      body.walletAddress,
      body.amount,
      body.tokenSymbol,
      body.txHash,
    );
  }

  @Post('release-token')
  @ApiOperation({
    summary:
      'Release token collateral: deployer sends USDC/USDT back to user',
  })
  releaseTokenCollateral(
    @Body()
    body: { walletAddress: string; amount: string; tokenSymbol?: string },
  ) {
    return this.collateralService.releaseTokenCollateral(
      body.walletAddress,
      body.amount,
      body.tokenSymbol ?? 'USDC',
    );
  }

  // ─── Read Endpoints ─────────────────────────────────────────────────────────

  @Get()
  @ApiOperation({
    summary: 'Get collateral balances (DB + on-chain)',
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
