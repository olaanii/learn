import { Controller, Get, Header, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiQuery, ApiTags } from '@nestjs/swagger';
import { AnalyticsService } from './analytics.service';
import {
  JoinedProgressQueryDto,
  PopularSeriesQueryDto,
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
}
