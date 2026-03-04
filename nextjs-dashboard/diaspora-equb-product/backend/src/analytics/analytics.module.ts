import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Contribution } from '../entities/contribution.entity';
import { PoolMember } from '../entities/pool-member.entity';
import { Pool } from '../entities/pool.entity';
import { PayoutStreamEntity } from '../entities/payout-stream.entity';
import { Round } from '../entities/round.entity';
import { Season } from '../entities/season.entity';
import { AnalyticsController, DannaAnalyticsController } from './analytics.controller';
import { AnalyticsService } from './analytics.service';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      Pool,
      PoolMember,
      Contribution,
      Season,
      Round,
      PayoutStreamEntity,
    ]),
  ],
  controllers: [AnalyticsController, DannaAnalyticsController],
  providers: [AnalyticsService],
})
export class AnalyticsModule {}
