import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { NotFoundException, ConflictException } from '@nestjs/common';
import { PoolsService } from './pools.service';
import { Pool } from '../entities/pool.entity';
import { PoolMember } from '../entities/pool-member.entity';
import { Contribution } from '../entities/contribution.entity';
import { PayoutStreamEntity } from '../entities/payout-stream.entity';
import { Web3Service } from '../web3/web3.service';

describe('PoolsService', () => {
  let service: PoolsService;

  const mockPoolRepo = {
    create: jest.fn(),
    save: jest.fn(),
    findOne: jest.fn(),
    find: jest.fn(),
  };

  const mockMemberRepo = {
    create: jest.fn(),
    save: jest.fn(),
    findOne: jest.fn(),
  };

  const mockContributionRepo = {
    create: jest.fn(),
    save: jest.fn(),
    findOne: jest.fn(),
    find: jest.fn(),
  };

  const mockPayoutStreamRepo = {
    create: jest.fn(),
    save: jest.fn(),
  };

  const mockWeb3Service = {
    getEqubPool: jest.fn(),
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        PoolsService,
        { provide: getRepositoryToken(Pool), useValue: mockPoolRepo },
        { provide: getRepositoryToken(PoolMember), useValue: mockMemberRepo },
        { provide: getRepositoryToken(Contribution), useValue: mockContributionRepo },
        { provide: getRepositoryToken(PayoutStreamEntity), useValue: mockPayoutStreamRepo },
        { provide: Web3Service, useValue: mockWeb3Service },
      ],
    }).compile();

    service = module.get<PoolsService>(PoolsService);
  });

  afterEach(() => jest.clearAllMocks());

  describe('createPool', () => {
    it('should create a pool and return it', async () => {
      const poolData = {
        id: 'uuid-123',
        tier: 0,
        contributionAmount: '1000000000000000000',
        maxMembers: 5,
        treasury: '0x1234567890123456789012345678901234567890',
        currentRound: 1,
        status: 'pending-onchain',
      };

      mockPoolRepo.create.mockReturnValue(poolData);
      mockPoolRepo.save.mockResolvedValue(poolData);

      const result = await service.createPool(
        0,
        '1000000000000000000',
        5,
        '0x1234567890123456789012345678901234567890',
      );

      expect(result.id).toBe('uuid-123');
      expect(result.status).toBe('pending-onchain');
      expect(mockPoolRepo.create).toHaveBeenCalled();
    });
  });

  describe('joinPool', () => {
    it('should throw NotFoundException for non-existent pool', async () => {
      mockPoolRepo.findOne.mockResolvedValue(null);
      await expect(service.joinPool('non-existent', '0x123')).rejects.toThrow(
        NotFoundException,
      );
    });

    it('should throw ConflictException if pool is full', async () => {
      mockPoolRepo.findOne.mockResolvedValue({
        id: 'pool-1',
        maxMembers: 2,
        members: [{ walletAddress: '0xa' }, { walletAddress: '0xb' }],
      });
      await expect(service.joinPool('pool-1', '0xc')).rejects.toThrow(
        ConflictException,
      );
    });

    it('should throw ConflictException if already a member', async () => {
      mockPoolRepo.findOne.mockResolvedValue({
        id: 'pool-1',
        maxMembers: 5,
        members: [{ walletAddress: '0xa' }],
      });
      mockMemberRepo.findOne.mockResolvedValue({ walletAddress: '0xa' });
      await expect(service.joinPool('pool-1', '0xa')).rejects.toThrow(
        ConflictException,
      );
    });

    it('should successfully join a pool', async () => {
      mockPoolRepo.findOne.mockResolvedValue({
        id: 'pool-1',
        maxMembers: 5,
        members: [{ walletAddress: '0xa' }],
      });
      mockMemberRepo.findOne.mockResolvedValue(null);
      mockMemberRepo.create.mockReturnValue({ poolId: 'pool-1', walletAddress: '0xb' });
      mockMemberRepo.save.mockResolvedValue({ poolId: 'pool-1', walletAddress: '0xb' });

      const result = await service.joinPool('pool-1', '0xb');
      expect(result.status).toBe('joined');
      expect(result.memberCount).toBe(2);
    });
  });

  describe('closeRound', () => {
    it('should identify contributors and defaulters', async () => {
      mockPoolRepo.findOne.mockResolvedValue({
        id: 'pool-1',
        currentRound: 1,
        members: [
          { walletAddress: '0xa' },
          { walletAddress: '0xb' },
          { walletAddress: '0xc' },
        ],
      });
      mockContributionRepo.find.mockResolvedValue([
        { walletAddress: '0xa' },
        { walletAddress: '0xb' },
      ]);
      mockPoolRepo.save.mockResolvedValue({});

      const result = await service.closeRound('pool-1', 1);

      expect(result.contributors).toEqual(['0xa', '0xb']);
      expect(result.defaulters).toEqual(['0xc']);
      expect(result.nextRound).toBe(2);
    });
  });
});
