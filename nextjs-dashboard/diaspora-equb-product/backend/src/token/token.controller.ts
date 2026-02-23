import { Body, Controller, Get, Post, Query } from '@nestjs/common';
import {
  ApiTags,
  ApiOperation,
  ApiBearerAuth,
  ApiQuery,
} from '@nestjs/swagger';
import { TokenService } from './token.service';
import {
  FaucetDto,
  GetTransactionsQueryDto,
  TransferDto,
  WithdrawDto,
} from './dto/token.dto';

@ApiTags('Token')
@ApiBearerAuth()
@Controller('token')
export class TokenController {
  constructor(private readonly tokenService: TokenService) {}

  @Get('balance')
  @ApiOperation({ summary: 'Get token balance for a wallet' })
  @ApiQuery({ name: 'walletAddress', description: 'EVM wallet address' })
  @ApiQuery({
    name: 'token',
    required: false,
    description: 'Token symbol (USDC, USDT)',
  })
  getBalance(
    @Query('walletAddress') walletAddress: string,
    @Query('token') token?: string,
  ) {
    return this.tokenService.getBalance(walletAddress, token || 'USDC');
  }

  @Get('transactions')
  @ApiOperation({ summary: 'Get recent token transactions for a wallet' })
  @ApiQuery({ name: 'walletAddress', description: 'EVM wallet address' })
  @ApiQuery({
    name: 'token',
    required: false,
    description: 'Token symbol (USDC, USDT)',
  })
  @ApiQuery({
    name: 'limit',
    required: false,
    description: 'Max transactions to return',
  })
  @ApiQuery({
    name: 'fromTimestamp',
    required: false,
    description: 'Lower bound timestamp (ms epoch, inclusive)',
  })
  @ApiQuery({
    name: 'toTimestamp',
    required: false,
    description: 'Upper bound timestamp (ms epoch, inclusive)',
  })
  @ApiQuery({
    name: 'direction',
    required: false,
    description: 'Direction filter: sent | received',
  })
  @ApiQuery({
    name: 'status',
    required: false,
    description: 'Status filter: success | failed',
  })
  @ApiQuery({
    name: 'cursor',
    required: false,
    description: 'Pagination cursor (reserved for future paging)',
  })
  getTransactions(
    @Query() query: GetTransactionsQueryDto,
  ) {
    const limitNum = query.limit != null ? Number(query.limit) : 50;
    return this.tokenService.getTransactions(
      query.walletAddress,
      query.token || 'USDC',
      Number.isFinite(limitNum) ? limitNum : 50,
      {
        fromTimestamp: query.fromTimestamp,
        toTimestamp: query.toTimestamp,
        direction: query.direction,
        status: query.status,
        cursor: query.cursor,
      },
    );
  }

  @Post('faucet')
  @ApiOperation({
    summary: 'Mint test tokens to a wallet using deployer key (testnet only)',
  })
  mintFaucet(@Body() dto: FaucetDto) {
    return this.tokenService.mintFaucetTokens(
      dto.walletAddress,
      dto.amount || 1000,
      dto.token || 'USDC',
    );
  }

  @Post('transfer')
  @ApiOperation({
    summary: 'Build unsigned transfer transaction (non-custodial)',
  })
  buildTransfer(@Body() dto: TransferDto) {
    return this.tokenService.buildTransfer(
      dto.from,
      dto.to,
      dto.amount,
      dto.token || 'USDC',
    );
  }

  @Post('withdraw')
  @ApiOperation({
    summary: 'Build unsigned withdraw transaction (non-custodial)',
  })
  buildWithdraw(@Body() dto: WithdrawDto) {
    // Withdraw is the same as transfer at the token level
    return this.tokenService.buildWithdraw(
      dto.from,
      dto.to,
      dto.amount,
      dto.token || 'USDC',
    );
  }

  @Get('rates')
  @ApiOperation({ summary: 'Get exchange rates' })
  getExchangeRates() {
    return this.tokenService.getExchangeRates();
  }

  @Get('supported')
  @ApiOperation({ summary: 'Get supported tokens for this chain' })
  getSupportedTokens() {
    return this.tokenService.getSupportedTokens();
  }
}
