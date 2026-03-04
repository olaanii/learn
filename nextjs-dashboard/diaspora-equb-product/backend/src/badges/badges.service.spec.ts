import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { NotFoundException } from '@nestjs/common';
import { BadgesService, BADGE_TYPES } from './badges.service';
import { BadgeEntity } from '../entities/badge.entity';
import { Web3Service } from '../web3/web3.service';

describe('BadgesService', () => {
  let service: BadgesService;
  let badgeRepo: any;

  const mockAchievementBadge = {
    interface: {
      encodeFunctionData: jest.fn().mockReturnValue('0xMintData'),
    },
    getAddress: jest.fn().mockResolvedValue('0xBadgeAddr'),
  };

  const mockWeb3Service = {
    getAchievementBadge: jest.fn().mockReturnValue(mockAchievementBadge),
    buildUnsignedTx: jest.fn((to, data, value, gas) => ({
      to,
      data,
      value,
      chainId: 102031,
      estimatedGas: gas,
    })),
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        BadgesService,
        { provide: Web3Service, useValue: mockWeb3Service },
        {
          provide: getRepositoryToken(BadgeEntity),
          useValue: {
            find: jest.fn(),
            findOne: jest.fn(),
            create: jest.fn((dto) => dto),
            save: jest.fn((entity) => Promise.resolve(entity)),
          },
        },
      ],
    }).compile();

    service = module.get<BadgesService>(BadgesService);
    badgeRepo = module.get(getRepositoryToken(BadgeEntity));
  });

  afterEach(() => jest.clearAllMocks());

  describe('getBadges', () => {
    it('should return badges with type metadata', async () => {
      badgeRepo.find.mockResolvedValue([
        { walletAddress: '0xuser', badgeType: 0, metadataURI: 'ipfs://0', earnedAt: new Date() },
      ]);

      const result = await service.getBadges('0xUser');
      expect(result.length).toBe(1);
      expect(result[0].name).toBe('First Equb Joined');
      expect(result[0].badgeType).toBe(0);
    });

    it('should return empty array if no badges', async () => {
      badgeRepo.find.mockResolvedValue([]);
      const result = await service.getBadges('0xUser');
      expect(result).toEqual([]);
    });
  });

  describe('getAvailableBadges', () => {
    it('should return all badge type definitions', () => {
      const result = service.getAvailableBadges();
      expect(result.length).toBe(10);
      expect(result[0].type).toBe(0);
      expect(result[9].type).toBe(9);
    });
  });

  describe('checkEligibility', () => {
    it('should return earned types and eligibility status', async () => {
      badgeRepo.find.mockResolvedValue([
        { badgeType: 0 },
        { badgeType: 7 },
      ]);

      const result = await service.checkEligibility('0xUser');
      expect(result.earnedTypes).toContain(0);
      expect(result.earnedTypes).toContain(7);
      expect(result.badges.length).toBe(BADGE_TYPES.length);
      expect(result.badges.find((b) => b.type === 0)?.earned).toBe(true);
      expect(result.badges.find((b) => b.type === 1)?.earned).toBe(false);
    });
  });

  describe('mintBadge', () => {
    it('should mint badge and return unsigned TX', async () => {
      badgeRepo.findOne.mockResolvedValue(null);

      const result = await service.mintBadge('0xUser', 0);
      expect(result.badge.badgeType).toBe(0);
      expect(result.unsignedTx.to).toBe('0xBadgeAddr');
      expect(mockAchievementBadge.interface.encodeFunctionData).toHaveBeenCalledWith(
        'mint',
        ['0xUser', 0, 'ipfs://badge-metadata/0'],
      );
      expect(badgeRepo.save).toHaveBeenCalled();
    });

    it('should throw if badge already earned', async () => {
      badgeRepo.findOne.mockResolvedValue({ id: 'existing' });
      await expect(service.mintBadge('0xUser', 0)).rejects.toThrow(NotFoundException);
    });

    it('should throw for unknown badge type', async () => {
      badgeRepo.findOne.mockResolvedValue(null);
      await expect(service.mintBadge('0xUser', 999)).rejects.toThrow(NotFoundException);
    });
  });
});
