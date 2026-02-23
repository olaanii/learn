import { HttpException, HttpStatus } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { PoolsController } from '../src/pools/pools.controller';
import { PoolsService } from '../src/pools/pools.service';

describe('Pools Phase 1 contract (e2e)', () => {
  let controller: PoolsController;

  const mockPoolsService = {
    closeActiveRound: jest.fn(),
    pickWinnerForActiveRound: jest.fn(),
    createNextSeason: jest.fn(),
    buildSelectWinner: jest.fn(),
    buildCreatePool: jest.fn(),
    createPoolFromCreationTx: jest.fn(),
    buildJoinPool: jest.fn(),
    buildContribute: jest.fn(),
    buildApproveToken: jest.fn(),
    buildCloseRound: jest.fn(),
    buildScheduleStream: jest.fn(),
    getPool: jest.fn(),
    getPoolToken: jest.fn(),
    listPools: jest.fn(),
    createPool: jest.fn(),
    joinPool: jest.fn(),
    recordContribution: jest.fn(),
    closeRound: jest.fn(),
    scheduleStream: jest.fn(),
  };

  beforeEach(async () => {
    const moduleRef: TestingModule = await Test.createTestingModule({
      controllers: [PoolsController],
      providers: [
        {
          provide: PoolsService,
          useValue: mockPoolsService,
        },
      ],
    }).compile();
    controller = moduleRef.get<PoolsController>(PoolsController);
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  it('closeActiveRound returns ROUND_NOT_OPEN envelope', async () => {
    mockPoolsService.closeActiveRound.mockRejectedValueOnce(
      new HttpException(
        { code: 'ROUND_NOT_OPEN', message: 'Active round is not open.' },
        HttpStatus.CONFLICT,
      ),
    );

    await expect(
      controller.closeActiveRound('pool-1', {
        user: { walletAddress: '0x1111111111111111111111111111111111111111' },
      }),
    ).rejects.toMatchObject({
      response: {
        code: 'ROUND_NOT_OPEN',
        message: 'Active round is not open.',
      },
      status: HttpStatus.CONFLICT,
    });
  });

  it('closeActiveRound returns SEASON_COMPLETE envelope', async () => {
    mockPoolsService.closeActiveRound.mockRejectedValueOnce(
      new HttpException(
        {
          code: 'SEASON_COMPLETE',
          message: 'Season is completed. Configure next season to continue.',
        },
        HttpStatus.CONFLICT,
      ),
    );

    await expect(
      controller.closeActiveRound('pool-1', {
        user: { walletAddress: '0x1111111111111111111111111111111111111111' },
      }),
    ).rejects.toMatchObject({
      response: {
        code: 'SEASON_COMPLETE',
        message: 'Season is completed. Configure next season to continue.',
      },
      status: HttpStatus.CONFLICT,
    });
  });

  it('closeActiveRound returns NOT_POOL_ADMIN envelope', async () => {
    mockPoolsService.closeActiveRound.mockRejectedValueOnce(
      new HttpException(
        {
          code: 'NOT_POOL_ADMIN',
          message: 'Only pool admin can perform this action.',
        },
        HttpStatus.FORBIDDEN,
      ),
    );

    await expect(
      controller.closeActiveRound('pool-1', {
        user: { walletAddress: '0x2222222222222222222222222222222222222222' },
      }),
    ).rejects.toMatchObject({
      response: {
        code: 'NOT_POOL_ADMIN',
        message: 'Only pool admin can perform this action.',
      },
      status: HttpStatus.FORBIDDEN,
    });
  });

  it('pickWinnerForActiveRound returns WINNER_BEFORE_CLOSE envelope', async () => {
    mockPoolsService.pickWinnerForActiveRound.mockRejectedValueOnce(
      new HttpException(
        {
          code: 'WINNER_BEFORE_CLOSE',
          message: 'Close the active round before picking winner.',
        },
        HttpStatus.CONFLICT,
      ),
    );

    await expect(
      controller.pickWinnerForActiveRound(
        'pool-1',
        { mode: 'auto' },
        'idem-1',
        { user: { walletAddress: '0x1111111111111111111111111111111111111111' } },
      ),
    ).rejects.toMatchObject({
      response: {
        code: 'WINNER_BEFORE_CLOSE',
        message: 'Close the active round before picking winner.',
      },
      status: HttpStatus.CONFLICT,
    });
  });

  it('pickWinnerForActiveRound returns IDEMPOTENCY_REPLAY_CONFLICT envelope', async () => {
    mockPoolsService.pickWinnerForActiveRound.mockRejectedValueOnce(
      new HttpException(
        {
          code: 'IDEMPOTENCY_REPLAY_CONFLICT',
          message: 'Idempotency key already used with a different payload.',
        },
        HttpStatus.CONFLICT,
      ),
    );

    await expect(
      controller.pickWinnerForActiveRound(
        'pool-1',
        { mode: 'auto' },
        'idem-1',
        { user: { walletAddress: '0x1111111111111111111111111111111111111111' } },
      ),
    ).rejects.toMatchObject({
      response: {
        code: 'IDEMPOTENCY_REPLAY_CONFLICT',
        message: 'Idempotency key already used with a different payload.',
      },
      status: HttpStatus.CONFLICT,
    });
  });

  it('pickWinnerForActiveRound returns ROUND_ALREADY_PICKED envelope', async () => {
    mockPoolsService.pickWinnerForActiveRound.mockRejectedValueOnce(
      new HttpException(
        {
          code: 'ROUND_ALREADY_PICKED',
          message: 'Winner is already picked for the active round.',
        },
        HttpStatus.CONFLICT,
      ),
    );

    await expect(
      controller.pickWinnerForActiveRound(
        'pool-1',
        { mode: 'auto' },
        'idem-1',
        { user: { walletAddress: '0x1111111111111111111111111111111111111111' } },
      ),
    ).rejects.toMatchObject({
      response: {
        code: 'ROUND_ALREADY_PICKED',
        message: 'Winner is already picked for the active round.',
      },
      status: HttpStatus.CONFLICT,
    });
  });

  it('pickWinnerForActiveRound returns SEASON_COMPLETE envelope', async () => {
    mockPoolsService.pickWinnerForActiveRound.mockRejectedValueOnce(
      new HttpException(
        {
          code: 'SEASON_COMPLETE',
          message: 'Season is completed. Configure next season to continue.',
        },
        HttpStatus.CONFLICT,
      ),
    );

    await expect(
      controller.pickWinnerForActiveRound(
        'pool-1',
        { mode: 'auto' },
        'idem-1',
        { user: { walletAddress: '0x1111111111111111111111111111111111111111' } },
      ),
    ).rejects.toMatchObject({
      response: {
        code: 'SEASON_COMPLETE',
        message: 'Season is completed. Configure next season to continue.',
      },
      status: HttpStatus.CONFLICT,
    });
  });

  it('pickWinnerForActiveRound returns NOT_POOL_ADMIN envelope', async () => {
    mockPoolsService.pickWinnerForActiveRound.mockRejectedValueOnce(
      new HttpException(
        {
          code: 'NOT_POOL_ADMIN',
          message: 'Only pool admin can perform this action.',
        },
        HttpStatus.FORBIDDEN,
      ),
    );

    await expect(
      controller.pickWinnerForActiveRound(
        'pool-1',
        { mode: 'auto' },
        'idem-1',
        { user: { walletAddress: '0x2222222222222222222222222222222222222222' } },
      ),
    ).rejects.toMatchObject({
      response: {
        code: 'NOT_POOL_ADMIN',
        message: 'Only pool admin can perform this action.',
      },
      status: HttpStatus.FORBIDDEN,
    });
  });
});