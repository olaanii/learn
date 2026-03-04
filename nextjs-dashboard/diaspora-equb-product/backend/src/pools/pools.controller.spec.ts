import { Test, TestingModule } from '@nestjs/testing';
import { PoolsController } from './pools.controller';
import { PoolsService } from './pools.service';

describe('PoolsController', () => {
  let controller: PoolsController;
  let poolsService: any;

  const mockPoolsService = {
    buildCreatePool: jest.fn(),
    buildJoinPool: jest.fn(),
    buildContribute: jest.fn(),
    buildApproveToken: jest.fn(),
    buildCloseRound: jest.fn(),
    buildScheduleStream: jest.fn(),
    buildSelectWinner: jest.fn(),
    getPool: jest.fn(),
    getPoolToken: jest.fn(),
    listPools: jest.fn(),
    createPool: jest.fn(),
    joinPool: jest.fn(),
    createPoolFromCreationTx: jest.fn(),
    closeActiveRound: jest.fn(),
    pickWinnerForActiveRound: jest.fn(),
    configureTiersOnChain: jest.fn(),
    createNextSeason: jest.fn(),
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [PoolsController],
      providers: [{ provide: PoolsService, useValue: mockPoolsService }],
    }).compile();

    controller = module.get<PoolsController>(PoolsController);
    poolsService = module.get(PoolsService);
  });

  afterEach(() => jest.clearAllMocks());

  describe('buildCreatePool', () => {
    it('should delegate to poolsService.buildCreatePool', async () => {
      const unsignedTx = { to: '0xPool', data: '0x1', value: '0', chainId: 102031 };
      mockPoolsService.buildCreatePool.mockResolvedValue(unsignedTx);

      const result = await controller.buildCreatePool({
        tier: 0,
        contributionAmount: '1000',
        maxMembers: 5,
        treasury: '0xTreasury',
      });

      expect(result).toEqual(unsignedTx);
      expect(mockPoolsService.buildCreatePool).toHaveBeenCalledWith(
        0, '1000', 5, '0xTreasury', undefined,
      );
    });
  });

  describe('buildJoinPool', () => {
    it('should delegate to poolsService.buildJoinPool', async () => {
      const unsignedTx = { to: '0xPool', data: '0x2', value: '0', chainId: 102031 };
      mockPoolsService.buildJoinPool.mockResolvedValue(unsignedTx);

      const result = await controller.buildJoinPool({
        onChainPoolId: 1,
        caller: '0xUser',
      });

      expect(result).toEqual(unsignedTx);
    });
  });

  describe('buildContribute', () => {
    it('should delegate to poolsService.buildContribute', async () => {
      const unsignedTx = { to: '0xPool', data: '0x3', value: '1000', chainId: 102031 };
      mockPoolsService.buildContribute.mockResolvedValue(unsignedTx);

      const result = await controller.buildContribute({
        onChainPoolId: 1,
        contributionAmount: '1000',
      });

      expect(result).toEqual(unsignedTx);
    });
  });

  describe('getPool', () => {
    it('should return pool data', async () => {
      const pool = { id: 'p1', tier: 0, status: 'active' };
      mockPoolsService.getPool.mockResolvedValue(pool);

      const result = await controller.getPool('p1');
      expect(result).toEqual(pool);
      expect(mockPoolsService.getPool).toHaveBeenCalledWith('p1');
    });
  });

  describe('listPools', () => {
    it('should list pools with optional tier filter', async () => {
      const pools = [{ id: 'p1' }, { id: 'p2' }];
      mockPoolsService.listPools.mockResolvedValue(pools);

      const result = await controller.listPools('1');
      expect(result).toEqual(pools);
    });

    it('should list all pools without tier filter', async () => {
      mockPoolsService.listPools.mockResolvedValue([]);
      const result = await controller.listPools(undefined);
      expect(result).toEqual([]);
    });
  });

  describe('selectWinner', () => {
    it('should delegate to poolsService.buildSelectWinner', async () => {
      const response = { winner: '0xWinner', round: 1 };
      mockPoolsService.buildSelectWinner.mockResolvedValue(response);

      const result = await controller.selectWinner('p1', {
        total: '1000',
        upfrontPercent: 20,
        totalRounds: 5,
        caller: '0xCreator',
      });

      expect(result).toEqual(response);
    });
  });

  describe('getPoolToken', () => {
    it('should return pool token info', async () => {
      const tokenInfo = { symbol: 'USDC', decimals: 6, address: '0xToken' };
      mockPoolsService.getPoolToken.mockResolvedValue(tokenInfo);

      const result = await controller.getPoolToken('p1');
      expect(result).toEqual(tokenInfo);
    });
  });

  describe('configureTiers', () => {
    it('should delegate to poolsService.configureTiersOnChain', async () => {
      mockPoolsService.configureTiersOnChain.mockResolvedValue({ status: 'configured' });
      const result = await controller.configureTiers();
      expect(result).toEqual({ status: 'configured' });
    });
  });
});
