import { Injectable, Logger, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { ConfigService } from '@nestjs/config';
import { createHash, randomBytes } from 'crypto';
import { ethers } from 'ethers';
import { Identity } from '../entities/identity.entity';
import { WalletChallenge } from '../entities/wallet-challenge.entity';
import { FaydaService } from './fayda.service';
import { FirebaseAdminService } from './firebase-admin.service';

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);

  constructor(
    private readonly jwtService: JwtService,
    private readonly configService: ConfigService,
    private readonly faydaService: FaydaService,
    private readonly firebaseAdminService: FirebaseAdminService,
    @InjectRepository(Identity)
    private readonly identityRepo: Repository<Identity>,
    @InjectRepository(WalletChallenge)
    private readonly walletChallengeRepo: Repository<WalletChallenge>,
  ) {}

  getFirebaseStatus() {
    return {
      configured: this.firebaseAdminService.isConfigured,
    };
  }

  async exchangeFirebaseSession(idToken: string) {
    const decoded = await this.firebaseAdminService.verifyIdToken(idToken);

    if (!decoded.uid) {
      throw new UnauthorizedException('Invalid Firebase token');
    }

    if (decoded.email && decoded.email_verified !== true) {
      throw new UnauthorizedException('Email verification is required');
    }

    const identityHash = `0x${createHash('sha256')
      .update(`firebase:${decoded.uid}`)
      .digest('hex')}`;

    let identity = await this.identityRepo.findOne({ where: { identityHash } });
    if (!identity) {
      identity = this.identityRepo.create({
        identityHash,
        bindingStatus: 'unbound',
      });
      identity = await this.identityRepo.save(identity);
      this.logger.log(`New Firebase identity created: ${identityHash}`);
    }

    const payload = {
      sub: identityHash,
      walletAddress: identity.walletAddress || undefined,
      firebaseUid: decoded.uid,
      email: decoded.email || undefined,
      displayName: decoded.name || undefined,
    };
    const accessToken = this.jwtService.sign(payload);

    return {
      accessToken,
      identityHash,
      walletAddress: identity.walletAddress ?? null,
      walletBindingStatus: identity.bindingStatus,
      firebaseUid: decoded.uid,
      email: decoded.email ?? null,
      displayName: decoded.name ?? null,
      photoUrl: decoded.picture ?? null,
      emailVerified: decoded.email_verified === true,
    };
  }

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

  private async issueChallenge(
    challengeKey: string,
    purpose: 'login' | 'bind',
    walletAddress: string,
    message: string,
    nonce: string,
    identityHash?: string,
  ) {
    const expiresAt = new Date(Date.now() + 5 * 60 * 1000);
    await this.walletChallengeRepo.delete({ challengeKey });

    const challenge = this.walletChallengeRepo.create({
      challengeKey,
      purpose,
      walletAddress,
      identityHash: identityHash ?? null,
      nonce,
      message,
      expiresAt,
      consumedAt: null,
    });

    await this.walletChallengeRepo.save(challenge);
    return { message, nonce };
  }

  private async loadAndConsumeChallenge(
    challengeKey: string,
    message: string,
    expiredErrorMessage: string,
    noChallengeMessage: string,
    mismatchMessage: string,
  ) {
    const stored = await this.walletChallengeRepo.findOne({
      where: { challengeKey },
    });

    if (!stored || stored.consumedAt) {
      throw new UnauthorizedException(noChallengeMessage);
    }
    if (stored.expiresAt.getTime() < Date.now()) {
      throw new UnauthorizedException(expiredErrorMessage);
    }
    if (stored.message !== message) {
      throw new UnauthorizedException(mismatchMessage);
    }

    const consumeResult = await this.walletChallengeRepo
      .createQueryBuilder()
      .update(WalletChallenge)
      .set({ consumedAt: new Date() })
      .where('id = :id', { id: stored.id })
      .andWhere('"consumedAt" IS NULL')
      .execute();

    if (!consumeResult.affected) {
      throw new UnauthorizedException(noChallengeMessage);
    }
  }

  async walletChallenge(walletAddress: string) {
    const normalizedWalletAddress = walletAddress.toLowerCase();
    const nonce = randomBytes(16).toString('hex');
    const timestamp = new Date().toISOString();
    const message =
      `Sign this message to log in to Diaspora Equb.\n\n` +
      `Wallet: ${normalizedWalletAddress}\n` +
      `Nonce: ${nonce}\n` +
      `Timestamp: ${timestamp}`;

    return this.issueChallenge(
      `login:${normalizedWalletAddress}`,
      'login',
      normalizedWalletAddress,
      message,
      nonce,
    );
  }

  async walletVerify(walletAddress: string, signature: string, message: string) {
    const key = walletAddress.toLowerCase();
    await this.loadAndConsumeChallenge(
      `login:${key}`,
      message,
      'Challenge expired. Request a new one.',
      'No challenge found. Request a new one.',
      'Challenge message mismatch.',
    );

    const recoveredAddress = ethers.verifyMessage(message, signature);
    if (recoveredAddress.toLowerCase() !== key) {
      throw new UnauthorizedException('Signature verification failed.');
    }
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

  async walletBindChallenge(identityHash: string, walletAddress: string) {
    const normalizedIdentityHash = identityHash.toLowerCase();
    const normalizedWalletAddress = walletAddress.toLowerCase();
    const nonce = randomBytes(16).toString('hex');
    const timestamp = new Date().toISOString();
    const message =
      `Sign this message to bind your wallet to your verified identity in Diaspora Equb.\n\n` +
      `Identity: ${normalizedIdentityHash}\n` +
      `Wallet: ${normalizedWalletAddress}\n` +
      `Nonce: ${nonce}\n` +
      `Timestamp: ${timestamp}`;

    return this.issueChallenge(
      `${normalizedIdentityHash}:${normalizedWalletAddress}`,
      'bind',
      normalizedWalletAddress,
      message,
      nonce,
      normalizedIdentityHash,
    );
  }

  async walletBindVerify(
    identityHash: string,
    walletAddress: string,
    signature: string,
    message: string,
  ) {
    const normalizedIdentityHash = identityHash.toLowerCase();
    const normalizedWalletAddress = walletAddress.toLowerCase();
    const key = `${normalizedIdentityHash}:${normalizedWalletAddress}`;
    await this.loadAndConsumeChallenge(
      key,
      message,
      'Bind challenge expired. Request a new one.',
      'No bind challenge found. Request a new one.',
      'Bind challenge message mismatch.',
    );

    const recoveredAddress = ethers.verifyMessage(message, signature);
    if (recoveredAddress.toLowerCase() !== normalizedWalletAddress) {
      throw new UnauthorizedException('Wallet bind signature verification failed.');
    }
    return { walletAddress: normalizedWalletAddress };
  }

  async validateToken(token: string) {
    try {
      return this.jwtService.verify(token);
    } catch {
      throw new UnauthorizedException('Invalid or expired token');
    }
  }
}
