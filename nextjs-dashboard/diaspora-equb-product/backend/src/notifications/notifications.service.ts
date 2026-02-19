import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Subject, Observable } from 'rxjs';
import {
  Notification,
  NotificationType,
} from '../entities/notification.entity';

export interface NotificationEvent {
  walletAddress: string;
  notification: Notification;
}

@Injectable()
export class NotificationsService {
  private readonly logger = new Logger(NotificationsService.name);
  private readonly eventBus = new Subject<NotificationEvent>();

  constructor(
    @InjectRepository(Notification)
    private readonly repo: Repository<Notification>,
  ) {}

  get events$(): Observable<NotificationEvent> {
    return this.eventBus.asObservable();
  }

  async create(
    walletAddress: string,
    type: NotificationType,
    title: string,
    body: string,
    metadata?: Record<string, unknown>,
  ): Promise<Notification> {
    const notification = this.repo.create({
      walletAddress,
      type,
      title,
      body,
      metadata: metadata ?? null,
    });

    const saved = await this.repo.save(notification);
    this.eventBus.next({ walletAddress, notification: saved });
    this.logger.debug(`Notification [${type}] for ${walletAddress}: ${title}`);
    return saved;
  }

  async findForWallet(
    walletAddress: string,
    limit = 50,
    offset = 0,
  ): Promise<Notification[]> {
    return this.repo.find({
      where: { walletAddress },
      order: { createdAt: 'DESC' },
      take: limit,
      skip: offset,
    });
  }

  async unreadCount(walletAddress: string): Promise<number> {
    return this.repo.count({
      where: { walletAddress, read: false },
    });
  }

  async markRead(id: string, walletAddress: string): Promise<void> {
    await this.repo.update({ id, walletAddress }, { read: true });
  }

  async markAllRead(walletAddress: string): Promise<void> {
    await this.repo.update(
      { walletAddress, read: false },
      { read: true },
    );
  }
}
