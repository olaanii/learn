import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { PoolsController } from './pools.controller';
import { PoolsService } from './pools.service';
import { Pool } from '../entities/pool.entity';
import { PoolMember } from '../entities/pool-member.entity';
import { Contribution } from '../entities/contribution.entity';
import { PayoutStreamEntity } from '../entities/payout-stream.entity';
import { Season } from '../entities/season.entity';
import { Round } from '../entities/round.entity';
import { IdempotencyKey } from '../entities/idempotency-key.entity';
import { NotificationsModule } from '../notifications/notifications.module';
import { RulesModule } from '../rules/rules.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      Pool,
      PoolMember,
      Contribution,
      PayoutStreamEntity,
      Season,
      Round,
      IdempotencyKey,
    ]),
    NotificationsModule,
    RulesModule,
  ],
  controllers: [PoolsController],
  providers: [PoolsService],
  exports: [PoolsService],
})
export class PoolsModule {}
