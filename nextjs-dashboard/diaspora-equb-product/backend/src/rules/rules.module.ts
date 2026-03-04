import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Pool } from '../entities/pool.entity';
import { EqubRulesEntity } from '../entities/equb-rules.entity';
import { RulesController } from './rules.controller';
import { RulesService } from './rules.service';
import { Web3Module } from '../web3/web3.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([Pool, EqubRulesEntity]),
    Web3Module,
  ],
  controllers: [RulesController],
  providers: [RulesService],
  exports: [RulesService],
})
export class RulesModule {}
