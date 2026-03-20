import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { ConfigService } from '@nestjs/config';
import { BadRequestException, NotFoundException } from '@nestjs/common';
import { CollateralService } from './collateral.service';
import { Collateral } from '../entities/collateral.entity';
import { Web3Service } from '../web3/web3.service';
import { NotificationsService } from '../notifications/notifications.service';

describe('CollateralService', () => {
  let service: CollateralService;
  let collateralRepo: any;

  const mockCollateralVault = {
    interface: {
      encodeFunctionData: jest.fn().mockReturnValue('0xencoded'),
    },
    getAddress: jest.fn().mockResolvedValue('0xVaultAddress'),
    collateralOf: jest.fn().mockResolvedValue(BigInt(1000)),
    lockedOf: jest.fn().mockResolvedValue(BigInt(500)),
  };

  const mockWeb3Service = {
    getCollateralVault: jest.fn().mockReturnValue(mockCollateralVault),
    getProvider: jest.fn().mockReturnValue({}),
    getDeployerSigner: jest.fn().mockReturnValue({
      address: '0x3000000000000000000000000000000000000003',
    }),
    buildUnsignedTx: jest.fn((to, data, value, gas) => ({
      to,
      data,
      value,
      chainId: 102031,
      estimatedGas: gas || '100000',
    })),
  };

  const mockConfigService = {
    get: jest.fn((key: string, defaultVal?: string) => {
      if (key === 'TEST_USDC_ADDRESS') return '0x1000000000000000000000000000000000000001';
      if (key === 'TEST_USDT_ADDRESS') return '0x2000000000000000000000000000000000000002';
      return defaultVal;
    }),
  };

  const mockNotifications = { create: jest.fn().mockResolvedValue({}) };

  const mockCollateralRepo = {
    findOne: jest.fn(),
    find: jest.fn(),
    create: jest.fn((dto) => dto),
    save: jest.fn((entity) => Promise.resolve(entity)),
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        CollateralService,
        { provide: Web3Service, useValue: mockWeb3Service },
        { provide: ConfigService, useValue: mockConfigService },
        { provide: NotificationsService, useValue: mockNotifications },
        { provide: getRepositoryToken(Collateral), useValue: mockCollateralRepo },
      ],
    }).compile();

    service = module.get<CollateralService>(CollateralService);
    collateralRepo = module.get(getRepositoryToken(Collateral));
  });

  afterEach(() => jest.clearAllMocks());

  describe('buildDeposit', () => {
    it('should return unsigned TX for native CTC deposit', async () => {
      const result = await service.buildDeposit('1000000000000000000');
      expect(result.to).toBe('0xVaultAddress');
      expect(result.data).toBe('0xencoded');
      expect(result.value).toBe('1000000000000000000');
      expect(mockCollateralVault.interface.encodeFunctionData).toHaveBeenCalledWith('depositCollateral');
    });
  });

  describe('buildRelease', () => {
    it('should return unsigned TX for release', async () => {
      const result = await service.buildRelease('0xUser', '500');
      expect(result.to).toBe('0xVaultAddress');
      expect(result.value).toBe('0');
      expect(mockCollateralVault.interface.encodeFunctionData).toHaveBeenCalledWith(
        'releaseCollateral',
        ['0xUser', '500'],
      );
    });
  });

  describe('buildDepositToken', () => {
    it('should return unsigned TX for ERC-20 token deposit', async () => {
      jest.spyOn(service as any, 'getTokenDecimals').mockResolvedValue(6);

      const result = await service.buildDepositToken('100', 'USDC');
      expect(result.to).toBe('0x1000000000000000000000000000000000000001');
      expect(result.tokenAddress).toBe('0x1000000000000000000000000000000000000001');
    });
  });

  describe('confirmTokenDeposit', () => {
    it('should create new collateral record if none exists', async () => {
      mockCollateralRepo.findOne.mockResolvedValue(null);
      const result = await service.confirmTokenDeposit('0xUser', '100', 'USDC', '0xTxHash');
      expect(result.status).toBe('confirmed');
      expect(result.walletAddress).toBe('0xUser');
      expect(mockCollateralRepo.save).toHaveBeenCalled();
    });

    it('should add to existing locked amount', async () => {
      const existing = {
        walletAddress: '0xUser',
        lockedAmount: '50',
        slashedAmount: '0',
        availableBalance: '0',
      };
      mockCollateralRepo.findOne.mockResolvedValue(existing);
      const result = await service.confirmTokenDeposit('0xUser', '100', 'USDC', '0xTx');
      expect(result.lockedAmount).toBe('150');
    });
  });

  describe('releaseTokenCollateral', () => {
    it('should throw NotFoundException if no collateral exists', async () => {
      mockCollateralRepo.findOne.mockResolvedValue(null);
      jest.spyOn(service as any, 'getTokenDecimals').mockResolvedValue(6);
      await expect(
        service.releaseTokenCollateral('0xUser', '100', 'USDC'),
      ).rejects.toThrow(NotFoundException);
    });

    it('should throw BadRequestException if release exceeds locked', async () => {
      mockCollateralRepo.findOne.mockResolvedValue({
        walletAddress: '0xUser',
        lockedAmount: '50',
        availableBalance: '0',
      });
      jest.spyOn(service as any, 'getTokenDecimals').mockResolvedValue(6);
      await expect(
        service.releaseTokenCollateral('0xUser', '100', 'USDC'),
      ).rejects.toThrow(BadRequestException);
    });
  });

  describe('getCollateral', () => {
    it('should merge DB and on-chain collateral', async () => {
      mockCollateralRepo.find.mockResolvedValue([
        {
          walletAddress: '0xUser',
          lockedAmount: '100',
          availableBalance: '50',
          slashedAmount: '0',
          poolId: null,
        },
      ]);

      const results = await service.getCollateral('0xUser');
      expect(results.length).toBe(2);
      expect(results[0].source).toBe('token');
      expect(results[1].source).toBe('on-chain-ctc');
    });

    it('should return empty array if no collateral found', async () => {
      mockCollateralRepo.find.mockResolvedValue([]);
      mockCollateralVault.collateralOf.mockResolvedValue(BigInt(0));
      mockCollateralVault.lockedOf.mockResolvedValue(BigInt(0));

      const results = await service.getCollateral('0xUser');
      expect(results).toEqual([]);
    });
  });

  describe('lock', () => {
    it('should create new collateral and lock amount', async () => {
      mockCollateralRepo.findOne.mockResolvedValue(null);
      const result = await service.lock('0xUser', '500');
      expect(result.status).toBe('locked');
      expect(result.lockedAmount).toBe('500');
    });

    it('should add to existing locked amount', async () => {
      mockCollateralRepo.findOne.mockResolvedValue({
        walletAddress: '0xUser',
        lockedAmount: '200',
        slashedAmount: '0',
        availableBalance: '0',
      });
      const result = await service.lock('0xUser', '300');
      expect(result.lockedAmount).toBe('500');
    });
  });

  describe('slash', () => {
    it('should slash from locked amount', async () => {
      mockCollateralRepo.findOne.mockResolvedValue({
        walletAddress: '0xUser',
        lockedAmount: '500',
        slashedAmount: '100',
        availableBalance: '0',
      });
      const result = await service.slash('0xUser', '200');
      expect(result.amount).toBe('200');
      expect(result.remainingLocked).toBe('300');
    });

    it('should cap slash at locked amount', async () => {
      mockCollateralRepo.findOne.mockResolvedValue({
        walletAddress: '0xUser',
        lockedAmount: '100',
        slashedAmount: '0',
        availableBalance: '0',
      });
      const result = await service.slash('0xUser', '500');
      expect(result.amount).toBe('100');
      expect(result.remainingLocked).toBe('0');
    });

    it('should throw NotFoundException if no collateral', async () => {
      mockCollateralRepo.findOne.mockResolvedValue(null);
      await expect(service.slash('0xUser', '100')).rejects.toThrow(NotFoundException);
    });
  });
});
