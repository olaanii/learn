import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Subject, Observable } from 'rxjs';
import {
  Notification,
  NotificationStatus,
  NotificationType,
} from '../entities/notification.entity';

export interface NotificationEvent {
  walletAddress: string;
  notification: Notification;
}

export interface NotificationCursor {
  createdAt: string;
  id: string;
}

export interface IncrementalNotificationsResult {
  items: Notification[];
  nextCursor: NotificationCursor | null;
  hasMore: boolean;
}

const IDEMPOTENCY_WINDOW_MS = 24 * 60 * 60 * 1000;
const TX_STATUS_VALUES = new Set<NotificationStatus>([
  'pending',
  'confirmed',
  'failed',
]);

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
    const normalizedWallet = this.normalizeWallet(walletAddress);
    const normalizedMetadata = this.normalizeMetadata(
      normalizedWallet,
      type,
      metadata,
    );
    const idempotencyKey = this.resolveIdempotencyKey(
      normalizedWallet,
      type,
      title,
      body,
      normalizedMetadata,
    );

    const existing = await this.findDuplicate(
      normalizedWallet,
      type,
      title,
      body,
      idempotencyKey,
    );
    if (existing) {
      this.logger.debug(
        `Deduped notification [${type}] for ${walletAddress} (key=${idempotencyKey})`,
      );
      return existing;
    }

    const notification = this.repo.create({
      walletAddress: normalizedWallet,
      type,
      title,
      body,
      metadata: {
        ...normalizedMetadata,
        idempotencyKey,
      },
    });

    const saved = await this.repo.save(notification);
    try {
      this.eventBus.next({ walletAddress: normalizedWallet, notification: saved });
    } catch (error) {
      this.logger.warn(
        `Failed to publish notification event [${type}] for ${normalizedWallet}: ${error}`,
      );
    }
    this.logger.debug(`Notification [${type}] for ${normalizedWallet}: ${title}`);
    return saved;
  }

  private async findDuplicate(
    walletAddress: string,
    type: NotificationType,
    _title: string,
    _body: string,
    idempotencyKey: string,
  ): Promise<Notification | null> {
    const recent = await this.repo.find({
      where: { walletAddress, type },
      order: { createdAt: 'DESC' },
      take: 100,
    });

    const cutoff = Date.now() - IDEMPOTENCY_WINDOW_MS;
    for (const candidate of recent) {
      if (candidate.createdAt.getTime() < cutoff) {
        return null;
      }
      const candidateKey = this.extractMetadataIdempotencyKey(
        candidate.metadata,
      );
      if (candidateKey != null && candidateKey === idempotencyKey) {
        return candidate;
      }
    }

    return null;
  }

  private resolveIdempotencyKey(
    walletAddress: string,
    type: NotificationType,
    title: string,
    body: string,
    metadata?: Record<string, unknown>,
  ): string {
    const explicit = this.extractMetadataIdempotencyKey(metadata ?? null);
    if (explicit) return explicit;

    const txHash = this.stringOrEmpty(metadata?.txHash);
    const poolId = this.stringOrEmpty(metadata?.poolId);
    const round = this.stringOrEmpty(metadata?.round);
    const amount = this.stringOrEmpty(metadata?.amount);
    const status = this.stringOrEmpty(metadata?.status);
    const kind = this.stringOrEmpty(metadata?.kind);

    return [
      'notif',
      walletAddress,
      type,
      txHash,
      poolId,
      round,
      amount,
      status,
      kind,
      title,
      body,
    ]
      .join('|')
      .toLowerCase();
  }

  private extractMetadataIdempotencyKey(
    metadata: Record<string, unknown> | null,
  ): string | null {
    if (!metadata) return null;
    const raw = metadata.idempotencyKey;
    if (typeof raw !== 'string') return null;
    const normalized = raw.trim().toLowerCase();
    return normalized.length === 0 ? null : normalized;
  }

  private stringOrEmpty(value: unknown): string {
    if (value == null) return '';
    return String(value).trim();
  }

  async findForWallet(
    walletAddress: string,
    limit = 50,
    offset = 0,
  ): Promise<Notification[]> {
    const normalizedWallet = this.normalizeWallet(walletAddress);
    return this.repo
      .createQueryBuilder('notification')
      .where('LOWER(notification.walletAddress) = :wallet', {
        wallet: normalizedWallet,
      })
      .orderBy('notification.createdAt', 'DESC')
      .take(limit)
      .skip(offset)
      .getMany();
  }

  async findForWalletIncremental(
    walletAddress: string,
    afterCreatedAt?: Date,
    afterId?: string,
    limit = 50,
  ): Promise<IncrementalNotificationsResult> {
    const normalizedWallet = this.normalizeWallet(walletAddress);
    const safeLimit = Math.max(1, Math.min(200, limit));

    const qb = this.repo
      .createQueryBuilder('notification')
      .where('LOWER(notification.walletAddress) = :wallet', {
        wallet: normalizedWallet,
      });

    if (afterCreatedAt) {
      qb.andWhere(
        '(notification.createdAt > :afterCreatedAt OR (notification.createdAt = :afterCreatedAt AND notification.id > :afterId))',
        {
          afterCreatedAt,
          afterId: (afterId ?? '').trim(),
        },
      );
    }

    const rows = await qb
      .orderBy('notification.createdAt', 'ASC')
      .addOrderBy('notification.id', 'ASC')
      .take(safeLimit + 1)
      .getMany();

    const hasMore = rows.length > safeLimit;
    const items = hasMore ? rows.slice(0, safeLimit) : rows;
    const last = items.at(-1);

    return {
      items,
      hasMore,
      nextCursor: last
        ? {
            createdAt: last.createdAt.toISOString(),
            id: last.id,
          }
        : null,
    };
  }

  async unreadCount(walletAddress: string): Promise<number> {
    const normalizedWallet = this.normalizeWallet(walletAddress);
    return this.repo
      .createQueryBuilder('notification')
      .where('LOWER(notification.walletAddress) = :wallet', {
        wallet: normalizedWallet,
      })
      .andWhere('notification.read = :read', { read: false })
      .getCount();
  }

  async markRead(id: string, walletAddress: string): Promise<void> {
    const normalizedWallet = this.normalizeWallet(walletAddress);
    await this.repo
      .createQueryBuilder()
      .update(Notification)
      .set({ read: true })
      .where('id = :id', { id })
      .andWhere('LOWER(walletAddress) = :wallet', { wallet: normalizedWallet })
      .execute();
  }

  async markAllRead(walletAddress: string): Promise<void> {
    const normalizedWallet = this.normalizeWallet(walletAddress);
    await this.repo
      .createQueryBuilder()
      .update(Notification)
      .set({ read: true })
      .where('LOWER(walletAddress) = :wallet', { wallet: normalizedWallet })
      .andWhere('read = :read', { read: false })
      .execute();
  }

  private normalizeWallet(walletAddress: string): string {
    return String(walletAddress || '').trim().toLowerCase();
  }

  private normalizeMetadata(
    walletAddress: string,
    type: NotificationType,
    metadata?: Record<string, unknown>,
  ): Record<string, unknown> {
    const status = this.resolveNotificationStatus(type, metadata);
    const kind = this.resolveNotificationKind(type, metadata);

    return {
      ...(metadata ?? {}),
      txHash: this.stringOrEmpty(metadata?.txHash).toLowerCase() || undefined,
      status,
      kind,
      walletAddress,
      notificationType: type,
    };
  }

  private resolveNotificationStatus(
    type: NotificationType,
    metadata?: Record<string, unknown>,
  ): NotificationStatus {
    const explicitRaw = metadata?.status;
    if (typeof explicitRaw === 'string') {
      const explicit = explicitRaw.trim().toLowerCase() as NotificationStatus;
      if (TX_STATUS_VALUES.has(explicit)) {
        return explicit;
      }
    }

    switch (type) {
      case 'transfer_built':
      case 'withdraw_built':
        return 'pending';
      default:
        return 'confirmed';
    }
  }

  private resolveNotificationKind(
    type: NotificationType,
    metadata?: Record<string, unknown>,
  ): 'transaction' | 'risk' | 'system' {
    const explicitRaw = metadata?.kind;
    if (
      explicitRaw === 'transaction' ||
      explicitRaw === 'risk' ||
      explicitRaw === 'system'
    ) {
      return explicitRaw;
    }

    switch (type) {
      case 'default_triggered':
      case 'collateral_slashed':
      case 'stream_frozen':
        return 'risk';
      case 'system':
        return 'system';
      default:
        return 'transaction';
    }
  }
}
