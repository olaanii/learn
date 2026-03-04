import { Test, TestingModule } from '@nestjs/testing';
import { CollateralController } from './collateral.controller';
import { CollateralService } from './collateral.service';

describe('CollateralController', () => {
  let controller: CollateralController;

  const mockCollateralService = {
    buildDeposit: jest.fn(),
    buildRelease: jest.fn(),
    buildDepositToken: jest.fn(),
    confirmTokenDeposit: jest.fn(),
    releaseTokenCollateral: jest.fn(),
    getCollateral: jest.fn(),
    lock: jest.fn(),
    slash: jest.fn(),
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [CollateralController],
      providers: [{ provide: CollateralService, useValue: mockCollateralService }],
    }).compile();

    controller = module.get<CollateralController>(CollateralController);
  });

  afterEach(() => jest.clearAllMocks());

  describe('buildDeposit', () => {
    it('should return unsigned TX for native CTC deposit', async () => {
      const tx = { to: '0xVault', data: '0x', value: '1000' };
      mockCollateralService.buildDeposit.mockResolvedValue(tx);
      const result = await controller.buildDeposit({ amount: '1000' });
      expect(result).toEqual(tx);
      expect(mockCollateralService.buildDeposit).toHaveBeenCalledWith('1000');
    });
  });

  describe('buildRelease', () => {
    it('should return unsigned TX for release', async () => {
      const tx = { to: '0xVault', data: '0x', value: '0' };
      mockCollateralService.buildRelease.mockResolvedValue(tx);
      const result = await controller.buildRelease({ userAddress: '0xUser', amount: '500' });
      expect(result).toEqual(tx);
    });
  });

  describe('buildDepositToken', () => {
    it('should return unsigned TX for ERC-20 deposit', async () => {
      const tx = { to: '0xToken', data: '0x', value: '0', tokenAddress: '0xUSDC' };
      mockCollateralService.buildDepositToken.mockResolvedValue(tx);
      const result = await controller.buildDepositToken({ amount: '100', tokenSymbol: 'USDC' });
      expect(result).toEqual(tx);
    });
  });

  describe('confirmTokenDeposit', () => {
    it('should confirm token deposit', async () => {
      const response = { status: 'confirmed', walletAddress: '0xUser' };
      mockCollateralService.confirmTokenDeposit.mockResolvedValue(response);
      const result = await controller.confirmTokenDeposit({
        walletAddress: '0xUser',
        amount: '100',
        tokenSymbol: 'USDC',
        txHash: '0xTx',
      });
      expect(result.status).toBe('confirmed');
    });
  });

  describe('getCollateral', () => {
    it('should return collateral data for wallet', async () => {
      const data = [{ source: 'token', lockedAmount: '100' }];
      mockCollateralService.getCollateral.mockResolvedValue(data);
      const result = await controller.getCollateral('0xUser');
      expect(result).toEqual(data);
      expect(mockCollateralService.getCollateral).toHaveBeenCalledWith('0xUser');
    });
  });

  describe('lock', () => {
    it('should lock collateral', async () => {
      mockCollateralService.lock.mockResolvedValue({ status: 'locked' });
      const result = await controller.lock({
        walletAddress: '0xUser',
        amount: '500',
      });
      expect(result.status).toBe('locked');
    });
  });

  describe('slash', () => {
    it('should slash collateral', async () => {
      mockCollateralService.slash.mockResolvedValue({ status: 'slashed', amount: '200' });
      const result = await controller.slash({
        walletAddress: '0xUser',
        amount: '200',
      });
      expect(result.status).toBe('slashed');
    });
  });
});
