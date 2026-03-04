import { Controller, Get, Header, Param, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiParam, ApiQuery, ApiTags } from '@nestjs/swagger';
import { SkipThrottle } from '@nestjs/throttler';
import { AnalyticsService } from './analytics.service';
import {
  GlobalStatsQueryDto,
  JoinedProgressQueryDto,
  LeaderboardQueryDto,
  PopularSeriesQueryDto,
  ReputationParamDto,
  SummaryQueryDto,
} from './dto/equb-insights-query.dto';

@ApiTags('Analytics')
@ApiBearerAuth()
@Controller('analytics/equbs')
export class AnalyticsController {
  constructor(private readonly analyticsService: AnalyticsService) {}

  @Get('popular-series')
  @Header('Cache-Control', 'public, max-age=60, s-maxage=60')
  @ApiOperation({ summary: 'Get Equb popular trends series' })
  @ApiQuery({ name: 'from', required: false })
  @ApiQuery({ name: 'to', required: false })
  @ApiQuery({ name: 'token', required: false })
  @ApiQuery({ name: 'status', required: false })
  @ApiQuery({ name: 'metric', required: false })
  @ApiQuery({ name: 'limit', required: false })
  @ApiQuery({ name: 'offset', required: false })
  @ApiQuery({ name: 'bucket', required: false, enum: ['hour', 'day'] })
  getPopularSeries(@Query() query: PopularSeriesQueryDto) {
    return this.analyticsService.getPopularSeries(query);
  }

  @Get('joined-progress')
  @Header('Cache-Control', 'public, max-age=60, s-maxage=60')
  @ApiOperation({ summary: 'Get joined Equb progress for a wallet' })
  @ApiQuery({ name: 'wallet', required: true })
  @ApiQuery({ name: 'from', required: false })
  @ApiQuery({ name: 'to', required: false })
  @ApiQuery({ name: 'token', required: false })
  @ApiQuery({ name: 'status', required: false })
  @ApiQuery({ name: 'bucket', required: false, enum: ['hour', 'day'] })
  getJoinedProgress(@Query() query: JoinedProgressQueryDto) {
    return this.analyticsService.getJoinedProgress(query);
  }

  @Get('summary')
  @Header('Cache-Control', 'public, max-age=60, s-maxage=60')
  @ApiOperation({ summary: 'Get Equb insights summary for a wallet' })
  @ApiQuery({ name: 'wallet', required: true })
  @ApiQuery({ name: 'from', required: false })
  @ApiQuery({ name: 'to', required: false })
  @ApiQuery({ name: 'token', required: false })
  @ApiQuery({ name: 'status', required: false })
  getSummary(@Query() query: SummaryQueryDto) {
    return this.analyticsService.getSummary(query);
  }

  @Get('global-stats')
  @SkipThrottle()
  @Header('Cache-Control', 'public, max-age=60, s-maxage=60')
  @ApiOperation({ summary: 'Get global equb statistics' })
  @ApiQuery({ name: 'type', required: false, description: 'Filter by equbType (smallint)' })
  getGlobalStats(@Query() query: GlobalStatsQueryDto) {
    return this.analyticsService.getGlobalStats(query);
  }

  @Get('leaderboard')
  @SkipThrottle()
  @Header('Cache-Control', 'public, max-age=60, s-maxage=60')
  @ApiOperation({ summary: 'Get equb leaderboard ranked by various metrics' })
  @ApiQuery({ name: 'type', required: false, description: 'Filter by equbType' })
  @ApiQuery({ name: 'sort', required: false, enum: ['members', 'contributions', 'completion', 'newest'] })
  @ApiQuery({ name: 'page', required: false })
  @ApiQuery({ name: 'limit', required: false })
  getLeaderboard(@Query() query: LeaderboardQueryDto) {
    return this.analyticsService.getLeaderboard(query);
  }

  @Get('trending')
  @SkipThrottle()
  @Header('Cache-Control', 'public, max-age=60, s-maxage=60')
  @ApiOperation({ summary: 'Get trending equbs: fastest growing, completing soon, newest' })
  getTrending() {
    return this.analyticsService.getTrending();
  }
}

@ApiTags('Analytics')
@ApiBearerAuth()
@Controller('analytics/danna')
export class DannaAnalyticsController {
  constructor(private readonly analyticsService: AnalyticsService) {}

  @Get(':address/reputation')
  @SkipThrottle()
  @Header('Cache-Control', 'public, max-age=60, s-maxage=60')
  @ApiOperation({ summary: 'Get creator reputation for a wallet address' })
  @ApiParam({ name: 'address', description: 'Wallet address (0x...)' })
  getReputation(@Param() params: ReputationParamDto) {
    return this.analyticsService.getCreatorReputation(params.address);
  }
}
