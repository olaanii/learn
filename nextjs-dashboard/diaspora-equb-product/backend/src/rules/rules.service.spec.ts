import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { NotFoundException, ForbiddenException } from '@nestjs/common';
import { RulesService } from './rules.service';
import { Pool } from '../entities/pool.entity';
import { EqubRulesEntity } from '../entities/equb-rules.entity';
import { Web3Service } from '../web3/web3.service';

describe('RulesService', () => {
  let service: RulesService;
  let poolRepo: any;
  let rulesRepo: any;

  const mockEqubPool = {
    getRules: jest.fn(),
  };

  const mockWeb3Service = {
    getEqubPool: jest.fn().mockReturnValue(mockEqubPool),
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        RulesService,
        { provide: Web3Service, useValue: mockWeb3Service },
        {
          provide: getRepositoryToken(Pool),
          useValue: {
            findOne: jest.fn(),
            update: jest.fn(),
          },
        },
        {
          provide: getRepositoryToken(EqubRulesEntity),
          useValue: {
            findOne: jest.fn(),
            create: jest.fn((dto) => dto),
            save: jest.fn((entity) => Promise.resolve(entity)),
          },
        },
      ],
    }).compile();

    service = module.get<RulesService>(RulesService);
    poolRepo = module.get(getRepositoryToken(Pool));
    rulesRepo = module.get(getRepositoryToken(EqubRulesEntity));
  });

  afterEach(() => jest.clearAllMocks());

  describe('getRules', () => {
    it('should return rules from DB if present', async () => {
      poolRepo.findOne.mockResolvedValue({ id: 'p1', onChainPoolId: 1 });
      rulesRepo.findOne.mockResolvedValue({
        poolId: 'p1',
        equbType: 1,
        frequency: 2,
        payoutMethod: 1,
        gracePeriodSeconds: 3600,
        penaltySeverity: 5,
        roundDurationSeconds: 86400,
        lateFeePercent: 2,
      });

      const result = await service.getRules('p1');
      expect(result.equbType).toBe(1);
      expect(result.source).toBe('db');
    });

    it('should fetch from chain if not in DB', async () => {
      poolRepo.findOne.mockResolvedValue({ id: 'p1', onChainPoolId: 1, equbType: null });
      rulesRepo.findOne.mockResolvedValueOnce(null);
      mockEqubPool.getRules.mockResolvedValue([1, 2, 1, 3600, 5, 86400, 2]);
      rulesRepo.findOne.mockResolvedValueOnce(null);
      rulesRepo.save.mockImplementation((entity: any) => Promise.resolve(entity));

      const result = await service.getRules('p1');
      expect(result.equbType).toBe(1);
      expect(result.source).toBe('db');
    });

    it('should return defaults if no rules found anywhere', async () => {
      poolRepo.findOne.mockResolvedValue({ id: 'p1', onChainPoolId: null });
      rulesRepo.findOne.mockResolvedValue(null);

      const result = await service.getRules('p1');
      expect(result.equbType).toBe(0);
      expect(result.source).toBe('default');
    });

    it('should throw NotFoundException if pool not found', async () => {
      poolRepo.findOne.mockResolvedValue(null);
      await expect(service.getRules('missing')).rejects.toThrow(NotFoundException);
    });
  });

  describe('setRules', () => {
    it('should create rules for pool', async () => {
      poolRepo.findOne.mockResolvedValue({ id: 'p1', createdBy: '0xcreator' });
      rulesRepo.findOne.mockResolvedValue(null);

      const dto = {
        equbType: 2,
        frequency: 1,
        payoutMethod: 0,
        gracePeriodSeconds: 7200,
        penaltySeverity: 8,
      };

      const result = await service.setRules('p1', dto as any, '0xCreator');
      expect(rulesRepo.create).toHaveBeenCalled();
      expect(rulesRepo.save).toHaveBeenCalled();
      expect(poolRepo.update).toHaveBeenCalled();
    });

    it('should throw ForbiddenException if not creator', async () => {
      poolRepo.findOne.mockResolvedValue({ id: 'p1', createdBy: '0xcreator' });
      await expect(
        service.setRules('p1', {} as any, '0xOtherUser'),
      ).rejects.toThrow(ForbiddenException);
    });
  });

  describe('updateRules', () => {
    it('should partially update existing rules', async () => {
      poolRepo.findOne.mockResolvedValue({ id: 'p1', createdBy: '0xcreator' });
      const existing = {
        poolId: 'p1',
        equbType: 0,
        frequency: 1,
        payoutMethod: 0,
        gracePeriodSeconds: 604800,
        penaltySeverity: 10,
        roundDurationSeconds: 2592000,
        lateFeePercent: 0,
      };
      rulesRepo.findOne.mockResolvedValue(existing);

      await service.updateRules('p1', { penaltySeverity: 15 } as any, '0xCreator');
      expect(existing.penaltySeverity).toBe(15);
      expect(rulesRepo.save).toHaveBeenCalledWith(existing);
    });

    it('should create rules if none exist and apply partial update', async () => {
      poolRepo.findOne.mockResolvedValue({ id: 'p1', createdBy: '0xcreator' });
      rulesRepo.findOne.mockResolvedValue(null);

      await service.updateRules('p1', { equbType: 3 } as any, '0xCreator');
      expect(rulesRepo.create).toHaveBeenCalled();
      expect(rulesRepo.save).toHaveBeenCalled();
    });
  });

  describe('fetchRulesFromChain', () => {
    it('should return parsed rules from on-chain', async () => {
      mockEqubPool.getRules.mockResolvedValue([1, 2, 1, 3600, 5, 86400, 2]);
      const result = await service.fetchRulesFromChain(1);
      expect(result).toEqual({
        equbType: 1,
        frequency: 2,
        payoutMethod: 1,
        gracePeriodSeconds: 3600,
        penaltySeverity: 5,
        roundDurationSeconds: 86400,
        lateFeePercent: 2,
      });
    });

    it('should return null on chain error', async () => {
      mockEqubPool.getRules.mockRejectedValue(new Error('RPC error'));
      const result = await service.fetchRulesFromChain(1);
      expect(result).toBeNull();
    });
  });

  describe('upsertRulesFromChain', () => {
    it('should create new rules entity', async () => {
      rulesRepo.findOne.mockResolvedValue(null);
      const rules = {
        equbType: 1,
        frequency: 2,
        payoutMethod: 1,
        gracePeriodSeconds: 3600,
        penaltySeverity: 5,
        roundDurationSeconds: 86400,
        lateFeePercent: 2,
      };

      await service.upsertRulesFromChain('p1', 1, rules);
      expect(rulesRepo.create).toHaveBeenCalledWith({ poolId: 'p1', ...rules });
      expect(rulesRepo.save).toHaveBeenCalled();
      expect(poolRepo.update).toHaveBeenCalled();
    });

    it('should update existing rules entity', async () => {
      const existing = { poolId: 'p1', equbType: 0 };
      rulesRepo.findOne.mockResolvedValue(existing);
      const rules = {
        equbType: 1,
        frequency: 2,
        payoutMethod: 1,
        gracePeriodSeconds: 3600,
        penaltySeverity: 5,
        roundDurationSeconds: 86400,
        lateFeePercent: 2,
      };

      await service.upsertRulesFromChain('p1', 1, rules);
      expect(existing.equbType).toBe(1);
      expect(rulesRepo.save).toHaveBeenCalledWith(existing);
    });
  });
});
