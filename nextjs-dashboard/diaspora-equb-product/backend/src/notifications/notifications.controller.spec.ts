import { Subject, firstValueFrom } from 'rxjs';
import { describe, expect, it, jest } from '@jest/globals';
import { NotificationsController } from './notifications.controller';
import { Notification } from '../entities/notification.entity';

describe('NotificationsController', () => {
  it('filters SSE events by wallet case-insensitively', async () => {
    const bus = new Subject<{ walletAddress: string; notification: Notification }>();
    const mockService = {
      events$: bus.asObservable(),
      findForWallet: jest.fn(),
      findForWalletIncremental: jest.fn(),
      unreadCount: jest.fn(),
      markRead: jest.fn(),
      markAllRead: jest.fn(),
    } as any;

    const controller = new NotificationsController(mockService);

    const stream = controller.stream({
      user: { walletAddress: '0xAbC123' },
    });

    const firstEventPromise = firstValueFrom(stream);

    bus.next({
      walletAddress: '0xother',
      notification: {
        id: 'n-other',
        walletAddress: '0xother',
        type: 'system',
        title: 'Other',
        body: 'ignored',
        read: false,
        metadata: {},
        createdAt: new Date(),
        updatedAt: new Date(),
      } as Notification,
    });

    const matchingNotification = {
      id: 'n-match',
      walletAddress: '0xabc123',
      type: 'system',
      title: 'Mine',
      body: 'delivered',
      read: false,
      metadata: {},
      createdAt: new Date(),
      updatedAt: new Date(),
    } as Notification;

    bus.next({
      walletAddress: '0xabc123',
      notification: matchingNotification,
    });

    const event = await firstEventPromise;
    expect(event.data).toBe(matchingNotification);
  });
});
