import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { PoolsController } from './pools.controller';
import { PoolsService } from './pools.service';
import { Pool } from '../entities/pool.entity';
import { PoolMember } from '../entities/pool-member.entity';
import { Contribution } from '../entities/contribution.entity';
import { PayoutStreamEntity } from '../entities/payout-stream.entity';

@Module({
  imports: [
    TypeOrmModule.forFeature([Pool, PoolMember, Contribution, PayoutStreamEntity]),
  ],
  controllers: [PoolsController],
  providers: [PoolsService],
  exports: [PoolsService],
})
export class PoolsModule {}
