import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { CreditController } from './credit.controller';
import { CreditService } from './credit.service';
import { CreditScore } from '../entities/credit-score.entity';

@Module({
  imports: [TypeOrmModule.forFeature([CreditScore])],
  controllers: [CreditController],
  providers: [CreditService],
  exports: [CreditService],
})
export class CreditModule {}
