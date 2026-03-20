import { Test, TestingModule } from '@nestjs/testing';
import { TokenController } from './token.controller';
import { TokenService } from './token.service';

describe('TokenController', () => {
  let controller: TokenController;

  const mockTokenService = {
    getBalance: jest.fn(),
    getTransactions: jest.fn(),
    mintFaucetTokens: jest.fn(),
    buildTransfer: jest.fn(),
    buildWithdraw: jest.fn(),
    getRates: jest.fn(),
    getPortfolio: jest.fn(),
    getExchangeRates: jest.fn(),
    getSupportedTokens: jest.fn(),
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [TokenController],
      providers: [{ provide: TokenService, useValue: mockTokenService }],
    }).compile();

    controller = module.get<TokenController>(TokenController);
  });

  afterEach(() => jest.clearAllMocks());

  describe('getBalance', () => {
    it('should return balance for wallet and token', async () => {
      mockTokenService.getBalance.mockResolvedValue({
        balance: '100.0',
        symbol: 'USDC',
        decimals: 6,
      });

      const result = await controller.getBalance('0xWallet', 'USDC');
      expect(result.balance).toBe('100.0');
      expect(mockTokenService.getBalance).toHaveBeenCalledWith('0xWallet', 'USDC', undefined);
    });

    it('should default to USDC if no token specified', async () => {
      mockTokenService.getBalance.mockResolvedValue({ balance: '50.0', symbol: 'USDC' });
      await controller.getBalance('0xWallet', undefined);
      expect(mockTokenService.getBalance).toHaveBeenCalledWith('0xWallet', 'USDC', undefined);
    });
  });

  describe('getTransactions', () => {
    it('should pass filter params to service', async () => {
      mockTokenService.getTransactions.mockResolvedValue([]);
      await controller.getTransactions({
        walletAddress: '0xWallet',
        token: 'USDT',
        limit: 25,
        direction: 'sent',
      });
      expect(mockTokenService.getTransactions).toHaveBeenCalledWith(
        '0xWallet',
        'USDT',
        25,
        expect.objectContaining({ direction: 'sent' }),
      );
    });
  });

  describe('mintFaucet', () => {
    it('should call mintFaucetTokens', async () => {
      mockTokenService.mintFaucetTokens.mockResolvedValue({ txHash: '0xTx' });
      const result = await controller.mintFaucet({
        walletAddress: '0xUser',
        amount: 1000,
        token: 'USDC',
      });
      expect(result.txHash).toBe('0xTx');
    });
  });

  describe('buildTransfer', () => {
    it('should return unsigned transfer TX', async () => {
      const tx = { to: '0xToken', data: '0x', value: '0' };
      mockTokenService.buildTransfer.mockResolvedValue(tx);
      const result = await controller.buildTransfer({
        from: '0xSender',
        to: '0xRecipient',
        amount: '100',
        token: 'USDC',
      });
      expect(result).toEqual(tx);
    });
  });

  describe('getRates', () => {
    it('should return exchange rates', async () => {
      const rates = { CTC: { usd: 0.5 }, USDC: { usd: 1.0 }, USDT: { usd: 1.0 } };
      mockTokenService.getRates.mockResolvedValue(rates);
      const result = await controller.getRates();
      expect(result).toEqual(rates);
    });
  });

  describe('getPortfolio', () => {
    it('should return portfolio for wallet', async () => {
      const portfolio = [{ token: 'USDC', balance: '100', usdValue: 100 }];
      mockTokenService.getPortfolio.mockResolvedValue(portfolio);
      const result = await controller.getPortfolio({ wallet: '0xWallet' });
      expect(result).toEqual(portfolio);
    });
  });
});
