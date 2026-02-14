import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { IdentityController } from './identity.controller';
import { IdentityService } from './identity.service';
import { Identity } from '../entities/identity.entity';

@Module({
  imports: [TypeOrmModule.forFeature([Identity])],
  controllers: [IdentityController],
  providers: [IdentityService],
  exports: [IdentityService],
})
export class IdentityModule {}
