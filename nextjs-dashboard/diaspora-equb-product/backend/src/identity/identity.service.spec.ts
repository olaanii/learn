import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { ConflictException, NotFoundException } from '@nestjs/common';
import { IdentityService } from './identity.service';
import { Identity } from '../entities/identity.entity';
import { Web3Service } from '../web3/web3.service';
import { NotificationsService } from '../notifications/notifications.service';

describe('IdentityService', () => {
  let service: IdentityService;
  let identityRepo: any;

  const mockIdentityRegistry = {
    interface: {
      encodeFunctionData: jest.fn().mockReturnValue('0xBindData'),
    },
    getAddress: jest.fn().mockResolvedValue('0xIdentityRegistryAddr'),
  };

  const mockWeb3Service = {
    getIdentityRegistry: jest.fn().mockReturnValue(mockIdentityRegistry),
    buildUnsignedTx: jest.fn((to, data, value, gas) => ({
      to,
      data,
      value,
      chainId: 102031,
      estimatedGas: gas,
    })),
  };

  const mockNotifications = { create: jest.fn().mockResolvedValue({}) };

  const mockIdentityRepo = {
    findOne: jest.fn(),
    create: jest.fn((dto) => dto),
    save: jest.fn((entity) => Promise.resolve(entity)),
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        IdentityService,
        { provide: Web3Service, useValue: mockWeb3Service },
        { provide: NotificationsService, useValue: mockNotifications },
        { provide: getRepositoryToken(Identity), useValue: mockIdentityRepo },
      ],
    }).compile();

    service = module.get<IdentityService>(IdentityService);
    identityRepo = module.get(getRepositoryToken(Identity));
  });

  afterEach(() => jest.clearAllMocks());

  describe('bindWallet', () => {
    it('should bind wallet to existing identity', async () => {
      mockIdentityRepo.findOne
        .mockResolvedValueOnce(null) // no existing by wallet
        .mockResolvedValueOnce({
          identityHash: '0xHash',
          walletAddress: null,
          bindingStatus: 'unbound',
        });

      const result = await service.bindWallet('0xHash', '0xWallet');
      expect(result.status).toBe('bound');
      expect(result.walletAddress).toBe('0xWallet');
      expect(mockIdentityRepo.save).toHaveBeenCalled();
    });

    it('should throw ConflictException if wallet bound to different identity', async () => {
      mockIdentityRepo.findOne.mockResolvedValueOnce({
        identityHash: '0xOtherHash',
        walletAddress: '0xWallet',
      });

      await expect(
        service.bindWallet('0xHash', '0xWallet'),
      ).rejects.toThrow(ConflictException);
    });

    it('should throw NotFoundException if identity not found', async () => {
      mockIdentityRepo.findOne
        .mockResolvedValueOnce(null)
        .mockResolvedValueOnce(null);

      await expect(
        service.bindWallet('0xHash', '0xWallet'),
      ).rejects.toThrow(NotFoundException);
    });

    it('should throw ConflictException if identity bound to different wallet', async () => {
      mockIdentityRepo.findOne
        .mockResolvedValueOnce(null)
        .mockResolvedValueOnce({
          identityHash: '0xHash',
          walletAddress: '0xOtherWallet',
          bindingStatus: 'bound',
        });

      await expect(
        service.bindWallet('0xHash', '0xWallet'),
      ).rejects.toThrow(ConflictException);
    });

    it('should be idempotent when wallet already bound to same identity', async () => {
      mockIdentityRepo.findOne
        .mockResolvedValueOnce(null)
        .mockResolvedValueOnce({
          identityHash: '0xHash',
          walletAddress: '0xwallet',
          bindingStatus: 'bound',
        });

      const result = await service.bindWallet('0xHash', '0xWallet');
      expect(result.status).toBe('bound');
    });
  });

  describe('buildStoreOnChain', () => {
    it('should return unsigned TX for on-chain binding', async () => {
      mockIdentityRepo.findOne.mockResolvedValue({
        identityHash:
          '0x1111111111111111111111111111111111111111111111111111111111111111',
        walletAddress: '0xwallet',
      });

      const result = await service.buildStoreOnChain(
        '0x1111111111111111111111111111111111111111111111111111111111111111',
        '0xWallet',
      );
      expect(result.to).toBe('0xIdentityRegistryAddr');
      expect(result.data).toBe('0xBindData');
      expect(result.value).toBe('0');
    });

    it('should throw NotFoundException if identity not found', async () => {
      mockIdentityRepo.findOne.mockResolvedValue(null);
      await expect(
        service.buildStoreOnChain('0xHash', '0xWallet'),
      ).rejects.toThrow(NotFoundException);
    });

    it('should throw ConflictException if wallet mismatch', async () => {
      mockIdentityRepo.findOne.mockResolvedValue({
        identityHash: '0xHash',
        walletAddress: '0xOtherWallet',
      });
      await expect(
        service.buildStoreOnChain('0xHash', '0xWallet'),
      ).rejects.toThrow(ConflictException);
    });
  });
});
