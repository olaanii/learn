import { Body, Controller, Get, Header, Post, Query } from '@nestjs/common';
import {
  ApiTags,
  ApiOperation,
  ApiBearerAuth,
  ApiQuery,
} from '@nestjs/swagger';
import { SkipThrottle } from '@nestjs/throttler';
import { TokenService } from './token.service';
import {
  FaucetDto,
  GetTransactionsQueryDto,
  PortfolioQueryDto,
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
    description: 'Token symbol (USDC, USDT) or native (CTC, tCTC)',
  })
  @ApiQuery({
    name: 'tokenAddress',
    required: false,
    description: 'ERC-20 contract address (overrides symbol lookup)',
  })
  getBalance(
    @Query('walletAddress') walletAddress: string,
    @Query('token') token?: string,
    @Query('tokenAddress') tokenAddress?: string,
  ) {
    return this.tokenService.getBalance(
      walletAddress,
      token || 'USDC',
      tokenAddress,
    );
  }

  @Get('allowance')
  @ApiOperation({ summary: 'Get ERC-20 allowance for a spender' })
  @ApiQuery({ name: 'walletAddress', description: 'EVM wallet address' })
  @ApiQuery({ name: 'spender', description: 'Spender contract address' })
  @ApiQuery({
    name: 'token',
    required: false,
    description: 'Token symbol (USDC, USDT)',
  })
  @ApiQuery({
    name: 'tokenAddress',
    required: false,
    description: 'ERC-20 contract address (overrides symbol lookup)',
  })
  @ApiQuery({
    name: 'requiredAmountRaw',
    required: false,
    description: 'Optional raw amount to compare against allowance',
  })
  getAllowance(
    @Query('walletAddress') walletAddress: string,
    @Query('spender') spender: string,
    @Query('token') token?: string,
    @Query('tokenAddress') tokenAddress?: string,
    @Query('requiredAmountRaw') requiredAmountRaw?: string,
  ) {
    return this.tokenService.getAllowance(
      walletAddress,
      spender,
      token || 'USDC',
      tokenAddress,
      requiredAmountRaw,
    );
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
  @SkipThrottle()
  @Header('Cache-Control', 'public, max-age=300')
  @ApiOperation({ summary: 'Live CTC/USDC/USDT → USD rates from CoinGecko' })
  getRates() {
    return this.tokenService.getRates();
  }

  @Get('portfolio')
  @ApiOperation({ summary: 'Aggregated portfolio with USD values' })
  @ApiQuery({ name: 'wallet', description: 'EVM wallet address' })
  getPortfolio(@Query() query: PortfolioQueryDto) {
    return this.tokenService.getPortfolio(query.wallet);
  }

  @Get('exchange-rates')
  @ApiOperation({ summary: 'Get fiat exchange rates (USD base)' })
  getExchangeRates() {
    return this.tokenService.getExchangeRates();
  }

  @Get('supported')
  @ApiOperation({ summary: 'Get supported tokens for this chain' })
  getSupportedTokens() {
    return this.tokenService.getSupportedTokens();
  }
}
