import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { BadgeEntity } from '../entities/badge.entity';
import { Web3Service } from '../web3/web3.service';

export const BADGE_TYPES = [
  { type: 0, name: 'First Equb Joined', description: 'Joined your first equb', requirement: 'Join 1 equb' },
  { type: 1, name: 'First Equb Completed', description: 'Completed a full equb cycle', requirement: 'Complete 1 equb' },
  { type: 2, name: 'Tier 2 Unlocked', description: 'Reached Tier 2 credit score', requirement: 'Credit score >= 100' },
  { type: 3, name: 'Tier 3 Unlocked', description: 'Reached Tier 3 credit score', requirement: 'Credit score >= 500' },
  { type: 4, name: 'Zero Defaults x10', description: '10 rounds without default', requirement: '10 consecutive contributions' },
  { type: 5, name: 'Trusted Danna', description: 'Created and completed 5 equbs', requirement: 'Create 5 completed equbs' },
  { type: 6, name: 'Perfect Consistency', description: 'Never missed a contribution', requirement: '100% contribution rate' },
  { type: 7, name: 'Diaspora Pioneer', description: 'Early adopter badge', requirement: 'Among first 100 users' },
  { type: 8, name: '100 Contributions', description: 'Made 100 contributions', requirement: 'Contribute 100 times' },
  { type: 9, name: 'Top Referrer', description: 'Referred 10+ users', requirement: 'Refer 10 users' },
];

@Injectable()
export class BadgesService {
  private readonly logger = new Logger(BadgesService.name);

  constructor(
    @InjectRepository(BadgeEntity)
    private readonly badgeRepo: Repository<BadgeEntity>,
    private readonly web3Service: Web3Service,
  ) {}

  async getBadges(walletAddress: string) {
    const badges = await this.badgeRepo.find({
      where: { walletAddress: walletAddress.toLowerCase() },
      order: { earnedAt: 'DESC' },
    });

    return badges.map((b) => ({
      ...b,
      ...BADGE_TYPES.find((t) => t.type === b.badgeType),
    }));
  }

  getAvailableBadges() {
    return BADGE_TYPES;
  }

  async checkEligibility(walletAddress: string) {
    const earned = await this.badgeRepo.find({
      where: { walletAddress: walletAddress.toLowerCase() },
    });
    const earnedTypes = new Set(earned.map((b) => b.badgeType));

    const eligible: number[] = [];
    for (const bt of BADGE_TYPES) {
      if (earnedTypes.has(bt.type)) continue;

      // Placeholder: real eligibility checks would query on-chain data /
      // contribution history / credit scores etc.
      // For now we mark none as eligible; the indexer or admin will award them.
      // Extend this switch with actual logic per badge type.
    }

    return {
      walletAddress,
      earnedTypes: Array.from(earnedTypes),
      eligibleTypes: eligible,
      badges: BADGE_TYPES.map((bt) => ({
        ...bt,
        earned: earnedTypes.has(bt.type),
        eligible: eligible.includes(bt.type),
      })),
    };
  }

  async mintBadge(walletAddress: string, badgeType: number) {
    const existing = await this.badgeRepo.findOne({
      where: {
        walletAddress: walletAddress.toLowerCase(),
        badgeType,
      },
    });
    if (existing) {
      throw new NotFoundException('Badge already earned');
    }

    const typeDef = BADGE_TYPES.find((t) => t.type === badgeType);
    if (!typeDef) {
      throw new NotFoundException('Unknown badge type');
    }

    const metadataURI = `ipfs://badge-metadata/${badgeType}`;

    const achievementBadge = this.web3Service.getAchievementBadge();
    const iface = achievementBadge.interface;
    const data = iface.encodeFunctionData('mint', [
      walletAddress,
      badgeType,
      metadataURI,
    ]);

    const unsignedTx = this.web3Service.buildUnsignedTx(
      await achievementBadge.getAddress(),
      data,
      '0',
      '200000',
    );

    const badge = this.badgeRepo.create({
      walletAddress: walletAddress.toLowerCase(),
      badgeType,
      metadataURI,
    });
    await this.badgeRepo.save(badge);

    this.logger.log(
      `Badge type ${badgeType} (${typeDef.name}) recorded for ${walletAddress}`,
    );

    return { badge, unsignedTx };
  }
}
