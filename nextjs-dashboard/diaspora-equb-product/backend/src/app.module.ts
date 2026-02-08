import { Module } from '@nestjs/common';
import { AuthModule } from './auth/auth.module';
import { CollateralModule } from './collateral/collateral.module';
import { IdentityModule } from './identity/identity.module';
import { PoolsModule } from './pools/pools.module';
import { TiersModule } from './tiers/tiers.module';

@Module({
  imports: [AuthModule, CollateralModule, IdentityModule, PoolsModule, TiersModule],
})
export class AppModule {}
