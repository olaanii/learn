import { MiddlewareConsumer, Module, NestModule } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ThrottlerModule, ThrottlerGuard } from '@nestjs/throttler';
import { APP_GUARD } from '@nestjs/core';

import { envValidationSchema } from './config/env.validation';
import { getDatabaseConfig } from './config/database.config';
import { JwtAuthGuard } from './common/guards/jwt-auth.guard';
import { AppController } from './app.controller';
import { LoggingMiddleware } from './common/middleware/logging.middleware';

import { AuthModule } from './auth/auth.module';
import { CollateralModule } from './collateral/collateral.module';
import { CreditModule } from './credit/credit.module';
import { IdentityModule } from './identity/identity.module';
import { PoolsModule } from './pools/pools.module';
import { TiersModule } from './tiers/tiers.module';
import { Web3Module } from './web3/web3.module';
import { TokenModule } from './token/token.module';
import { HealthModule } from './health/health.module';
import { IndexerModule } from './indexer/indexer.module';
import { NotificationsModule } from './notifications/notifications.module';
import { AnalyticsModule } from './analytics/analytics.module';
import { RulesModule } from './rules/rules.module';
import { SecurityModule } from './security/security.module';
import { SwapModule } from './swap/swap.module';
import { ReferralModule } from './referral/referral.module';
import { GovernanceModule } from './governance/governance.module';
import { BadgesModule } from './badges/badges.module';
import { CacheModule } from './cache/cache.module';
import { JobsModule } from './jobs/jobs.module';
import { WebsocketModule } from './websocket/websocket.module';

@Module({
  imports: [
    // Environment configuration
    ConfigModule.forRoot({
      isGlobal: true,
      validationSchema: envValidationSchema,
      envFilePath: ['.env', '../.env'],
    }),

    // Database
    TypeOrmModule.forRootAsync({
      inject: [ConfigService],
      useFactory: getDatabaseConfig,
    }),

    // Rate limiting: 60 requests per minute per IP
    ThrottlerModule.forRoot([
      {
        ttl: 60000,
        limit: 60,
      },
    ]),

    // Global infrastructure
    CacheModule,
    JobsModule,
    WebsocketModule,

    // Feature modules
    AuthModule,
    CollateralModule,
    CreditModule,
    IdentityModule,
    PoolsModule,
    TiersModule,
    Web3Module,
    TokenModule,
    HealthModule,
    IndexerModule,
    NotificationsModule,
    AnalyticsModule,
    RulesModule,
    SecurityModule,
    GovernanceModule,
    ReferralModule,
    SwapModule,
    BadgesModule,
  ],
  controllers: [AppController],
  providers: [
    // Global JWT authentication guard
    {
      provide: APP_GUARD,
      useClass: JwtAuthGuard,
    },
    // Global rate limit guard
    {
      provide: APP_GUARD,
      useClass: ThrottlerGuard,
    },
  ],
})
export class AppModule implements NestModule {
  configure(consumer: MiddlewareConsumer) {
    consumer.apply(LoggingMiddleware).forRoutes('*');
  }
}
