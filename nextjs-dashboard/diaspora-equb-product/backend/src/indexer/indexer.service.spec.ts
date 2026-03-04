import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { ConfigService } from '@nestjs/config';
import { IndexerService } from './indexer.service';
import { Web3Service } from '../web3/web3.service';
import { RulesService } from '../rules/rules.service';
import { NotificationsService } from '../notifications/notifications.service';
import { EventsGateway } from '../websocket/events.gateway';
import { Pool } from '../entities/pool.entity';
import { PoolMember } from '../entities/pool-member.entity';
import { Contribution } from '../entities/contribution.entity';
import { PayoutStreamEntity } from '../entities/payout-stream.entity';
import { CreditScore } from '../entities/credit-score.entity';
import { Collateral } from '../entities/collateral.entity';
import { Identity } from '../entities/identity.entity';
import { IndexedBlock } from '../entities/indexed-block.entity';
import { TokenTransfer } from '../entities/token-transfer.entity';
import { Proposal } from '../entities/proposal.entity';

describe('IndexerService', () => {
  let service: IndexerService;
  let poolRepo: any;
  let memberRepo: any;
  let contributionRepo: any;
  let payoutStreamRepo: any;
  let creditScoreRepo: any;
  let collateralRepo: any;
  let identityRepo: any;
  let proposalRepo: any;
  let tokenTransferRepo: any;

  const mockRepo = () => ({
    findOne: jest.fn(),
    find: jest.fn(),
    create: jest.fn((dto) => dto),
    save: jest.fn((entity) => Promise.resolve({ id: 'test-id', ...entity })),
    count: jest.fn(),
    update: jest.fn(),
    createQueryBuilder: jest.fn(),
  });

  const mockWeb3Service = {
    getProvider: jest.fn().mockReturnValue({
      getBlockNumber: jest.fn().mockResolvedValue(100),
      getBlock: jest.fn(),
      getTransaction: jest.fn(),
    }),
    getEqubPool: jest.fn().mockReturnValue({
      queryFilter: jest.fn().mockResolvedValue([]),
      removeAllListeners: jest.fn(),
      on: jest.fn(),
      interface: { parseTransaction: jest.fn() },
    }),
    getPayoutStream: jest.fn().mockReturnValue({
      queryFilter: jest.fn().mockResolvedValue([]),
      removeAllListeners: jest.fn(),
      on: jest.fn(),
    }),
    getCreditRegistry: jest.fn().mockReturnValue({
      queryFilter: jest.fn().mockResolvedValue([]),
      removeAllListeners: jest.fn(),
      on: jest.fn(),
    }),
    getCollateralVault: jest.fn().mockReturnValue({
      queryFilter: jest.fn().mockResolvedValue([]),
      removeAllListeners: jest.fn(),
      on: jest.fn(),
    }),
    getIdentityRegistry: jest.fn().mockReturnValue({
      queryFilter: jest.fn().mockResolvedValue([]),
      removeAllListeners: jest.fn(),
      on: jest.fn(),
    }),
    getEqubGovernor: jest.fn().mockReturnValue({
      queryFilter: jest.fn().mockResolvedValue([]),
      removeAllListeners: jest.fn(),
      on: jest.fn(),
    }),
  };

  const mockNotifications = { create: jest.fn().mockResolvedValue({}) };
  const mockRulesService = {
    fetchRulesFromChain: jest.fn().mockResolvedValue(null),
    upsertRulesFromChain: jest.fn(),
  };
  const mockEventsGateway = {
    emitGlobal: jest.fn(),
    emitToPool: jest.fn(),
  };

  beforeEach(async () => {
    const repos = {
      pool: mockRepo(),
      member: mockRepo(),
      contribution: mockRepo(),
      payoutStream: mockRepo(),
      creditScore: mockRepo(),
      collateral: mockRepo(),
      identity: mockRepo(),
      indexedBlock: mockRepo(),
      tokenTransfer: mockRepo(),
      proposal: mockRepo(),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        IndexerService,
        { provide: Web3Service, useValue: mockWeb3Service },
        { provide: NotificationsService, useValue: mockNotifications },
        { provide: RulesService, useValue: mockRulesService },
        { provide: ConfigService, useValue: { get: jest.fn().mockReturnValue('') } },
        { provide: EventsGateway, useValue: mockEventsGateway },
        { provide: getRepositoryToken(Pool), useValue: repos.pool },
        { provide: getRepositoryToken(PoolMember), useValue: repos.member },
        { provide: getRepositoryToken(Contribution), useValue: repos.contribution },
        { provide: getRepositoryToken(PayoutStreamEntity), useValue: repos.payoutStream },
        { provide: getRepositoryToken(CreditScore), useValue: repos.creditScore },
        { provide: getRepositoryToken(Collateral), useValue: repos.collateral },
        { provide: getRepositoryToken(Identity), useValue: repos.identity },
        { provide: getRepositoryToken(IndexedBlock), useValue: repos.indexedBlock },
        { provide: getRepositoryToken(TokenTransfer), useValue: repos.tokenTransfer },
        { provide: getRepositoryToken(Proposal), useValue: repos.proposal },
      ],
    }).compile();

    service = module.get<IndexerService>(IndexerService);
    poolRepo = module.get(getRepositoryToken(Pool));
    memberRepo = module.get(getRepositoryToken(PoolMember));
    contributionRepo = module.get(getRepositoryToken(Contribution));
    payoutStreamRepo = module.get(getRepositoryToken(PayoutStreamEntity));
    creditScoreRepo = module.get(getRepositoryToken(CreditScore));
    collateralRepo = module.get(getRepositoryToken(Collateral));
    identityRepo = module.get(getRepositoryToken(Identity));
    proposalRepo = module.get(getRepositoryToken(Proposal));
    tokenTransferRepo = module.get(getRepositoryToken(TokenTransfer));
  });

  afterEach(() => jest.clearAllMocks());

  describe('handleScoreUpdated', () => {
    it('should create a new credit score record', async () => {
      creditScoreRepo.findOne.mockResolvedValue(null);
      await (service as any).handleScoreUpdated('0xUser1', BigInt(10));
      expect(creditScoreRepo.create).toHaveBeenCalledWith({
        walletAddress: '0xUser1',
        score: 10,
      });
      expect(creditScoreRepo.save).toHaveBeenCalled();
    });

    it('should update an existing credit score', async () => {
      const existing = { walletAddress: '0xUser1', score: 5 };
      creditScoreRepo.findOne.mockResolvedValue(existing);
      await (service as any).handleScoreUpdated('0xUser1', BigInt(15));
      expect(existing.score).toBe(15);
      expect(creditScoreRepo.save).toHaveBeenCalledWith(existing);
    });
  });

  describe('handleCollateralDeposited', () => {
    it('should create new collateral record if none exists', async () => {
      collateralRepo.findOne.mockResolvedValue(null);
      await (service as any).handleCollateralDeposited('0xUser1', BigInt(1000));
      expect(collateralRepo.create).toHaveBeenCalledWith({
        walletAddress: '0xUser1',
        lockedAmount: '0',
        slashedAmount: '0',
        availableBalance: '1000',
      });
      expect(collateralRepo.save).toHaveBeenCalled();
    });

    it('should add to existing available balance', async () => {
      const existing = {
        walletAddress: '0xUser1',
        availableBalance: '500',
        lockedAmount: '0',
        slashedAmount: '0',
      };
      collateralRepo.findOne.mockResolvedValue(existing);
      await (service as any).handleCollateralDeposited('0xUser1', BigInt(300));
      expect(existing.availableBalance).toBe('800');
      expect(collateralRepo.save).toHaveBeenCalledWith(existing);
    });
  });

  describe('handleCollateralLocked', () => {
    it('should move balance from available to locked', async () => {
      const existing = {
        walletAddress: '0xUser1',
        availableBalance: '1000',
        lockedAmount: '200',
      };
      collateralRepo.findOne.mockResolvedValue(existing);
      await (service as any).handleCollateralLocked('0xUser1', BigInt(300));
      expect(existing.availableBalance).toBe('700');
      expect(existing.lockedAmount).toBe('500');
    });

    it('should do nothing if no collateral record exists', async () => {
      collateralRepo.findOne.mockResolvedValue(null);
      await (service as any).handleCollateralLocked('0xUser1', BigInt(100));
      expect(collateralRepo.save).not.toHaveBeenCalled();
    });
  });

  describe('handleCollateralSlashed', () => {
    it('should slash from locked amount', async () => {
      const existing = {
        walletAddress: '0xUser1',
        lockedAmount: '500',
        slashedAmount: '100',
      };
      collateralRepo.findOne.mockResolvedValue(existing);
      await (service as any).handleCollateralSlashed('0xUser1', BigInt(200));
      expect(existing.lockedAmount).toBe('300');
      expect(existing.slashedAmount).toBe('300');
    });

    it('should cap slash at locked amount', async () => {
      const existing = {
        walletAddress: '0xUser1',
        lockedAmount: '100',
        slashedAmount: '0',
      };
      collateralRepo.findOne.mockResolvedValue(existing);
      await (service as any).handleCollateralSlashed('0xUser1', BigInt(500));
      expect(existing.lockedAmount).toBe('0');
      expect(existing.slashedAmount).toBe('100');
    });
  });

  describe('handleIdentityBound', () => {
    it('should update existing identity by wallet', async () => {
      const existing = { walletAddress: '0xWallet', bindingStatus: 'bound' };
      identityRepo.findOne.mockResolvedValueOnce(existing);
      await (service as any).handleIdentityBound('0xWallet', '0xHash');
      expect(existing.bindingStatus).toBe('onchain');
      expect(identityRepo.save).toHaveBeenCalledWith(existing);
    });

    it('should update existing identity by hash when wallet not found', async () => {
      const existing = { identityHash: '0xHash', walletAddress: null, bindingStatus: 'unbound' };
      identityRepo.findOne
        .mockResolvedValueOnce(null)
        .mockResolvedValueOnce(existing);
      await (service as any).handleIdentityBound('0xNewWallet', '0xHash');
      expect(existing.walletAddress).toBe('0xNewWallet');
      expect(existing.bindingStatus).toBe('onchain');
    });

    it('should create new identity if none exists', async () => {
      identityRepo.findOne.mockResolvedValue(null);
      await (service as any).handleIdentityBound('0xWallet', '0xHash');
      expect(identityRepo.create).toHaveBeenCalledWith({
        identityHash: '0xHash',
        walletAddress: '0xWallet',
        bindingStatus: 'onchain',
      });
      expect(identityRepo.save).toHaveBeenCalled();
    });
  });

  describe('handleRoundClosed', () => {
    it('should update pool currentRound and status', async () => {
      const pool = { id: 'p1', onChainPoolId: 1, currentRound: 1, status: 'active' };
      poolRepo.findOne.mockResolvedValue(pool);
      memberRepo.find.mockResolvedValue([]);
      await (service as any).handleRoundClosed(BigInt(1), BigInt(1));
      expect(pool.currentRound).toBe(2);
      expect(pool.status).toBe('round-closed');
      expect(poolRepo.save).toHaveBeenCalledWith(pool);
    });

    it('should skip if pool not found', async () => {
      poolRepo.findOne.mockResolvedValue(null);
      await (service as any).handleRoundClosed(BigInt(999), BigInt(1));
      expect(poolRepo.save).not.toHaveBeenCalled();
    });
  });

  describe('handleDefaultTriggered', () => {
    it('should create defaulted contribution if none exists', async () => {
      const pool = { id: 'p1', onChainPoolId: 1 };
      poolRepo.findOne.mockResolvedValue(pool);
      contributionRepo.findOne.mockResolvedValue(null);
      await (service as any).handleDefaultTriggered(BigInt(1), '0xMember', BigInt(2));
      expect(contributionRepo.create).toHaveBeenCalledWith({
        poolId: 'p1',
        walletAddress: '0xMember',
        round: 2,
        status: 'defaulted',
        txHash: null,
      });
      expect(contributionRepo.save).toHaveBeenCalled();
    });

    it('should update existing contribution to defaulted', async () => {
      const pool = { id: 'p1', onChainPoolId: 1 };
      const existing = { poolId: 'p1', walletAddress: '0xMember', round: 2, status: 'confirmed' };
      poolRepo.findOne.mockResolvedValue(pool);
      contributionRepo.findOne.mockResolvedValue(existing);
      await (service as any).handleDefaultTriggered(BigInt(1), '0xMember', BigInt(2));
      expect(existing.status).toBe('defaulted');
      expect(contributionRepo.save).toHaveBeenCalledWith(existing);
    });
  });

  describe('handleStreamCreated', () => {
    it('should create payout stream entity', async () => {
      const pool = { id: 'p1', onChainPoolId: 1 };
      poolRepo.findOne.mockResolvedValue(pool);
      payoutStreamRepo.findOne.mockResolvedValue(null);

      await (service as any).handleStreamCreated(
        BigInt(1), '0xBeneficiary', BigInt(10000), BigInt(20), BigInt(1000), BigInt(8),
      );

      expect(payoutStreamRepo.create).toHaveBeenCalledWith(
        expect.objectContaining({
          poolId: 'p1',
          beneficiary: '0xBeneficiary',
          total: '10000',
          upfrontPercent: 20,
          totalRounds: 8,
          releasedRounds: 0,
          frozen: false,
        }),
      );
      expect(payoutStreamRepo.save).toHaveBeenCalled();
    });

    it('should skip if stream already exists (idempotent)', async () => {
      const pool = { id: 'p1', onChainPoolId: 1 };
      poolRepo.findOne.mockResolvedValue(pool);
      payoutStreamRepo.findOne.mockResolvedValue({ id: 'existing' });

      await (service as any).handleStreamCreated(
        BigInt(1), '0xBeneficiary', BigInt(10000), BigInt(20), BigInt(1000), BigInt(8),
      );

      expect(payoutStreamRepo.create).not.toHaveBeenCalled();
    });
  });

  describe('handleStreamFrozen', () => {
    it('should set stream frozen flag', async () => {
      const pool = { id: 'p1', onChainPoolId: 1 };
      const stream = { poolId: 'p1', beneficiary: '0xBen', frozen: false };
      poolRepo.findOne.mockResolvedValue(pool);
      payoutStreamRepo.findOne.mockResolvedValue(stream);

      await (service as any).handleStreamFrozen(BigInt(1), '0xBen');
      expect(stream.frozen).toBe(true);
      expect(payoutStreamRepo.save).toHaveBeenCalledWith(stream);
    });
  });

  describe('handleProposalCreated', () => {
    it('should create proposal entity', async () => {
      proposalRepo.findOne.mockResolvedValue(null);
      poolRepo.findOne.mockResolvedValue({ id: 'p1' });

      await (service as any).handleProposalCreated(
        BigInt(1), BigInt(1), '0xProposer', '0xRuleHash', 'Test proposal', BigInt(1700000000),
      );

      expect(proposalRepo.create).toHaveBeenCalledWith(
        expect.objectContaining({
          onChainProposalId: 1,
          proposer: '0xProposer',
          description: 'Test proposal',
          status: 'active',
        }),
      );
      expect(proposalRepo.save).toHaveBeenCalled();
    });

    it('should skip duplicate proposal (idempotent)', async () => {
      proposalRepo.findOne.mockResolvedValue({ id: 'existing' });
      await (service as any).handleProposalCreated(
        BigInt(1), BigInt(1), '0xProposer', '0xHash', 'dup', BigInt(1700000000),
      );
      expect(proposalRepo.create).not.toHaveBeenCalled();
    });
  });

  describe('handleVoteCast', () => {
    it('should increment yesVotes for support=true', async () => {
      const proposal = { onChainProposalId: 1, yesVotes: 2, noVotes: 1 };
      proposalRepo.findOne.mockResolvedValue(proposal);
      await (service as any).handleVoteCast(BigInt(1), true);
      expect(proposal.yesVotes).toBe(3);
      expect(proposalRepo.save).toHaveBeenCalledWith(proposal);
    });

    it('should increment noVotes for support=false', async () => {
      const proposal = { onChainProposalId: 1, yesVotes: 2, noVotes: 1 };
      proposalRepo.findOne.mockResolvedValue(proposal);
      await (service as any).handleVoteCast(BigInt(1), false);
      expect(proposal.noVotes).toBe(2);
    });

    it('should skip if proposal not found', async () => {
      proposalRepo.findOne.mockResolvedValue(null);
      await (service as any).handleVoteCast(BigInt(999), true);
      expect(proposalRepo.save).not.toHaveBeenCalled();
    });
  });

  describe('handleProposalExecuted', () => {
    it('should set proposal status to executed', async () => {
      const proposal = { status: 'active' };
      proposalRepo.findOne.mockResolvedValue(proposal);
      await (service as any).handleProposalExecuted(BigInt(1));
      expect(proposal.status).toBe('executed');
      expect(proposalRepo.save).toHaveBeenCalledWith(proposal);
    });
  });

  describe('handleProposalCancelled', () => {
    it('should set proposal status to cancelled', async () => {
      const proposal = { status: 'active' };
      proposalRepo.findOne.mockResolvedValue(proposal);
      await (service as any).handleProposalCancelled(BigInt(1));
      expect(proposal.status).toBe('cancelled');
      expect(proposalRepo.save).toHaveBeenCalledWith(proposal);
    });
  });

  describe('handleJoinedPool', () => {
    it('should create pool member', async () => {
      const pool = { id: 'p1', onChainPoolId: 1, tier: 0 };
      poolRepo.findOne.mockResolvedValue(pool);
      memberRepo.findOne.mockResolvedValue(null);

      const mockEvent = { log: { transactionHash: '0xTx' } };
      await (service as any).handleJoinedPool(BigInt(1), '0xMember', mockEvent);

      expect(memberRepo.create).toHaveBeenCalledWith({
        poolId: 'p1',
        walletAddress: '0xMember',
      });
      expect(memberRepo.save).toHaveBeenCalled();
    });

    it('should skip if member already exists (idempotent)', async () => {
      const pool = { id: 'p1', onChainPoolId: 1 };
      poolRepo.findOne.mockResolvedValue(pool);
      memberRepo.findOne.mockResolvedValue({ id: 'existing' });

      await (service as any).handleJoinedPool(BigInt(1), '0xMember', {});
      expect(memberRepo.create).not.toHaveBeenCalled();
    });
  });

  describe('handleContributionReceived', () => {
    it('should create new contribution record', async () => {
      const pool = { id: 'p1', onChainPoolId: 1, status: 'active', createdBy: '0xCreator' };
      poolRepo.findOne.mockResolvedValue(pool);
      contributionRepo.findOne.mockResolvedValue(null);
      memberRepo.find.mockResolvedValue([{ walletAddress: '0xM1' }]);
      contributionRepo.count.mockResolvedValue(0);

      const mockEvent = { log: { transactionHash: '0xTxHash' } };
      await (service as any).handleContributionReceived(BigInt(1), '0xM1', BigInt(1), mockEvent);

      expect(contributionRepo.create).toHaveBeenCalledWith(
        expect.objectContaining({
          poolId: 'p1',
          walletAddress: '0xM1',
          round: 1,
          status: 'confirmed',
        }),
      );
      expect(contributionRepo.save).toHaveBeenCalled();
    });

    it('should update pending contribution to confirmed', async () => {
      const pool = { id: 'p1', onChainPoolId: 1, status: 'active', createdBy: '0xCreator' };
      const existing = { poolId: 'p1', walletAddress: '0xM1', round: 1, status: 'pending-onchain', txHash: null };
      poolRepo.findOne.mockResolvedValue(pool);
      contributionRepo.findOne.mockResolvedValue(existing);
      memberRepo.find.mockResolvedValue([]);
      contributionRepo.count.mockResolvedValue(0);

      const mockEvent = { log: { transactionHash: '0xNewTx' } };
      await (service as any).handleContributionReceived(BigInt(1), '0xM1', BigInt(1), mockEvent);

      expect(existing.status).toBe('confirmed');
      expect(existing.txHash).toBe('0xNewTx');
    });
  });

  describe('handleRoundReleased', () => {
    it('should increment releasedRounds and add to released amount', async () => {
      const pool = { id: 'p1', onChainPoolId: 1 };
      const stream = { poolId: 'p1', beneficiary: '0xBen', releasedRounds: 1, released: '2000' };
      poolRepo.findOne.mockResolvedValue(pool);
      payoutStreamRepo.findOne.mockResolvedValue(stream);

      await (service as any).handleRoundReleased(BigInt(1), '0xBen', BigInt(1000));
      expect(stream.releasedRounds).toBe(2);
      expect(stream.released).toBe('3000');
    });
  });
});
