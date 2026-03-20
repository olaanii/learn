import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import {
  NotFoundException,
  ConflictException,
  BadRequestException,
  HttpException,
} from '@nestjs/common';
import { PoolsService } from './pools.service';
import { Pool } from '../entities/pool.entity';
import { PoolMember } from '../entities/pool-member.entity';
import { Contribution } from '../entities/contribution.entity';
import { PayoutStreamEntity } from '../entities/payout-stream.entity';
import { Season } from '../entities/season.entity';
import { Round } from '../entities/round.entity';
import { IdempotencyKey } from '../entities/idempotency-key.entity';
import { Web3Service } from '../web3/web3.service';
import { NotificationsService } from '../notifications/notifications.service';
import { RulesService } from '../rules/rules.service';
import { EventsGateway } from '../websocket/events.gateway';
import { DataSource } from 'typeorm';
import { createHash } from 'crypto';

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
    find: jest.fn(),
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
    find: jest.fn(),
  };

  const mockSeasonRepo = {
    create: jest.fn(),
    save: jest.fn(),
    findOne: jest.fn(),
  };

  const mockRoundRepo = {
    create: jest.fn(),
    save: jest.fn(),
    findOne: jest.fn(),
    find: jest.fn(),
  };

  const mockIdempotencyRepo = {
    create: jest.fn(),
    save: jest.fn(),
    findOne: jest.fn(),
  };

  const mockWeb3Service = {
    getEqubPool: jest.fn(),
  };

  const mockNotifications = {
    create: jest.fn(),
  };

  const mockRulesService = {
    fetchRulesFromChain: jest.fn().mockResolvedValue(null),
    upsertRulesFromChain: jest.fn().mockResolvedValue({}),
  };

  const mockEventsGateway = {
    emitWinnerRandomizing: jest.fn(),
    emitWinnerPicked: jest.fn(),
    emitContributionReceived: jest.fn(),
    emitRoundClosed: jest.fn(),
    emitPayoutSent: jest.fn(),
    emitMemberJoined: jest.fn(),
  };

  const mockDataSource = {
    transaction: jest.fn(),
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        PoolsService,
        { provide: getRepositoryToken(Pool), useValue: mockPoolRepo },
        { provide: getRepositoryToken(PoolMember), useValue: mockMemberRepo },
        { provide: getRepositoryToken(Contribution), useValue: mockContributionRepo },
        { provide: getRepositoryToken(PayoutStreamEntity), useValue: mockPayoutStreamRepo },
        { provide: getRepositoryToken(Season), useValue: mockSeasonRepo },
        { provide: getRepositoryToken(Round), useValue: mockRoundRepo },
        { provide: getRepositoryToken(IdempotencyKey), useValue: mockIdempotencyRepo },
        { provide: Web3Service, useValue: mockWeb3Service },
        { provide: NotificationsService, useValue: mockNotifications },
        { provide: RulesService, useValue: mockRulesService },
        { provide: EventsGateway, useValue: mockEventsGateway },
        { provide: DataSource, useValue: mockDataSource },
      ],
    }).compile();

    service = module.get<PoolsService>(PoolsService);
  });

  afterEach(() => jest.clearAllMocks());

  beforeEach(() => {
    mockSeasonRepo.findOne.mockResolvedValue({
      id: 'season-1',
      poolId: 'pool-1',
      seasonNumber: 1,
      status: 'active',
      totalRounds: 5,
      completedRounds: 0,
      contributionAmount: '1000',
      token: '0x0000000000000000000000000000000000000000',
      payoutSplitPct: 20,
      cadence: null,
      startedAt: new Date(),
      completedAt: null,
    });
    mockSeasonRepo.save.mockImplementation(async (entity) => entity);
    mockRoundRepo.save.mockImplementation(async (entity) => ({
      id: entity.id ?? 'round-saved',
      ...entity,
    }));
    mockRoundRepo.create.mockImplementation((entity) => ({ ...entity }));
    mockRoundRepo.find.mockResolvedValue([]);
    mockIdempotencyRepo.create.mockImplementation((entity) => ({ ...entity }));
    mockIdempotencyRepo.save.mockImplementation(async (entity) => entity);
    mockDataSource.transaction.mockImplementation(async (cb) =>
      cb({
        getRepository: (token: unknown) => {
          if (token === Pool) return mockPoolRepo;
          if (token === Season) return mockSeasonRepo;
          if (token === Round) return mockRoundRepo;
          if (token === IdempotencyKey) return mockIdempotencyRepo;
          if (token === PoolMember) return mockMemberRepo;
          return mockContributionRepo;
        },
      }),
    );
  });

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

  describe('buildSelectWinner', () => {
    it('should auto-select rotating winner and build both txs', async () => {
      mockWeb3Service.getEqubPool.mockReturnValue({
        rotatingWinnerForLastClosedRound: jest
          .fn()
          .mockResolvedValue([
            1n,
            '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          ]),
        winnerScheduled: jest.fn().mockResolvedValue(false),
      });

      mockPoolRepo.findOne.mockResolvedValue({
        id: 'pool-1',
        onChainPoolId: 7,
        createdBy: '0x1234567890123456789012345678901234567890',
        currentRound: 1,
        members: [
          { walletAddress: '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa' },
          { walletAddress: '0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb' },
        ],
      });
      mockContributionRepo.find.mockResolvedValue([
        { walletAddress: '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa' },
      ]);
      mockPayoutStreamRepo.find = jest.fn().mockResolvedValue([]);

      jest.spyOn(service, 'buildCloseRound').mockResolvedValue({
        to: '0xclose',
        data: '0x1',
        value: '0',
        chainId: 102031,
        estimatedGas: '1',
      });
      jest.spyOn(service, 'buildScheduleStream').mockResolvedValue({
        to: '0xschedule',
        data: '0x2',
        value: '0',
        chainId: 102031,
        estimatedGas: '1',
      });

      const result = await service.buildSelectWinner('pool-1', {
        total: '1000',
        upfrontPercent: 20,
        totalRounds: 5,
        caller: '0x1234567890123456789012345678901234567890',
      });

      expect(result.winner).toBe('0xaAaAaAaaAaAaAaaAaAAAAAAAAaaaAaAaAaaAaaAa');
      expect(result.round).toBe(1);
      expect(service.buildCloseRound).toHaveBeenCalledWith(7);
      expect(service.buildScheduleStream).toHaveBeenCalledWith(
        7,
        '0xaAaAaAaaAaAaAaaAaAAAAAAAAaaaAaAaAaaAaaAa',
        '1000',
        20,
        5,
      );
    });

    it('should reject a provided winner that does not match rotation', async () => {
      mockWeb3Service.getEqubPool.mockReturnValue({
        rotatingWinnerForLastClosedRound: jest
          .fn()
          .mockResolvedValue([
            1n,
            '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          ]),
        winnerScheduled: jest.fn().mockResolvedValue(false),
      });

      mockPoolRepo.findOne.mockResolvedValue({
        id: 'pool-1',
        onChainPoolId: 7,
        createdBy: '0x1234567890123456789012345678901234567890',
        currentRound: 1,
        members: [
          { walletAddress: '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa' },
          { walletAddress: '0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb' },
        ],
      });
      mockContributionRepo.find.mockResolvedValue([
        { walletAddress: '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa' },
      ]);
      mockPayoutStreamRepo.find = jest.fn().mockResolvedValue([]);

      await expect(
        service.buildSelectWinner('pool-1', {
          phase: 'schedule',
          winner: '0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
          total: '1000',
          upfrontPercent: 20,
          totalRounds: 5,
          caller: '0x1234567890123456789012345678901234567890',
        }),
      ).rejects.toThrow(BadRequestException);
    });
  });

  describe('Phase 1 active round endpoints', () => {
    it('closeActiveRound should reject non-admin caller', async () => {
      mockPoolRepo.findOne.mockResolvedValue({
        id: 'pool-1',
        createdBy: '0x1111111111111111111111111111111111111111',
      });

      await expect(
        service.closeActiveRound(
          'pool-1',
          '0x2222222222222222222222222222222222222222',
        ),
      ).rejects.toThrow(HttpException);
    });

    it('pickWinnerForActiveRound should return replayed response for same key+payload', async () => {
      const requestHash = createHash('sha256')
        .update(JSON.stringify({ mode: 'auto' }))
        .digest('hex');
      const replayBody = {
        pool: { id: 'pool-1' },
        season: { id: 'season-1' },
        round: { id: 'round-1' },
        winner: { wallet: '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa' },
      };
      mockIdempotencyRepo.findOne.mockResolvedValue({
        key: 'idem-1',
        route: 'POST:/pools/pool-1/rounds/active/pick-winner',
        requestHash,
        responseBody: replayBody,
      });

      const result = await service.pickWinnerForActiveRound({
        poolId: 'pool-1',
        mode: 'auto',
        idempotencyKey: 'idem-1',
        caller: '0x1111111111111111111111111111111111111111',
      });

      expect(result).toEqual(replayBody);
    });

    it('pickWinnerForActiveRound should reject key replay conflict', async () => {
      mockIdempotencyRepo.findOne.mockResolvedValue({
        key: 'idem-1',
        route: 'POST:/pools/pool-1/rounds/active/pick-winner',
        requestHash: 'different-hash',
        responseBody: { ok: true },
      });

      await expect(
        service.pickWinnerForActiveRound({
          poolId: 'pool-1',
          mode: 'auto',
          idempotencyKey: 'idem-1',
          caller: '0x1111111111111111111111111111111111111111',
        }),
      ).rejects.toThrow(HttpException);
    });

    it('pickWinnerForActiveRound should select winner using random index', async () => {
      mockIdempotencyRepo.findOne.mockResolvedValue(null);

      mockPoolRepo.findOne.mockResolvedValue({
        id: 'pool-1',
        createdBy: '0x1111111111111111111111111111111111111111',
        currentRound: 1,
        activeRoundId: 'round-1',
        status: 'active',
      });

      mockRoundRepo.findOne
        .mockResolvedValueOnce({
          id: 'round-1',
          poolId: 'pool-1',
          seasonId: 'season-1',
          roundNumber: 1,
          status: 'closed',
          closedAt: new Date(),
          winnerPickedAt: null,
          winnerWallet: null,
        })
        .mockResolvedValueOnce({
          id: 'round-1',
          poolId: 'pool-1',
          seasonId: 'season-1',
          roundNumber: 1,
          status: 'closed',
          closedAt: new Date(),
          winnerPickedAt: null,
          winnerWallet: null,
        });

      mockMemberRepo.find = jest.fn().mockResolvedValue([
        {
          walletAddress: '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          joinedAt: new Date('2026-01-01T00:00:00.000Z'),
        },
        {
          walletAddress: '0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
          joinedAt: new Date('2026-01-02T00:00:00.000Z'),
        },
      ]);

      const randomSpy = jest
        .spyOn(service as any, 'pickRandomIndex')
        .mockReturnValue(1);

      const result = await service.pickWinnerForActiveRound({
        poolId: 'pool-1',
        mode: 'auto',
        idempotencyKey: 'idem-random-1',
        caller: '0x1111111111111111111111111111111111111111',
      });

      expect(randomSpy).toHaveBeenCalledWith(2);
      expect((result as any).winner.wallet).toBe(
        '0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB',
      );
    });

    it('pickWinnerForActiveRound should not repeat winner within same season', async () => {
      mockIdempotencyRepo.findOne.mockResolvedValue(null);

      mockPoolRepo.findOne.mockResolvedValue({
        id: 'pool-1',
        createdBy: '0x1111111111111111111111111111111111111111',
        currentRound: 2,
        activeRoundId: 'round-2',
        status: 'round-closed',
      });

      mockRoundRepo.findOne
        .mockResolvedValueOnce({
          id: 'round-2',
          poolId: 'pool-1',
          seasonId: 'season-1',
          roundNumber: 2,
          status: 'closed',
          closedAt: new Date(),
          winnerPickedAt: null,
          winnerWallet: null,
        })
        .mockResolvedValueOnce({
          id: 'round-2',
          poolId: 'pool-1',
          seasonId: 'season-1',
          roundNumber: 2,
          status: 'closed',
          closedAt: new Date(),
          winnerPickedAt: null,
          winnerWallet: null,
        });

      mockRoundRepo.find.mockResolvedValue([
        {
          id: 'round-1',
          poolId: 'pool-1',
          seasonId: 'season-1',
          roundNumber: 1,
          status: 'winner_picked',
          winnerWallet: '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        },
      ]);

      mockMemberRepo.find = jest.fn().mockResolvedValue([
        {
          walletAddress: '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          joinedAt: new Date('2026-01-01T00:00:00.000Z'),
        },
        {
          walletAddress: '0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
          joinedAt: new Date('2026-01-02T00:00:00.000Z'),
        },
      ]);

      const randomSpy = jest
        .spyOn(service as any, 'pickRandomIndex')
        .mockReturnValue(0);

      const result = await service.pickWinnerForActiveRound({
        poolId: 'pool-1',
        mode: 'auto',
        idempotencyKey: 'idem-no-repeat-1',
        caller: '0x1111111111111111111111111111111111111111',
      });

      expect(randomSpy).toHaveBeenCalledWith(1);
      expect((result as any).winner.wallet).toBe(
        '0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB',
      );
    });
  });
});
