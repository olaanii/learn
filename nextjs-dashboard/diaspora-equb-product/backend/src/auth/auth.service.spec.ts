import { Test, TestingModule } from '@nestjs/testing';
import { JwtService } from '@nestjs/jwt';
import { getRepositoryToken } from '@nestjs/typeorm';
import { ConfigService } from '@nestjs/config';
import { AuthService } from './auth.service';
import { Identity } from '../entities/identity.entity';

describe('AuthService', () => {
  let service: AuthService;
  let jwtService: JwtService;
  let identityRepo: any;

  const mockIdentityRepo = {
    findOne: jest.fn(),
    create: jest.fn(),
    save: jest.fn(),
  };

  const mockJwtService = {
    sign: jest.fn().mockReturnValue('mock-jwt-token'),
    verify: jest.fn(),
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        AuthService,
        { provide: JwtService, useValue: mockJwtService },
        { provide: ConfigService, useValue: { get: jest.fn() } },
        { provide: getRepositoryToken(Identity), useValue: mockIdentityRepo },
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
      expect(result.identityHash).toMatch(/^0x[a-f0-9]{64}$/);
      expect(result.walletBindingStatus).toBe('unbound');
      expect(mockJwtService.sign).toHaveBeenCalled();
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
      expect(result.walletBindingStatus).toBe('bound');
      expect(mockIdentityRepo.create).not.toHaveBeenCalled();
    });
  });
});
