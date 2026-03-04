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
  amountIn: string;
  minAmountOut: string;
}

@ApiTags('Swap')
@ApiBearerAuth()
@Controller('api/swap')
export class SwapController {
  constructor(private readonly swapService: SwapService) {}

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
      dto.amountIn,
      dto.minAmountOut,
    );
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
