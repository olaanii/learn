import {
  Body,
  Controller,
  Post,
  Get,
  Param,
  Query,
  Req,
  Headers,
} from '@nestjs/common';
import {
  ApiTags,
  ApiOperation,
  ApiBearerAuth,
  ApiQuery,
} from '@nestjs/swagger';
import { SkipThrottle } from '@nestjs/throttler';
import { PoolsService } from './pools.service';
import { SelectWinnerDto } from './dto/select-winner.dto';
import {
  CreatePoolDto,
  JoinPoolDto,
  RecordContributionDto,
  CloseRoundDto,
  ScheduleStreamDto,
  CreateSeasonDto,
} from './dto/pool.dto';

@ApiTags('Pools')
@ApiBearerAuth()
@Controller('pools')
export class PoolsController {
  constructor(private readonly poolsService: PoolsService) {}

  @Post(':id/select-winner')
  async selectWinner(
    @Param('id') id: string,
    @Body() body: SelectWinnerDto,
  ) {
    const result = await this.poolsService.buildSelectWinner(id, body as any);
    return result;
  }

  @Post(':poolId/rounds/active/close')
  async closeActiveRound(
    @Param('poolId') poolId: string,
    @Req() req: any,
  ) {
    return this.poolsService.closeActiveRound(poolId, req?.user?.walletAddress);
  }

  @Post(':poolId/rounds/active/pick-winner')
  async pickWinnerForActiveRound(
    @Param('poolId') poolId: string,
    @Body() body: { mode?: 'auto' },
    @Headers('idempotency-key') idempotencyKey: string,
    @Req() req: any,
  ) {
    return this.poolsService.pickWinnerForActiveRound({
      poolId,
      mode: body?.mode ?? 'auto',
      idempotencyKey,
      caller: req?.user?.walletAddress,
    });
  }

  @Post(':id/seasons')
  @ApiOperation({
    summary: 'Create Season N+1 for a completed season (admin only)',
  })
  createNextSeason(
    @Param('id') id: string,
    @Body() body: CreateSeasonDto,
  ) {
    return this.poolsService.createNextSeason(id, body);
  }

  // ─── TX Builder Endpoints (non-custodial: return unsigned TX for wallet signing) ──

  @Post('build/create')
  @ApiOperation({
    summary:
      'Build unsigned TX to create a new Equb pool on-chain (supports ERC-20 token)',
  })
  buildCreatePool(
    @Body() body: CreatePoolDto & { token?: string },
  ) {
    return this.poolsService.buildCreatePool(
      body.tier,
      body.contributionAmount,
      body.maxMembers,
      body.treasury,
      body.token,
    );
  }

  @Post('from-creation-tx')
  @SkipThrottle()
  @ApiOperation({
    summary:
      'Create pool from a mined createPool tx. Waits for receipt, parses PoolCreated, returns pool with onChainPoolId and status active.',
  })
  createPoolFromCreationTx(@Body() body: { txHash: string }) {
    return this.poolsService.createPoolFromCreationTx(body.txHash);
  }

  @Post('build/join')
  @ApiOperation({ summary: 'Build unsigned TX to join an existing pool' })
  buildJoinPool(@Body() body: { onChainPoolId: number; caller?: string }) {
    return this.poolsService.buildJoinPool(body.onChainPoolId, body.caller);
  }

  @Post('build/contribute')
  @ApiOperation({
    summary:
      'Build unsigned TX to contribute to a pool round (native CTC or ERC-20)',
  })
  buildContribute(
    @Body()
    body: {
      onChainPoolId: number;
      contributionAmount: string;
      tokenAddress?: string;
    },
  ) {
    return this.poolsService.buildContribute(
      body.onChainPoolId,
      body.contributionAmount,
      body.tokenAddress,
    );
  }

  @Post('build/approve-token')
  @ApiOperation({
    summary:
      'Build unsigned TX to approve EqubPool to spend ERC-20 tokens (required before contributing to an ERC-20 pool)',
  })
  buildApproveToken(
    @Body() body: { tokenAddress: string; amount: string },
  ) {
    return this.poolsService.buildApproveToken(
      body.tokenAddress,
      body.amount,
    );
  }

