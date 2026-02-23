import { Test, TestingModule } from '@nestjs/testing';
import { ConfigService } from '@nestjs/config';
import { TokenService } from './token.service';
import { Web3Service } from '../web3/web3.service';
import { IndexerService } from '../indexer/indexer.service';
import { NotificationsService } from '../notifications/notifications.service';

describe('TokenService', () => {
  let service: TokenService;

  const mockProvider = {
    getBlockNumber: jest.fn(),
    getBlock: jest.fn(),
  };

  const mockWeb3Service = {
    getProvider: jest.fn().mockReturnValue(mockProvider),
  };

  const mockConfigService = {
    get: jest.fn((key: string, defaultValue?: unknown) => {
      const map: Record<string, unknown> = {
        CHAIN_ID: 102031,
        TEST_USDC_ADDRESS: '0x1000000000000000000000000000000000000001',
        TEST_USDT_ADDRESS: '0x2000000000000000000000000000000000000002',
      };
      return (map[key] as any) ?? defaultValue;
    }),
  };

  const mockIndexerService = {};
  const mockNotifications = {
    create: jest.fn(),
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        TokenService,
        { provide: Web3Service, useValue: mockWeb3Service },
        { provide: ConfigService, useValue: mockConfigService },
        { provide: IndexerService, useValue: mockIndexerService },
        { provide: NotificationsService, useValue: mockNotifications },
      ],
    }).compile();

    service = module.get<TokenService>(TokenService);
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  it('filters by direction', async () => {
    jest.spyOn<any, any>(service as any, 'getTransactionsFromBlockscout').mockResolvedValue([
      {
        txHash: '0x1',
        type: 'sent',
        token: 'USDC',
        timestamp: 1_700_000_200_000,
        blockNumber: 100,
        isError: false,
      },
      {
        txHash: '0x2',
        type: 'received',
        token: 'USDC',
        timestamp: 1_700_000_100_000,
        blockNumber: 99,
        isError: false,
      },
    ]);
    jest
      .spyOn<any, any>(service as any, 'getTokenTransfersFromBlockscout')
      .mockResolvedValue([]);

    const result = await service.getTransactions(
      '0x1111111111111111111111111111111111111111',
      'ALL',
      50,
      { direction: 'sent' },
    );

    expect(result).toHaveLength(1);
    expect(result[0].type).toBe('sent');
  });

  it('filters by status failed', async () => {
    jest.spyOn<any, any>(service as any, 'getTransactionsFromBlockscout').mockResolvedValue([
      {
        txHash: '0x1',
        type: 'sent',
        token: 'USDC',
        timestamp: 1_700_000_200_000,
        blockNumber: 100,
        isError: false,
      },
      {
        txHash: '0x2',
        type: 'sent',
        token: 'USDC',
        timestamp: 1_700_000_100_000,
        blockNumber: 99,
        isError: true,
      },
    ]);
    jest
      .spyOn<any, any>(service as any, 'getTokenTransfersFromBlockscout')
      .mockResolvedValue([]);

    const result = await service.getTransactions(
      '0x1111111111111111111111111111111111111111',
      'ALL',
      50,
      { status: 'failed' },
    );

    expect(result).toHaveLength(1);
    expect(result[0].isError).toBe(true);
  });

  it('filters by timestamp range inclusively', async () => {
    jest.spyOn<any, any>(service as any, 'getTransactionsFromBlockscout').mockResolvedValue([
      {
        txHash: '0x1',
        type: 'sent',
        token: 'USDC',
        timestamp: 1_700_000_000_000,
        blockNumber: 100,
        isError: false,
      },
      {
        txHash: '0x2',
        type: 'received',
        token: 'USDC',
        timestamp: 1_700_000_500_000,
        blockNumber: 101,
        isError: false,
      },
      {
        txHash: '0x3',
        type: 'received',
        token: 'USDC',
        timestamp: 1_700_001_000_000,
        blockNumber: 102,
        isError: false,
      },
    ]);
    jest
      .spyOn<any, any>(service as any, 'getTokenTransfersFromBlockscout')
      .mockResolvedValue([]);

    const result = await service.getTransactions(
      '0x1111111111111111111111111111111111111111',
      'ALL',
      50,
      {
        fromTimestamp: 1_700_000_000_000,
        toTimestamp: 1_700_000_500_000,
      },
    );

    expect(result).toHaveLength(2);
    expect(result.map((tx) => tx.txHash)).toEqual(['0x2', '0x1']);
  });

  it('filters by token symbol', async () => {
    jest.spyOn<any, any>(service as any, 'getTransactionsFromBlockscout').mockResolvedValue([
      {
        txHash: '0x1',
        type: 'sent',
        token: 'USDC',
        timestamp: 1_700_000_000_000,
        blockNumber: 100,
        isError: false,
      },
      {
        txHash: '0x2',
        type: 'received',
        token: 'USDT',
        timestamp: 1_700_000_100_000,
        blockNumber: 101,
        isError: false,
      },
    ]);
    jest
      .spyOn<any, any>(service as any, 'getTokenTransfersFromBlockscout')
      .mockResolvedValue([]);

    const result = await service.getTransactions(
      '0x1111111111111111111111111111111111111111',
      'USDT',
      50,
      {},
    );

    expect(result).toHaveLength(1);
    expect(result[0].token).toBe('USDT');
  });
});
