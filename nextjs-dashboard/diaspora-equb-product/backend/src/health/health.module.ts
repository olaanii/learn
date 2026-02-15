import { Module } from '@nestjs/common';
import { TerminusModule } from '@nestjs/terminus';
import { HealthController } from './health.controller';
import { IndexerModule } from '../indexer/indexer.module';

@Module({
  imports: [TerminusModule, IndexerModule],
  controllers: [HealthController],
})
export class HealthModule {}
