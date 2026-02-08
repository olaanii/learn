import { Module } from '@nestjs/common';
import { CollateralController } from './collateral.controller';
import { CollateralService } from './collateral.service';

@Module({
  controllers: [CollateralController],
  providers: [CollateralService],
})
export class CollateralModule {}