  @Post('build/close-round')
  @ApiOperation({ summary: 'Build unsigned TX to close a pool round' })
  buildCloseRound(@Body() body: { onChainPoolId: number }) {
    return this.poolsService.buildCloseRound(body.onChainPoolId);
  }

  @Post('build/schedule-stream')
  @ApiOperation({
    summary: 'Build unsigned TX to schedule a streamed payout',
  })
  buildScheduleStream(
    @Body()
    body: {
      onChainPoolId: number;
      beneficiary: string;
      total: string;
      upfrontPercent: number;
      totalRounds: number;
    },
  ) {
    return this.poolsService.buildScheduleStream(
      body.onChainPoolId,
      body.beneficiary,
      body.total,
      body.upfrontPercent,
      body.totalRounds,
    );
  }

  // ─── Read Endpoints (from DB cache, populated by event indexer) ───────────────

  @Get(':id/rounds/active/eligible-winners')
  @SkipThrottle()
  @ApiOperation({
    summary: 'Get eligible winner addresses for the active round (read-only)',
  })
  getEligibleWinners(@Param('id') id: string) {
    return this.poolsService.getEligibleWinners(id);
  }

  @Get(':id')
  @SkipThrottle()
  @ApiOperation({ summary: 'Get pool details by ID (from cache)' })
  getPool(@Param('id') id: string) {
    return this.poolsService.getPool(id);
  }

  @Get(':id/token')
  @ApiOperation({
    summary: 'Get the ERC-20 token info for a pool (or null for native CTC pools)',
  })
  async getPoolToken(@Param('id') id: string) {
    return this.poolsService.getPoolToken(id);
  }

  @Get()
  @ApiOperation({
    summary: 'List all pools, optionally filtered by tier (from cache)',
  })
  @ApiQuery({
    name: 'tier',
    required: false,
    description: 'Filter by tier (0-3)',
  })
  listPools(@Query('tier') tier?: string) {
    const parsed =
      tier !== undefined && tier !== null && tier !== ''
        ? Number(tier)
        : undefined;
    return this.poolsService.listPools(parsed);
  }

  // ─── Legacy DB Endpoints (kept for dev/test) ─────────────────────────────────

  @Post('create')
  @ApiOperation({
    summary: '[Legacy] Create a pool record in DB only (dev/test)',
  })
  createPool(@Body() dto: CreatePoolDto) {
    return this.poolsService.createPool(
      dto.tier,
      dto.contributionAmount,
      dto.maxMembers,
      dto.treasury,
      dto.token,
    );
  }

  @Post('join')
  @ApiOperation({ summary: '[Legacy] Join a pool in DB only (dev/test)' })
  joinPool(@Body() dto: JoinPoolDto) {
    return this.poolsService.joinPool(dto.poolId, dto.walletAddress);
  }

  @Post('contributions')
  @ApiOperation({
    summary: '[Legacy] Record a contribution in DB only (dev/test)',
  })
  recordContribution(@Body() dto: RecordContributionDto) {
    return this.poolsService.recordContribution(
      dto.poolId,
      dto.walletAddress,
      dto.round,
    );
  }

  @Post('rounds/close')
  @ApiOperation({
    summary: '[Legacy] Close a round in DB only (dev/test)',
  })
  closeRound(@Body() dto: CloseRoundDto) {
    return this.poolsService.closeRound(dto.poolId, dto.round);
  }

  @Post('payouts/stream')
  @ApiOperation({
    summary: '[Legacy] Schedule a payout stream in DB only (dev/test)',
  })
  scheduleStream(@Body() dto: ScheduleStreamDto) {
    return this.poolsService.scheduleStream(
      dto.poolId,
      dto.beneficiary,
      dto.total,
      dto.upfrontPercent,
      dto.totalRounds,
    );
  }

  // ─── Admin ───────────────────────────────────────────────────────────────────

  @Post('admin/configure-tiers')
  @SkipThrottle()
  @ApiOperation({
    summary:
      '[Admin] Enable tiers 1-3 on-chain via deployer signer (dev/test)',
  })
  configureTiers() {
    return this.poolsService.configureTiersOnChain();
  }
}
