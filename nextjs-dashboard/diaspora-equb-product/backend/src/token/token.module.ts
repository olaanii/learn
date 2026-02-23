import { Module } from '@nestjs/common';
import { TokenController } from './token.controller';
import { TokenService } from './token.service';
import { IndexerModule } from '../indexer/indexer.module';
import { NotificationsModule } from '../notifications/notifications.module';

@Module({
  imports: [IndexerModule, NotificationsModule],
  controllers: [TokenController],
  providers: [TokenService],
  exports: [TokenService],
})
export class TokenModule {}
