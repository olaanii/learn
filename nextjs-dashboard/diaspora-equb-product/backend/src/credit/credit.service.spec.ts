import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { CreditService } from './credit.service';
import { CreditScore } from '../entities/credit-score.entity';
import { Web3Service } from '../web3/web3.service';

describe('CreditService', () => {
  let service: CreditService;

  const mockCreditScoreRepo = {
    findOne: jest.fn(),
    create: jest.fn(),
    save: jest.fn(),
  };

  const mockWeb3Service = {
    getCreditRegistry: jest.fn(),
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        CreditService,
        { provide: getRepositoryToken(CreditScore), useValue: mockCreditScoreRepo },
        { provide: Web3Service, useValue: mockWeb3Service },
      ],
    }).compile();

    service = module.get<CreditService>(CreditService);
  });

  afterEach(() => jest.clearAllMocks());

  describe('updateScore', () => {
    it('should create new score record if not found', async () => {
      mockCreditScoreRepo.findOne.mockResolvedValue(null);
      mockCreditScoreRepo.create.mockReturnValue({
        walletAddress: '0x123',
        score: 0,
      });
      mockCreditScoreRepo.save.mockResolvedValue({
        walletAddress: '0x123',
        score: 5,
      });

      const result = await service.updateScore('0x123', 5, 'round-completion');

      expect(result.newScore).toBe(5);
      expect(result.delta).toBe(5);
      expect(result.reason).toBe('round-completion');
    });

    it('should update existing score', async () => {
      mockCreditScoreRepo.findOne.mockResolvedValue({
        walletAddress: '0x123',
        score: 10,
      });
      mockCreditScoreRepo.save.mockResolvedValue({
        walletAddress: '0x123',
        score: 0,
      });

      const result = await service.updateScore('0x123', -10, 'default');

      expect(result.previousScore).toBe(10);
      expect(result.newScore).toBe(0);
    });
  });

  describe('getScore', () => {
    it('should return 0 for unknown wallet', async () => {
      mockCreditScoreRepo.findOne.mockResolvedValue(null);
      const result = await service.getScore('0x999');
      expect(result.score).toBe(0);
    });

    it('should return existing score', async () => {
      mockCreditScoreRepo.findOne.mockResolvedValue({
        walletAddress: '0x123',
        score: 42,
        lastUpdated: new Date(),
      });
      const result = await service.getScore('0x123');
      expect(result.score).toBe(42);
    });
  });
});
