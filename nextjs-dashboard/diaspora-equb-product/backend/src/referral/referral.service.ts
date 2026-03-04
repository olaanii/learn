import {
  Injectable,
  BadRequestException,
  NotFoundException,
  ConflictException,
  Logger,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { randomBytes } from 'crypto';
import { ReferralCode } from '../entities/referral-code.entity';
import { Referral } from '../entities/referral.entity';
import { Commission } from '../entities/commission.entity';

@Injectable()
export class ReferralService {
  private readonly logger = new Logger(ReferralService.name);

  constructor(
    @InjectRepository(ReferralCode)
    private readonly codeRepo: Repository<ReferralCode>,
    @InjectRepository(Referral)
    private readonly referralRepo: Repository<Referral>,
    @InjectRepository(Commission)
    private readonly commissionRepo: Repository<Commission>,
  ) {}

  async getOrCreateCode(walletAddress: string): Promise<{ code: string }> {
    const existing = await this.codeRepo.findOne({ where: { walletAddress } });
    if (existing) {
      return { code: existing.code };
    }

    const code = this.generateCode();
    const entry = this.codeRepo.create({ walletAddress, code });
    await this.codeRepo.save(entry);
    this.logger.log(`Generated referral code ${code} for ${walletAddress}`);
    return { code };
  }

  async getReferralStats(walletAddress: string) {
    const referrals = await this.referralRepo.find({
      where: { referrerWallet: walletAddress },
    });

    const totalReferred = referrals.length;
    const activeReferred = referrals.filter((r) => r.active).length;
    const totalCommission = referrals.reduce(
      (sum, r) => sum + parseFloat(r.totalCommission || '0'),
      0,
    );

    const code = await this.codeRepo.findOne({ where: { walletAddress } });

    return {
      code: code?.code ?? null,
      totalReferred,
      activeReferred,
      totalCommission: totalCommission.toString(),
    };
  }

  async getCommissionHistory(
    walletAddress: string,
    page: number,
    limit: number,
  ) {
    const referrals = await this.referralRepo.find({
      where: { referrerWallet: walletAddress },
      select: ['id'],
    });

    if (referrals.length === 0) {
      return { data: [], total: 0, page, limit };
    }

    const referralIds = referrals.map((r) => r.id);

    const qb = this.commissionRepo
      .createQueryBuilder('c')
      .where('c.referralId IN (:...referralIds)', { referralIds })
      .orderBy('c.createdAt', 'DESC')
      .skip((page - 1) * limit)
      .take(limit);

    const [data, total] = await qb.getManyAndCount();

    return { data, total, page, limit };
  }

  async applyReferral(
    referralCode: string,
    newUserWallet: string,
  ): Promise<Referral> {
    const codeEntry = await this.codeRepo.findOne({
      where: { code: referralCode },
    });
    if (!codeEntry) {
      throw new NotFoundException('Invalid referral code');
    }

    if (
      codeEntry.walletAddress.toLowerCase() === newUserWallet.toLowerCase()
    ) {
      throw new BadRequestException('Cannot refer yourself');
    }

    const existingReferral = await this.referralRepo.findOne({
      where: { referredWallet: newUserWallet },
    });
    if (existingReferral) {
      throw new ConflictException('Wallet already has a referrer');
    }

    const referral = this.referralRepo.create({
      referrerWallet: codeEntry.walletAddress,
      referredWallet: newUserWallet,
    });

    const saved = await this.referralRepo.save(referral);
    this.logger.log(
      `Referral applied: ${codeEntry.walletAddress} referred ${newUserWallet}`,
    );
    return saved;
  }

  async recordCommission(
    referrerWallet: string,
    poolId: string | null,
    round: number | null,
    amount: string,
    txHash: string | null,
  ): Promise<Commission> {
    const referral = await this.referralRepo.findOne({
      where: { referrerWallet },
    });
    if (!referral) {
      throw new NotFoundException(
        'No referral record found for this referrer',
      );
    }

    const commission = this.commissionRepo.create({
      referralId: referral.id,
      poolId,
      round,
      amount,
      txHash,
    });
    const saved = await this.commissionRepo.save(commission);

    referral.totalCommission = (
      parseFloat(referral.totalCommission || '0') + parseFloat(amount)
    ).toString();
    await this.referralRepo.save(referral);

    return saved;
  }

  private generateCode(): string {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789';
    const bytes = randomBytes(8);
    let code = '';
    for (let i = 0; i < 8; i++) {
      code += chars[bytes[i] % chars.length];
    }
    return code;
  }
}
