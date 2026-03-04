import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { IndexerService } from './indexer.service';
import { Pool } from '../entities/pool.entity';
import { PoolMember } from '../entities/pool-member.entity';
import { Contribution } from '../entities/contribution.entity';
import { PayoutStreamEntity } from '../entities/payout-stream.entity';
import { CreditScore } from '../entities/credit-score.entity';
import { Collateral } from '../entities/collateral.entity';
import { Identity } from '../entities/identity.entity';
import { IndexedBlock } from '../entities/indexed-block.entity';
import { TokenTransfer } from '../entities/token-transfer.entity';
import { EqubRulesEntity } from '../entities/equb-rules.entity';
import { Proposal } from '../entities/proposal.entity';
import { NotificationsModule } from '../notifications/notifications.module';
import { RulesModule } from '../rules/rules.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      Pool,
      PoolMember,
      Contribution,
      PayoutStreamEntity,
      CreditScore,
      Collateral,
      Identity,
      IndexedBlock,
      TokenTransfer,
      EqubRulesEntity,
      Proposal,
    ]),
    NotificationsModule,
    RulesModule,
  ],
  providers: [IndexerService],
  exports: [IndexerService],
})
export class IndexerModule {}
