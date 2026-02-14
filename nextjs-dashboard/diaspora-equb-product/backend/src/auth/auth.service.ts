import { Injectable, Logger, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { ConfigService } from '@nestjs/config';
import { createHash } from 'crypto';
import { Identity } from '../entities/identity.entity';

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);

  constructor(
    private readonly jwtService: JwtService,
    private readonly configService: ConfigService,
    @InjectRepository(Identity)
    private readonly identityRepo: Repository<Identity>,
  ) {}

  async verifyFayda(token: string) {
    this.logger.log('Verifying Fayda token...');

    // In production, this would call the Fayda API:
    // const faydaUrl = this.configService.get('FAYDA_API_URL');
    // const response = await httpClient.post(`${faydaUrl}/verify`, { token });
    // For MVP, we generate identity hash from the token
    const identityHash = `0x${createHash('sha256').update(token).digest('hex')}`;

    // Upsert identity record
    let identity = await this.identityRepo.findOne({ where: { identityHash } });
    if (!identity) {
      identity = this.identityRepo.create({
        identityHash,
        bindingStatus: 'unbound',
      });
      identity = await this.identityRepo.save(identity);
      this.logger.log(`New identity created: ${identityHash}`);
    }

    // Generate JWT
    const payload = {
      sub: identityHash,
      walletAddress: identity.walletAddress || undefined,
    };
    const accessToken = this.jwtService.sign(payload);

    return {
      accessToken,
      identityHash,
      walletBindingStatus: identity.bindingStatus,
    };
  }

  /**
   * Dev-only login: generates a JWT for testing without Fayda verification.
   * In production this endpoint should be disabled or protected.
   */
  async devLogin(walletAddress?: string) {
    const devWallet = walletAddress || '0x0000000000000000000000000000000000DE1057';
    const identityHash = `0x${createHash('sha256').update('dev-test-identity').digest('hex')}`;

    // Upsert identity record — always update wallet to current devWallet
    let identity = await this.identityRepo.findOne({ where: { identityHash } });
    if (!identity) {
      identity = this.identityRepo.create({
        identityHash,
        walletAddress: devWallet,
        bindingStatus: 'bound',
      });
      identity = await this.identityRepo.save(identity);
      this.logger.log(`Dev identity created: ${identityHash}`);
    } else if (identity.walletAddress !== devWallet) {
      identity.walletAddress = devWallet;
      identity.bindingStatus = 'bound';
      identity = await this.identityRepo.save(identity);
      this.logger.log(`Dev identity wallet updated to: ${devWallet}`);
    }

    // Generate JWT
    const payload = {
      sub: identityHash,
      walletAddress: identity.walletAddress || devWallet,
    };
    const accessToken = this.jwtService.sign(payload);

    this.logger.warn(`[DEV-LOGIN] JWT issued for ${devWallet} — disable in production!`);

    return {
      accessToken,
      identityHash,
      walletAddress: identity.walletAddress || devWallet,
      walletBindingStatus: 'bound',
    };
  }

  async validateToken(token: string) {
    try {
      return this.jwtService.verify(token);
    } catch {
      throw new UnauthorizedException('Invalid or expired token');
    }
  }
}
