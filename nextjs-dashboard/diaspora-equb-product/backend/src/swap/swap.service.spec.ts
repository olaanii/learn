import { Test, TestingModule } from '@nestjs/testing';
import { BadRequestException } from '@nestjs/common';
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

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        SwapService,
        { provide: Web3Service, useValue: mockWeb3Service },
      ],
    }).compile();

    service = module.get<SwapService>(SwapService);
  });

  afterEach(() => jest.clearAllMocks());

  describe('getQuote', () => {
    it('should return quote for CTC to token swap', async () => {
      const result = await service.getQuote('CTC', '0xToken', '10000');
      expect(result.estimatedOutput).toBe('9900');
      expect(result.fee).toBeDefined();
      expect(mockRouter.getQuote).toHaveBeenCalledWith('0xToken', BigInt(10000), true);
    });

    it('should return quote for token to CTC swap', async () => {
      await service.getQuote('0xToken', 'CTC', '10000');
      expect(mockRouter.getQuote).toHaveBeenCalledWith('0xToken', BigInt(10000), false);
    });

    it('should throw if no liquidity', async () => {
      mockRouter.getReserves.mockResolvedValueOnce([BigInt(0), BigInt(0)]);
      await expect(service.getQuote('CTC', '0xToken', '10000')).rejects.toThrow(
        BadRequestException,
      );
    });

    it('should throw for CTC to CTC', async () => {
      await expect(service.getQuote('CTC', 'CTC', '10000')).rejects.toThrow(
        BadRequestException,
      );
    });

    it('should throw for token to token (no CTC)', async () => {
      await expect(
        service.getQuote('0xTokenA', '0xTokenB', '10000'),
      ).rejects.toThrow(BadRequestException);
    });
  });

  describe('buildSwapTx', () => {
    it('should build CTC-to-token swap TX with value', async () => {
      const result = await service.buildSwapTx('CTC', '0xToken', '10000', '9000');
      expect(result.to).toBe('0xRouterAddr');
      expect(result.value).toBe('10000');
      expect(mockRouter.interface.encodeFunctionData).toHaveBeenCalledWith(
        'swapCTCForToken',
        ['0xToken', '9000'],
      );
    });

    it('should build token-to-CTC swap TX with zero value', async () => {
      const result = await service.buildSwapTx('0xToken', 'CTC', '10000', '9000');
      expect(result.to).toBe('0xRouterAddr');
      expect(result.value).toBe('0');
      expect(mockRouter.interface.encodeFunctionData).toHaveBeenCalledWith(
        'swapTokenForCTC',
        ['0xToken', '10000', '9000'],
      );
    });
  });

  describe('getReserves', () => {
    it('should return formatted reserves', async () => {
      const result = await service.getReserves('0xToken');
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
