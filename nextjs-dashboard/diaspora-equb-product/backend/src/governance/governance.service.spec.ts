import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { NotFoundException } from '@nestjs/common';
import { GovernanceService } from './governance.service';
import { Proposal } from '../entities/proposal.entity';
import { Pool } from '../entities/pool.entity';
import { Web3Service } from '../web3/web3.service';

describe('GovernanceService', () => {
  let service: GovernanceService;
  let proposalRepo: any;
  let poolRepo: any;

  const mockGovernor = {
    interface: {
      encodeFunctionData: jest.fn().mockReturnValue('0xEncodedData'),
    },
    getAddress: jest.fn().mockResolvedValue('0xGovernorAddr'),
  };

  const mockWeb3Service = {
    getEqubGovernor: jest.fn().mockReturnValue(mockGovernor),
    buildUnsignedTx: jest.fn((to, data, value, gas) => ({
      to,
      data,
      value: value || '0',
      chainId: 102031,
      estimatedGas: gas || '200000',
    })),
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        GovernanceService,
        { provide: Web3Service, useValue: mockWeb3Service },
        {
          provide: getRepositoryToken(Proposal),
          useValue: {
            find: jest.fn(),
            findOne: jest.fn(),
            create: jest.fn((dto) => dto),
            save: jest.fn((entity) => Promise.resolve(entity)),
          },
        },
        {
          provide: getRepositoryToken(Pool),
          useValue: {
            findOne: jest.fn(),
          },
        },
      ],
    }).compile();

    service = module.get<GovernanceService>(GovernanceService);
    proposalRepo = module.get(getRepositoryToken(Proposal));
    poolRepo = module.get(getRepositoryToken(Pool));
  });

  afterEach(() => jest.clearAllMocks());

  describe('getProposals', () => {
    it('should return proposals for a pool', async () => {
      const proposals = [{ id: '1', poolId: 'p1' }, { id: '2', poolId: 'p1' }];
      proposalRepo.find.mockResolvedValue(proposals);

      const result = await service.getProposals('p1');
      expect(result).toEqual(proposals);
      expect(proposalRepo.find).toHaveBeenCalledWith({
        where: { poolId: 'p1' },
        order: { createdAt: 'DESC' },
      });
    });
  });

  describe('getProposal', () => {
    it('should return a single proposal', async () => {
      const proposal = { id: 'prop1', poolId: 'p1' };
      proposalRepo.findOne.mockResolvedValue(proposal);

      const result = await service.getProposal('p1', 'prop1');
      expect(result).toEqual(proposal);
    });

    it('should throw NotFoundException if not found', async () => {
      proposalRepo.findOne.mockResolvedValue(null);
      await expect(service.getProposal('p1', 'missing')).rejects.toThrow(NotFoundException);
    });
  });

  describe('buildProposeTx', () => {
    it('should encode proposeRuleChange and return unsigned TX', async () => {
      poolRepo.findOne.mockResolvedValue({ id: 'p1', onChainPoolId: 1 });

      const rules = {
        equbType: 1,
        frequency: 2,
        payoutMethod: 1,
        gracePeriodSeconds: 3600,
        penaltySeverity: 5,
        roundDurationSeconds: 86400,
        lateFeePercent: 2,
      };

      const result = await service.buildProposeTx('p1', rules, 'Change rules', '0xCaller');
      expect(result.to).toBe('0xGovernorAddr');
      expect(result.data).toBe('0xEncodedData');
      expect(mockGovernor.interface.encodeFunctionData).toHaveBeenCalledWith(
        'proposeRuleChange',
        [1, [1, 2, 1, 3600, 5, 86400, 2], 'Change rules'],
      );
    });

    it('should throw NotFoundException if pool not found', async () => {
      poolRepo.findOne.mockResolvedValue(null);
      await expect(
        service.buildProposeTx('missing', {} as any, 'desc', '0xCaller'),
      ).rejects.toThrow(NotFoundException);
    });
  });

  describe('buildVoteTx', () => {
    it('should encode vote(proposalId, support)', async () => {
      const result = await service.buildVoteTx(1, true, '0xVoter');
      expect(result.to).toBe('0xGovernorAddr');
      expect(mockGovernor.interface.encodeFunctionData).toHaveBeenCalledWith('vote', [1, true]);
    });

    it('should encode vote with support=false', async () => {
      await service.buildVoteTx(5, false, '0xVoter');
      expect(mockGovernor.interface.encodeFunctionData).toHaveBeenCalledWith('vote', [5, false]);
    });
  });

  describe('buildExecuteTx', () => {
    it('should encode executeProposal(proposalId)', async () => {
      const result = await service.buildExecuteTx(3, '0xExecutor');
      expect(result.to).toBe('0xGovernorAddr');
      expect(mockGovernor.interface.encodeFunctionData).toHaveBeenCalledWith('executeProposal', [3]);
    });
  });
});
