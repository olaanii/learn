import { Body, Controller, Post, Get, Param, Query } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth, ApiQuery } from '@nestjs/swagger';
import { PoolsService } from './pools.service';
import {
  CreatePoolDto,
  JoinPoolDto,
  RecordContributionDto,
  CloseRoundDto,
  ScheduleStreamDto,
} from './dto/pool.dto';

@ApiTags('Pools')
@ApiBearerAuth()
@Controller('pools')
export class PoolsController {
  constructor(private readonly poolsService: PoolsService) {}

  @Post('create')
  @ApiOperation({ summary: 'Create a new Equb pool' })
  createPool(@Body() dto: CreatePoolDto) {
    return this.poolsService.createPool(
      dto.tier,
      dto.contributionAmount,
      dto.maxMembers,
      dto.treasury,
    );
  }

  @Post('join')
  @ApiOperation({ summary: 'Join an existing pool' })
  joinPool(@Body() dto: JoinPoolDto) {
    return this.poolsService.joinPool(dto.poolId, dto.walletAddress);
  }

  @Post('contributions')
  @ApiOperation({ summary: 'Record a contribution for a round' })
  recordContribution(@Body() dto: RecordContributionDto) {
    return this.poolsService.recordContribution(
      dto.poolId,
      dto.walletAddress,
      dto.round,
    );
  }

  @Post('rounds/close')
  @ApiOperation({ summary: 'Close a round and detect defaults' })
  closeRound(@Body() dto: CloseRoundDto) {
    return this.poolsService.closeRound(dto.poolId, dto.round);
  }

  @Post('payouts/stream')
  @ApiOperation({ summary: 'Schedule a streamed payout for a beneficiary' })
  scheduleStream(@Body() dto: ScheduleStreamDto) {
    return this.poolsService.scheduleStream(
      dto.poolId,
      dto.beneficiary,
      dto.total,
      dto.upfrontPercent,
      dto.totalRounds,
    );
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get pool details by ID' })
  getPool(@Param('id') id: string) {
    return this.poolsService.getPool(id);
  }

  @Get()
  @ApiOperation({ summary: 'List all pools, optionally filtered by tier' })
  @ApiQuery({ name: 'tier', required: false, description: 'Filter by tier (0-3)' })
  listPools(@Query('tier') tier?: number) {
    return this.poolsService.listPools(tier);
  }
}
