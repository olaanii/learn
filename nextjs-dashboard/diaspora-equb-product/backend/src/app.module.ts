import { MiddlewareConsumer, Module, NestModule } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ThrottlerModule, ThrottlerGuard } from '@nestjs/throttler';
import { APP_GUARD } from '@nestjs/core';

import { envValidationSchema } from './config/env.validation';
import { getDatabaseConfig } from './config/database.config';
import { JwtAuthGuard } from './common/guards/jwt-auth.guard';
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
  ],
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
