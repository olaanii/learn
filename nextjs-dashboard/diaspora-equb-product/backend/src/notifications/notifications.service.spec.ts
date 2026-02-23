import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import {
  afterEach,
  beforeEach,
  describe,
  expect,
  it,
  jest,
} from '@jest/globals';
import { NotificationsService } from './notifications.service';
import { Notification } from '../entities/notification.entity';

describe('NotificationsService', () => {
  let service: NotificationsService;
  let saveCounter = 0;

  const mockRepo: any = {
    create: jest.fn(),
    save: jest.fn(),
    find: jest.fn(),
    count: jest.fn(),
    update: jest.fn(),
    createQueryBuilder: jest.fn(),
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        NotificationsService,
        { provide: getRepositoryToken(Notification), useValue: mockRepo },
      ],
    }).compile();

    service = module.get<NotificationsService>(NotificationsService);
  });

  afterEach(() => {
    jest.clearAllMocks();
    saveCounter = 0;
  });

  it('dedupes when same idempotency key already exists in recent notifications', async () => {
    const existing = {
      id: 'n1',
      walletAddress: '0xabc',
      type: 'pool_joined',
      title: 'Joined Pool',
      body: 'Joined',
      read: false,
      metadata: { idempotencyKey: 'pool_joined:123' },
      createdAt: new Date(),
    } as Notification;

    mockRepo.find.mockResolvedValue([existing]);

    const result = await service.create(
      '0xabc',
      'pool_joined',
      'Joined Pool',
      'Joined',
      { idempotencyKey: 'pool_joined:123' },
    );

    expect(result).toBe(existing);
    expect(mockRepo.create).not.toHaveBeenCalled();
    expect(mockRepo.save).not.toHaveBeenCalled();
  });

  it('creates notification and emits event when no duplicate exists', async () => {
    mockRepo.find.mockResolvedValue([]);
    mockRepo.create.mockImplementation((payload: unknown) => payload);
    mockRepo.save.mockImplementation(async (payload: any) => ({
      id: `new-id-${++saveCounter}`,
      read: false,
      createdAt: new Date(),
      ...payload,
    }));

    const events: Array<{ walletAddress: string; notification: Notification }> =
      [];
    const sub = service.events$.subscribe((event) => events.push(event));

    const result = await service.create(
      '0xabc',
      'contribution_confirmed',
      'Contribution Confirmed',
      'Round 1 confirmed',
      { txHash: '0xtxhash', poolId: 'pool-1', round: 1 },
    );

    expect(mockRepo.create).toHaveBeenCalledTimes(1);
    expect(result.metadata).toMatchObject({
      txHash: '0xtxhash',
      poolId: 'pool-1',
      round: 1,
    });
    expect(typeof (result.metadata as Record<string, unknown>).idempotencyKey).toBe(
      'string',
    );
    expect(events).toHaveLength(1);
    expect(events[0].walletAddress).toBe('0xabc');

    sub.unsubscribe();
  });

  it('dedupes idempotency key case-insensitively', async () => {
    const existing = {
      id: 'n2',
      walletAddress: '0xabc',
      type: 'pool_joined',
      title: 'Joined Pool',
      body: 'Joined',
      read: false,
      metadata: { idempotencyKey: 'pool_joined:abc:123' },
      createdAt: new Date(),
    } as Notification;

    mockRepo.find.mockResolvedValue([existing]);

    const result = await service.create(
      '0xabc',
      'pool_joined',
      'Joined Pool',
      'Joined',
      { idempotencyKey: 'POOL_JOINED:ABC:123' },
    );

    expect(result).toBe(existing);
    expect(mockRepo.save).not.toHaveBeenCalled();
  });

  it('emits events in creation order during burst', async () => {
    mockRepo.find.mockResolvedValue([]);
    mockRepo.create.mockImplementation((payload: unknown) => payload);
    mockRepo.save.mockImplementation(async (payload: any) => ({
      id: `burst-${++saveCounter}`,
      read: false,
      createdAt: new Date(Date.now() + saveCounter),
      ...payload,
    }));

    const events: Array<{ walletAddress: string; notification: Notification }> =
      [];
    const sub = service.events$.subscribe((event) => events.push(event));

    await service.create('0xabc', 'system', 'A', 'first', {
      idempotencyKey: 'burst:a',
    });
    await service.create('0xabc', 'system', 'B', 'second', {
      idempotencyKey: 'burst:b',
    });
    await service.create('0xabc', 'system', 'C', 'third', {
      idempotencyKey: 'burst:c',
    });

    expect(events).toHaveLength(3);
    expect(events.map((e) => e.notification.title)).toEqual(['A', 'B', 'C']);
    sub.unsubscribe();
  });

  it('returns incremental page with deterministic cursor and hasMore flag', async () => {
    const rows = [
      {
        id: 'a',
        walletAddress: '0xabc',
        type: 'system',
        title: '1',
        body: '1',
        read: false,
        metadata: {},
        createdAt: new Date('2026-02-22T10:00:00.000Z'),
      },
      {
        id: 'b',
        walletAddress: '0xabc',
        type: 'system',
        title: '2',
        body: '2',
        read: false,
        metadata: {},
        createdAt: new Date('2026-02-22T10:00:01.000Z'),
      },
      {
        id: 'c',
        walletAddress: '0xabc',
        type: 'system',
        title: '3',
        body: '3',
        read: false,
        metadata: {},
        createdAt: new Date('2026-02-22T10:00:02.000Z'),
      },
    ] as Notification[];

    const qb: any = {
      where: jest.fn().mockReturnThis(),
      andWhere: jest.fn().mockReturnThis(),
      orderBy: jest.fn().mockReturnThis(),
      addOrderBy: jest.fn().mockReturnThis(),
      take: jest.fn().mockReturnThis(),
      getMany: jest.fn().mockImplementation(async () => rows as any),
    };
    mockRepo.createQueryBuilder.mockReturnValue(qb);

    const result = await service.findForWalletIncremental(
      '0xABC',
      new Date('2026-02-22T09:59:00.000Z'),
      'z',
      2,
    );

    expect(qb.orderBy).toHaveBeenCalledWith('notification.createdAt', 'ASC');
    expect(qb.addOrderBy).toHaveBeenCalledWith('notification.id', 'ASC');
    expect(result.items).toHaveLength(2);
    expect(result.hasMore).toBe(true);
    expect(result.nextCursor).toEqual({
      createdAt: '2026-02-22T10:00:01.000Z',
      id: 'b',
    });
  });

  it('normalizes wallet casing for list and unread ownership lookups', async () => {
    const listQb: any = {
      where: jest.fn().mockReturnThis(),
      orderBy: jest.fn().mockReturnThis(),
      take: jest.fn().mockReturnThis(),
      skip: jest.fn().mockReturnThis(),
      getMany: jest.fn().mockImplementation(async () => [] as any),
    };
    const unreadQb: any = {
      where: jest.fn().mockReturnThis(),
      andWhere: jest.fn().mockReturnThis(),
      getCount: jest.fn().mockImplementation(async () => 3 as any),
    };
    mockRepo.createQueryBuilder
      .mockReturnValueOnce(listQb)
      .mockReturnValueOnce(unreadQb);

    await service.findForWallet(' 0xAbCDef ', 25, 5);
    await service.unreadCount('0xABCDEF');

    expect(listQb.where).toHaveBeenCalledWith(
      'LOWER(notification.walletAddress) = :wallet',
      { wallet: '0xabcdef' },
    );
    expect(unreadQb.where).toHaveBeenCalledWith(
      'LOWER(notification.walletAddress) = :wallet',
      { wallet: '0xabcdef' },
    );
    expect(unreadQb.andWhere).toHaveBeenCalledWith(
      'notification.read = :read',
      { read: false },
    );
  });

  it('normalizes wallet casing in markRead and markAllRead updates', async () => {
    const execute = jest
      .fn()
      .mockImplementation(async () => ({ affected: 1 }) as any);
    const markReadQb: any = {
      update: jest.fn().mockReturnThis(),
      set: jest.fn().mockReturnThis(),
      where: jest.fn().mockReturnThis(),
      andWhere: jest.fn().mockReturnThis(),
      execute,
    };
    const markAllQb: any = {
      update: jest.fn().mockReturnThis(),
      set: jest.fn().mockReturnThis(),
      where: jest.fn().mockReturnThis(),
      andWhere: jest.fn().mockReturnThis(),
      execute,
    };
    mockRepo.createQueryBuilder
      .mockReturnValueOnce(markReadQb)
      .mockReturnValueOnce(markAllQb);

    await service.markRead('notif-1', ' 0xABCdef ');
    await service.markAllRead('0xAbCdEf');

    expect(markReadQb.andWhere).toHaveBeenCalledWith(
      'LOWER(walletAddress) = :wallet',
      { wallet: '0xabcdef' },
    );
    expect(markAllQb.where).toHaveBeenCalledWith(
      'LOWER(walletAddress) = :wallet',
      { wallet: '0xabcdef' },
    );
    expect(markAllQb.andWhere).toHaveBeenCalledWith('read = :read', {
      read: false,
    });
  });
});
