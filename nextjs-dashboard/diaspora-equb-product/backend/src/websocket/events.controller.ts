import { Controller, Get, Param, Query, ParseIntPipe, DefaultValuePipe } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiQuery, ApiParam } from '@nestjs/swagger';
import { EventsGateway, EqubEvent } from './events.gateway';

@ApiTags('Events')
@Controller('events')
export class EventsController {
  constructor(private readonly eventsGateway: EventsGateway) {}

  @Get('recent')
  @ApiOperation({ summary: 'Get recent global equb events from the in-memory buffer' })
  @ApiQuery({ name: 'limit', required: false, type: Number, description: 'Max events to return (default 20)' })
  getRecentEvents(
    @Query('limit', new DefaultValuePipe(20), ParseIntPipe) limit: number,
  ): EqubEvent[] {
    return this.eventsGateway.getRecentEvents(limit);
  }

  @Get('pool/:poolId')
  @ApiOperation({ summary: 'Get recent events for a specific pool from the in-memory buffer' })
  @ApiParam({ name: 'poolId', description: 'Pool UUID' })
  @ApiQuery({ name: 'limit', required: false, type: Number, description: 'Max events to return (default 20)' })
  getPoolEvents(
    @Param('poolId') poolId: string,
    @Query('limit', new DefaultValuePipe(20), ParseIntPipe) limit: number,
  ): EqubEvent[] {
    return this.eventsGateway.getRecentEventsForPool(poolId, limit);
  }
}
