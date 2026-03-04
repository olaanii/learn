import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { TotpSecret } from '../entities/totp-secret.entity';
import { Device } from '../entities/device.entity';
import { WithdrawalWhitelist } from '../entities/withdrawal-whitelist.entity';
import { SecurityController } from './security.controller';
import { SecurityService } from './security.service';

@Module({
  imports: [TypeOrmModule.forFeature([TotpSecret, Device, WithdrawalWhitelist])],
  controllers: [SecurityController],
  providers: [SecurityService],
  exports: [SecurityService],
})
export class SecurityModule {}
