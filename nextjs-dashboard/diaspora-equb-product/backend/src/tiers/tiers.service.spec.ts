import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { TiersService } from './tiers.service';
import { TierConfig } from '../entities/tier-config.entity';
import { CreditScore } from '../entities/credit-score.entity';
import { Web3Service } from '../web3/web3.service';

describe('TiersService', () => {
  let service: TiersService;
  let tierConfigRepo: any;
  let creditScoreRepo: any;

  const mockCreditRegistry = {
    scoreOf: jest.fn(),
  };

  const mockTierRegistry = {
    tierConfig: jest.fn(),
  };

  const mockWeb3Service = {
    getCreditRegistry: jest.fn().mockReturnValue(mockCreditRegistry),
    getTierRegistry: jest.fn().mockReturnValue(mockTierRegistry),
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        TiersService,
        { provide: Web3Service, useValue: mockWeb3Service },
        {
          provide: getRepositoryToken(TierConfig),
          useValue: {
            findOne: jest.fn(),
            find: jest.fn(),
          },
        },
        {
          provide: getRepositoryToken(CreditScore),
          useValue: {
            findOne: jest.fn(),
          },
        },
      ],
    }).compile();

    service = module.get<TiersService>(TiersService);
    tierConfigRepo = module.get(getRepositoryToken(TierConfig));
    creditScoreRepo = module.get(getRepositoryToken(CreditScore));
  });

  afterEach(() => jest.clearAllMocks());

  describe('getEligibility', () => {
    it('should return tier 0 for score 0', async () => {
      mockCreditRegistry.scoreOf.mockResolvedValue(BigInt(0));
      mockTierRegistry.tierConfig.mockResolvedValue({
        maxPoolSize: BigInt(1000),
        collateralRateBps: BigInt(0),
        enabled: true,
      });

      const result = await service.getEligibility('0xUser');
      expect(result.eligibleTier).toBe(0);
      expect(result.creditScore).toBe(0);
      expect(result.source).toBe('on-chain');
    });

    it('should return tier 2 for score 25', async () => {
      mockCreditRegistry.scoreOf.mockResolvedValue(BigInt(25));
      mockTierRegistry.tierConfig.mockResolvedValue({
        maxPoolSize: BigInt(5000),
        collateralRateBps: BigInt(500),
        enabled: true,
      });

      const result = await service.getEligibility('0xUser');
      expect(result.eligibleTier).toBe(2);
      expect(result.creditScore).toBe(25);
    });

    it('should return tier 3 for score 50+', async () => {
      mockCreditRegistry.scoreOf.mockResolvedValue(BigInt(100));
      mockTierRegistry.tierConfig.mockResolvedValue({
        maxPoolSize: BigInt(10000),
        collateralRateBps: BigInt(1000),
        enabled: true,
      });

      const result = await service.getEligibility('0xUser');
      expect(result.eligibleTier).toBe(3);
    });

    it('should fall back to DB when on-chain call fails', async () => {
      mockCreditRegistry.scoreOf.mockRejectedValue(new Error('RPC down'));
      creditScoreRepo.findOne.mockResolvedValue({ walletAddress: '0xUser', score: 10 });
      mockTierRegistry.tierConfig.mockResolvedValue({
        maxPoolSize: BigInt(2000),
        collateralRateBps: BigInt(200),
        enabled: true,
      });

      const result = await service.getEligibility('0xUser');
      expect(result.creditScore).toBe(10);
      expect(result.eligibleTier).toBe(1);
      expect(result.source).toBe('cache');
    });

    it('should fall back to DB tier config when on-chain tier read fails', async () => {
      mockCreditRegistry.scoreOf.mockResolvedValue(BigInt(5));
      mockTierRegistry.tierConfig.mockRejectedValue(new Error('RPC down'));
      tierConfigRepo.findOne.mockResolvedValue({
        tier: 1,
        collateralRateBps: 300,
        maxPoolSize: '3000',
      });

      const result = await service.getEligibility('0xUser');
      expect(result.collateralRate).toBe(300);
      expect(result.maxPoolSize).toBe('3000');
    });

    it('should include nextTier and scoreForNextTier', async () => {
      mockCreditRegistry.scoreOf.mockResolvedValue(BigInt(5));
      mockTierRegistry.tierConfig.mockResolvedValue({
        maxPoolSize: BigInt(2000),
        collateralRateBps: BigInt(200),
        enabled: true,
      });

      const result = await service.getEligibility('0xUser');
      expect(result.nextTier).toBe(2);
      expect(result.scoreForNextTier).toBe(20);
    });

    it('should return null nextTier for tier 3', async () => {
      mockCreditRegistry.scoreOf.mockResolvedValue(BigInt(100));
      mockTierRegistry.tierConfig.mockResolvedValue({
        maxPoolSize: BigInt(10000),
        collateralRateBps: BigInt(1000),
        enabled: true,
      });

      const result = await service.getEligibility('0xUser');
      expect(result.nextTier).toBeNull();
      expect(result.scoreForNextTier).toBeNull();
    });
  });

  describe('getAllTiers', () => {
    it('should return all 4 tiers from on-chain', async () => {
      mockTierRegistry.tierConfig.mockImplementation((tier: number) =>
        Promise.resolve({
          maxPoolSize: BigInt(1000 * (tier + 1)),
          collateralRateBps: BigInt(tier * 100),
          enabled: true,
        }),
      );

      const tiers = await service.getAllTiers();
      expect(tiers.length).toBe(4);
      expect(tiers[0].tier).toBe(0);
      expect(tiers[3].tier).toBe(3);
      expect(tiers[0].source).toBe('on-chain');
    });

    it('should fall back to DB when on-chain fails', async () => {
      mockTierRegistry.tierConfig.mockRejectedValue(new Error('RPC down'));
      tierConfigRepo.find.mockResolvedValue([
        { tier: 0, maxPoolSize: '1000', collateralRateBps: 0, enabled: true },
        { tier: 1, maxPoolSize: '2000', collateralRateBps: 200, enabled: true },
      ]);

      const tiers = await service.getAllTiers();
      expect(tiers.length).toBe(2);
    });
  });
});
