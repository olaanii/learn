import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { CollateralController } from './collateral.controller';
import { CollateralService } from './collateral.service';
import { Collateral } from '../entities/collateral.entity';

@Module({
  imports: [TypeOrmModule.forFeature([Collateral])],
  controllers: [CollateralController],
  providers: [CollateralService],
  exports: [CollateralService],
})
export class CollateralModule {}
