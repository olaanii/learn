import { Module } from '@nestjs/common';
import { AuthModule } from './auth/auth.module';
import { CollateralModule } from './collateral/collateral.module';
import { CreditModule } from './credit/credit.module';
import { IdentityModule } from './identity/identity.module';
import { PoolsModule } from './pools/pools.module';
import { TiersModule } from './tiers/tiers.module';

@Module({
  imports: [AuthModule, CollateralModule, CreditModule, IdentityModule, PoolsModule, TiersModule],
})
export class AppModule {}
