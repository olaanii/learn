import { Injectable, Logger, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { ConfigService } from '@nestjs/config';
import { createHash, randomBytes } from 'crypto';
import { ethers } from 'ethers';
import { Identity } from '../entities/identity.entity';
import { FaydaService } from './fayda.service';

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);
  private readonly challengeStore = new Map<string, { nonce: string; message: string; expiresAt: number }>();

  constructor(
    private readonly jwtService: JwtService,
    private readonly configService: ConfigService,
    private readonly faydaService: FaydaService,
    @InjectRepository(Identity)
    private readonly identityRepo: Repository<Identity>,
  ) {}

  async verifyFayda(token: string) {
    this.logger.log('Verifying Fayda token...');

    const result = await this.faydaService.verify(token);

    if (!result.verified || !result.identityHash) {
      throw new UnauthorizedException('Fayda verification failed');
    }

    const { identityHash } = result;

    let identity = await this.identityRepo.findOne({ where: { identityHash } });
    if (!identity) {
      identity = this.identityRepo.create({
        identityHash,
        bindingStatus: 'unbound',
      });
      identity = await this.identityRepo.save(identity);
      this.logger.log(`New identity created: ${identityHash}`);
    }

    const payload = {
      sub: identityHash,
      walletAddress: identity.walletAddress || undefined,
    };
    const accessToken = this.jwtService.sign(payload);

    return {
      accessToken,
      identityHash,
      walletBindingStatus: identity.bindingStatus,
      faydaMode: this.faydaService.isRealIntegration ? 'real' : 'mock',
    };
  }

  /**
   * Dev-only login: generates a JWT for testing without Fayda verification.
   * If the wallet is already bound to an identity, uses that identity (avoids unique constraint).
   * In production this endpoint should be disabled or protected.
   */
  async devLogin(walletAddress?: string) {
    const devWallet = (walletAddress || '0x0000000000000000000000000000000000DE1057').toLowerCase();
    const devIdentityHash = `0x${createHash('sha256').update('dev-test-identity').digest('hex')}`;

    // Prefer existing identity that already has this wallet (case-insensitive for DE1057 etc.)
    let identity = await this.identityRepo
      .createQueryBuilder('i')
      .where('LOWER(i.walletAddress) = :wallet', { wallet: devWallet })
      .getOne();
    if (identity) {
      this.logger.log(`Dev login: using existing identity for wallet ${devWallet}`);
    } else {
      identity = await this.identityRepo.findOne({ where: { identityHash: devIdentityHash } });
      if (!identity) {
        identity = this.identityRepo.create({
          identityHash: devIdentityHash,
          walletAddress: devWallet,
          bindingStatus: 'bound',
        });
        identity = await this.identityRepo.save(identity);
        this.logger.log(`Dev identity created: ${devIdentityHash}`);
      } else if ((identity.walletAddress || '').toLowerCase() !== devWallet) {
        identity.walletAddress = devWallet;
        identity.bindingStatus = 'bound';
        identity = await this.identityRepo.save(identity);
        this.logger.log(`Dev identity wallet updated to: ${devWallet}`);
      }
    }

    const wallet = identity.walletAddress || devWallet;
    const payload = { sub: identity.identityHash, walletAddress: wallet };
    const accessToken = this.jwtService.sign(payload);

    this.logger.warn(`[DEV-LOGIN] JWT issued for ${wallet} — disable in production!`);

    return {
      accessToken,
      identityHash: identity.identityHash,
      walletAddress: wallet,
      walletBindingStatus: 'bound',
    };
  }

  // ── Wallet-based Authentication (Sign-In with Ethereum) ─────────────

  async walletChallenge(walletAddress: string) {
    const nonce = randomBytes(16).toString('hex');
    const timestamp = new Date().toISOString();
    const message =
      `Sign this message to log in to Diaspora Equb.\n\n` +
      `Wallet: ${walletAddress}\n` +
      `Nonce: ${nonce}\n` +
      `Timestamp: ${timestamp}`;

    this.challengeStore.set(walletAddress.toLowerCase(), {
      nonce,
      message,
      expiresAt: Date.now() + 5 * 60 * 1000, // 5 minutes
    });

    return { message, nonce };
  }

  async walletVerify(walletAddress: string, signature: string, message: string) {
    const key = walletAddress.toLowerCase();
    const stored = this.challengeStore.get(key);

    if (!stored) {
      throw new UnauthorizedException('No challenge found. Request a new one.');
    }
    if (stored.expiresAt < Date.now()) {
      this.challengeStore.delete(key);
      throw new UnauthorizedException('Challenge expired. Request a new one.');
    }
    if (stored.message !== message) {
      throw new UnauthorizedException('Challenge message mismatch.');
    }

    const recoveredAddress = ethers.verifyMessage(message, signature);
    if (recoveredAddress.toLowerCase() !== key) {
      throw new UnauthorizedException('Signature verification failed.');
    }

    this.challengeStore.delete(key);
    this.logger.log(`Wallet signature verified for ${walletAddress}`);

    const identityHash = `0x${createHash('sha256').update(key).digest('hex')}`;

    let identity = await this.identityRepo.findOne({ where: { walletAddress: key } });
    if (!identity) {
      identity = await this.identityRepo.findOne({ where: { identityHash } });
    }
    if (!identity) {
      identity = this.identityRepo.create({
        identityHash,
        walletAddress,
        bindingStatus: 'bound',
      });
      identity = await this.identityRepo.save(identity);
      this.logger.log(`New wallet identity created: ${walletAddress}`);
    } else if (!identity.walletAddress || identity.walletAddress.toLowerCase() !== key) {
      identity.walletAddress = walletAddress;
      identity.bindingStatus = 'bound';
      identity = await this.identityRepo.save(identity);
    }

    const payload = { sub: identityHash, walletAddress };
    const accessToken = this.jwtService.sign(payload);

    return {
      accessToken,
      identityHash,
      walletAddress,
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
