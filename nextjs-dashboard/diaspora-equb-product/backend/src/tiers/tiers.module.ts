import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { TiersController } from './tiers.controller';
import { TiersService } from './tiers.service';
import { TierConfig } from '../entities/tier-config.entity';
import { CreditScore } from '../entities/credit-score.entity';

@Module({
  imports: [TypeOrmModule.forFeature([TierConfig, CreditScore])],
  controllers: [TiersController],
  providers: [TiersService],
  exports: [TiersService],
})
export class TiersModule {}
