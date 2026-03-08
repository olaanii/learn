import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { PassportModule } from '@nestjs/passport';
import { HttpModule } from '@nestjs/axios';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';
import { FaydaService } from './fayda.service';
import { FirebaseAdminService } from './firebase-admin.service';
import { JwtStrategy } from './jwt.strategy';
import { Identity } from '../entities/identity.entity';

@Module({
  imports: [
    PassportModule.register({ defaultStrategy: 'jwt' }),
    HttpModule.register({ timeout: 15000, maxRedirects: 3 }),
    JwtModule.registerAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (configService: ConfigService) => ({
        secret: configService.get<string>('JWT_SECRET'),
        signOptions: {
          expiresIn: configService.get<string>('JWT_EXPIRATION', '1d'),
        },
      }),
    }),
    TypeOrmModule.forFeature([Identity]),
  ],
  controllers: [AuthController],
  providers: [AuthService, FaydaService, FirebaseAdminService, JwtStrategy],
  exports: [AuthService, JwtModule],
})
export class AuthModule {}
