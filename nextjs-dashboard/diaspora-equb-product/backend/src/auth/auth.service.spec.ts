import { Test, TestingModule } from '@nestjs/testing';
import { JwtService } from '@nestjs/jwt';
import { getRepositoryToken } from '@nestjs/typeorm';
import { ConfigService } from '@nestjs/config';
import { AuthService } from './auth.service';
import { FaydaService } from './fayda.service';
import { FirebaseAdminService } from './firebase-admin.service';
import { Identity } from '../entities/identity.entity';
import { WalletChallenge } from '../entities/wallet-challenge.entity';

describe('AuthService', () => {
  let service: AuthService;
  let jwtService: JwtService;
  let identityRepo: any;

  const mockIdentityRepo = {
    findOne: jest.fn(),
    create: jest.fn(),
    save: jest.fn(),
  };

  const mockWalletChallengeRepo = {
    findOne: jest.fn(),
    create: jest.fn((dto) => dto),
    save: jest.fn(async (entity) => ({ ...entity, id: entity.id ?? 'challenge-id' })),
    delete: jest.fn(),
    createQueryBuilder: jest.fn().mockReturnValue({
      update: jest.fn().mockReturnThis(),
      set: jest.fn().mockReturnThis(),
      where: jest.fn().mockReturnThis(),
      andWhere: jest.fn().mockReturnThis(),
      execute: jest.fn().mockResolvedValue({ affected: 1 }),
    }),
  };

  const mockJwtService = {
    sign: jest.fn().mockReturnValue('mock-jwt-token'),
    verify: jest.fn(),
  };

  const mockFaydaService = {
    verify: jest.fn().mockResolvedValue({
      verified: true,
      identityHash: '0xabc',
    }),
    isRealIntegration: false,
  };

  const mockFirebaseAdminService = {
    isConfigured: true,
    verifyIdToken: jest.fn().mockResolvedValue({
      uid: 'firebase-uid',
      email: 'user@example.com',
      name: 'Test User',
      email_verified: true,
    }),
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        AuthService,
        { provide: JwtService, useValue: mockJwtService },
        { provide: ConfigService, useValue: { get: jest.fn() } },
        { provide: FaydaService, useValue: mockFaydaService },
        { provide: FirebaseAdminService, useValue: mockFirebaseAdminService },
        { provide: getRepositoryToken(Identity), useValue: mockIdentityRepo },
        {
          provide: getRepositoryToken(WalletChallenge),
          useValue: mockWalletChallengeRepo,
        },
      ],
    }).compile();

    service = module.get<AuthService>(AuthService);
    jwtService = module.get<JwtService>(JwtService);
    identityRepo = module.get(getRepositoryToken(Identity));
  });

  afterEach(() => jest.clearAllMocks());

  describe('verifyFayda', () => {
    it('should create a new identity and return JWT', async () => {
      mockIdentityRepo.findOne.mockResolvedValue(null);
      mockIdentityRepo.create.mockReturnValue({
        identityHash: '0xabc',
        bindingStatus: 'unbound',
      });
      mockIdentityRepo.save.mockResolvedValue({
        identityHash: '0xabc',
        bindingStatus: 'unbound',
        walletAddress: null,
      });

      const result = await service.verifyFayda('test-token');

      expect(result.accessToken).toBe('mock-jwt-token');
      expect(result.identityHash).toBe('0xabc');
      expect(result.walletBindingStatus).toBe('unbound');
      expect(result.faydaMode).toBe('mock');
      expect(mockJwtService.sign).toHaveBeenCalled();
      expect(mockFaydaService.verify).toHaveBeenCalledWith('test-token');
    });

    it('should return existing identity if found', async () => {
      const existingIdentity = {
        identityHash: '0xexisting',
        walletAddress: '0x1234',
        bindingStatus: 'bound',
      };
      mockIdentityRepo.findOne.mockResolvedValue(existingIdentity);

      const result = await service.verifyFayda('test-token');

      expect(result.accessToken).toBe('mock-jwt-token');
      expect(result.identityHash).toBe('0xabc');
      expect(result.walletBindingStatus).toBe('bound');
      expect(mockIdentityRepo.create).not.toHaveBeenCalled();
      expect(mockFaydaService.verify).toHaveBeenCalledWith('test-token');
    });
  });

  describe('walletChallenge', () => {
    it('should return a message and nonce', async () => {
      const result = await service.walletChallenge('0xWalletAddress');
      expect(result.message).toContain('Sign this message');
      expect(result.message).toContain('0xwalletaddress');
      expect(result.nonce).toBeDefined();
      expect(result.nonce.length).toBeGreaterThan(0);
      expect(mockWalletChallengeRepo.save).toHaveBeenCalled();
    });
  });

  describe('walletVerify', () => {
    it('should reject when no challenge exists', async () => {
      mockWalletChallengeRepo.findOne.mockResolvedValueOnce(null);
      await expect(
        service.walletVerify('0xUnknown', '0xSig', 'some message'),
      ).rejects.toThrow('No challenge found');
    });

    it('should reject expired challenge', async () => {
      mockWalletChallengeRepo.findOne.mockResolvedValueOnce({
        id: 'challenge-id',
        consumedAt: null,
        expiresAt: new Date(Date.now() - 1000),
        message: 'challenge',
      });

      await expect(
        service.walletVerify('0xWallet', '0xSig', 'challenge'),
      ).rejects.toThrow('Challenge expired');
    });

    it('should reject message mismatch', async () => {
      mockWalletChallengeRepo.findOne.mockResolvedValueOnce({
        id: 'challenge-id',
        consumedAt: null,
        expiresAt: new Date(Date.now() + 60_000),
        message: 'expected message',
      });

      await expect(
        service.walletVerify('0xWallet', '0xSig', 'wrong message'),
      ).rejects.toThrow('Challenge message mismatch');
    });
  });

  describe('devLogin', () => {
    it('should return JWT for dev wallet', async () => {
      mockIdentityRepo.findOne.mockResolvedValue(null);
      (identityRepo as any).createQueryBuilder = jest.fn().mockReturnValue({
        where: jest.fn().mockReturnThis(),
        getOne: jest.fn().mockResolvedValue(null),
      });
      mockIdentityRepo.create.mockReturnValue({
        identityHash: '0xdev',
        walletAddress: '0x0000000000000000000000000000000000de1057',
        bindingStatus: 'bound',
      });
      mockIdentityRepo.save.mockResolvedValue({
        identityHash: '0xdev',
        walletAddress: '0x0000000000000000000000000000000000de1057',
        bindingStatus: 'bound',
      });

      const result = await service.devLogin();
      expect(result.accessToken).toBe('mock-jwt-token');
      expect(result.walletBindingStatus).toBe('bound');
    });

    it('should reuse existing identity for dev wallet', async () => {
      (identityRepo as any).createQueryBuilder = jest.fn().mockReturnValue({
        where: jest.fn().mockReturnThis(),
        getOne: jest.fn().mockResolvedValue({
          identityHash: '0xexisting',
          walletAddress: '0x0000000000000000000000000000000000de1057',
          bindingStatus: 'bound',
        }),
      });

      const result = await service.devLogin();
      expect(result.accessToken).toBe('mock-jwt-token');
      expect(mockIdentityRepo.create).not.toHaveBeenCalled();
    });
  });

  describe('validateToken', () => {
    it('should return payload for valid token', async () => {
      mockJwtService.verify.mockReturnValue({ sub: '0xHash', walletAddress: '0x123' });
      const result = await service.validateToken('valid-token');
      expect(result.sub).toBe('0xHash');
    });

    it('should throw for invalid token', async () => {
      mockJwtService.verify.mockImplementation(() => {
        throw new Error('invalid');
      });
      await expect(service.validateToken('bad-token')).rejects.toThrow(
        'Invalid or expired token',
      );
    });
  });
});
