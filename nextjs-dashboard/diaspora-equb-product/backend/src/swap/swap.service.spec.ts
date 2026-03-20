import { Test, TestingModule } from '@nestjs/testing';
import { BadRequestException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { SwapService } from './swap.service';
import { Web3Service } from '../web3/web3.service';

describe('SwapService', () => {
  let service: SwapService;

  const mockRouter = {
    interface: {
      encodeFunctionData: jest.fn().mockReturnValue('0xSwapData'),
    },
    getAddress: jest.fn().mockResolvedValue('0xRouterAddr'),
    getReserves: jest.fn().mockResolvedValue([BigInt(100_000), BigInt(1_000_000)]),
    getQuote: jest.fn().mockResolvedValue(BigInt(9900)),
  };

  const mockWeb3Service = {
    getSwapRouter: jest.fn().mockReturnValue(mockRouter),
    buildUnsignedTx: jest.fn((to, data, value, gas) => ({
      to,
      data,
      value: value || '0',
      chainId: 102031,
      estimatedGas: gas || '300000',
    })),
  };

  const mockConfigService = {
    get: jest.fn((key: string, defaultValue?: unknown) => {
      const values: Record<string, unknown> = {
        CHAIN_ID: 102031,
        SWAP_ROUTER_ADDRESS: '0x3000000000000000000000000000000000000003',
        TEST_USDC_ADDRESS: '0x1000000000000000000000000000000000000001',
        TEST_USDT_ADDRESS: '0x2000000000000000000000000000000000000002',
      };
      return key in values ? values[key] : defaultValue;
    }),
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        SwapService,
        { provide: Web3Service, useValue: mockWeb3Service },
        { provide: ConfigService, useValue: mockConfigService },
      ],
    }).compile();

    service = module.get<SwapService>(SwapService);
  });

  afterEach(() => jest.clearAllMocks());

  describe('getQuote', () => {
    it('should expose router readiness status', () => {
      expect(service.getStatus()).toEqual({
        routerConfigured: true,
        routerAddress: '0x3000000000000000000000000000000000000003',
        nativeSymbol: 'tCTC',
        supportedTokens: [
          {
            symbol: 'USDC',
            address: '0x1000000000000000000000000000000000000001',
          },
          {
            symbol: 'USDT',
            address: '0x2000000000000000000000000000000000000002',
          },
        ],
      });
    });

    it('should return quote for CTC to token swap', async () => {
      const result = await service.getQuote('tCTC', 'USDC', '1.5');
      expect(result.amountInRaw).toBe('1500000000000000000');
      expect(result.estimatedOutput).toBe('0.0099');
      expect(result.priceImpactPct).toBeDefined();
      expect(mockRouter.getQuote).toHaveBeenCalledWith(
        '0x1000000000000000000000000000000000000001',
        BigInt('1500000000000000000'),
        true,
      );
    });

    it('should return quote for token to CTC swap', async () => {
      await service.getQuote('USDC', 'tCTC', '12.5');
      expect(mockRouter.getQuote).toHaveBeenCalledWith(
        '0x1000000000000000000000000000000000000001',
        BigInt('12500000'),
        false,
      );
    });

    it('should throw if no liquidity', async () => {
      mockRouter.getReserves.mockResolvedValueOnce([BigInt(0), BigInt(0)]);
      await expect(service.getQuote('tCTC', 'USDC', '1')).rejects.toThrow(
        BadRequestException,
      );
    });

    it('should throw for CTC to CTC', async () => {
      await expect(service.getQuote('CTC', 'tCTC', '1')).rejects.toThrow(
        BadRequestException,
      );
    });

    it('should throw for token to token (no CTC)', async () => {
      await expect(service.getQuote('USDC', 'USDT', '1')).rejects.toThrow(
        BadRequestException,
      );
    });
  });

  describe('buildSwapTx', () => {
    it('should build CTC-to-token swap TX with value', async () => {
      const result = await service.buildSwapTx(
        'tCTC',
        'USDC',
        '1000000000000000000',
        '900000',
      );
      expect(result.to).toBe('0xRouterAddr');
      expect(result.value).toBe('1000000000000000000');
      expect(mockRouter.interface.encodeFunctionData).toHaveBeenCalledWith(
        'swapCTCForToken',
        ['0x1000000000000000000000000000000000000001', '900000'],
      );
    });

    it('should build token-to-CTC swap TX with zero value', async () => {
      const result = await service.buildSwapTx(
        'USDC',
        'tCTC',
        '12500000',
        '990000000000000000',
      );
      expect(result.to).toBe('0xRouterAddr');
      expect(result.value).toBe('0');
      expect(mockRouter.interface.encodeFunctionData).toHaveBeenCalledWith(
        'swapTokenForCTC',
        [
          '0x1000000000000000000000000000000000000001',
          '12500000',
          '990000000000000000',
        ],
      );
    });

    it('should build token approval TX for token-to-CTC swaps', async () => {
      const result = await service.buildApprovalTx('USDC', '12500000');
      expect(result.to).toBe('0x1000000000000000000000000000000000000001');
      expect(result.value).toBe('0');
    });
  });

  describe('getReserves', () => {
    it('should return formatted reserves', async () => {
      const result = await service.getReserves('USDC');
      expect(result.ctcReserve).toBe('100000');
      expect(result.tokenReserve).toBe('1000000');
    });
  });

  describe('getSwapHistory', () => {
    it('should return empty array (placeholder)', async () => {
      const result = await service.getSwapHistory('0xUser');
      expect(result).toEqual([]);
    });
  });
});
