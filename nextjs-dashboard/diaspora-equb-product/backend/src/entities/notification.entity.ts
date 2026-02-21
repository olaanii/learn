import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  Index,
} from 'typeorm';

export type NotificationType =
  | 'round_closed'
  | 'all_contributed'
  | 'payout_received'
  | 'contribution_confirmed'
  | 'default_triggered'
  | 'collateral_slashed'
  | 'pool_joined'
  | 'stream_frozen'
  | 'credit_updated'
  | 'system';

@Entity('notifications')
export class Notification {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Index()
  @Column()
  walletAddress: string;

  @Column({ type: 'varchar', length: 40 })
  type: NotificationType;

  @Column()
  title: string;

  @Column({ type: 'text' })
  body: string;

  @Column({ type: 'jsonb', nullable: true })
  metadata: Record<string, unknown> | null;

  @Column({ default: false })
  read: boolean;

  @CreateDateColumn()
  createdAt: Date;
}
