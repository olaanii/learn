import { Body, Controller, Get, Post, Query } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { SwapService } from './swap.service';

class SwapQuoteDto {
  fromToken: string;
  toToken: string;
  amountIn: string;
}

class BuildSwapTxDto {
  fromToken: string;
  toToken: string;
  amountInRaw: string;
  minAmountOutRaw: string;
}

class BuildSwapApprovalDto {
  fromToken: string;
  amountInRaw: string;
}

@ApiTags('Swap')
@ApiBearerAuth()
@Controller('swap')
export class SwapController {
  constructor(private readonly swapService: SwapService) {}

  @Get('status')
  @ApiOperation({ summary: 'Get swap router readiness and supported tokens' })
  async getStatus() {
    return this.swapService.getStatus();
  }

  @Post('quote')
  @ApiOperation({ summary: 'Get swap quote with price impact and fee' })
  async getQuote(@Body() dto: SwapQuoteDto) {
    return this.swapService.getQuote(dto.fromToken, dto.toToken, dto.amountIn);
  }

  @Post('build-tx')
  @ApiOperation({ summary: 'Build unsigned swap transaction' })
  async buildSwapTx(@Body() dto: BuildSwapTxDto) {
    return this.swapService.buildSwapTx(
      dto.fromToken,
      dto.toToken,
      dto.amountInRaw,
      dto.minAmountOutRaw,
    );
  }

  @Post('build-approval')
  @ApiOperation({ summary: 'Build unsigned approval transaction for token-to-CTC swaps' })
  async buildSwapApproval(@Body() dto: BuildSwapApprovalDto) {
    return this.swapService.buildApprovalTx(dto.fromToken, dto.amountInRaw);
  }

  @Get('reserves')
  @ApiOperation({ summary: 'Get pool reserves for a token' })
  async getReserves(@Query('token') token: string) {
    return this.swapService.getReserves(token);
  }

  @Get('history')
  @ApiOperation({ summary: 'Get swap history for a wallet (placeholder)' })
  async getHistory(@Query('wallet') wallet: string) {
    return this.swapService.getSwapHistory(wallet);
  }
}
