import { Module } from '@nestjs/common';
import { TiersController } from './tiers.controller';
import { TiersService } from './tiers.service';

@Module({
  controllers: [TiersController],
  providers: [TiersService],
})
export class TiersModule {}
