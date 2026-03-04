import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  OneToOne,
  JoinColumn,
} from 'typeorm';
import { Pool } from './pool.entity';

/**
 * Equb rules (type, frequency, payoutMethod, penalties, etc.).
 * Synced from on-chain getRules() or set via POST/PATCH when creator proposes changes.
 * On-chain rules are updated via EqubGovernor (P1); until then, PATCH updates DB only.
 */
@Entity('equb_rules')
export class EqubRulesEntity {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'uuid', unique: true })
  poolId: string;

  /** EqubType enum: 0=Finance, 1=House, 2=Car, 3=Travel, 4=Special, 5=Workplace, 6=Education, 7=Wedding, 8=Emergency */
  @Column({ type: 'smallint', default: 0 })
  equbType: number;

  /** Frequency enum: 0=Daily, 1=Weekly, 2=BiWeekly, 3=Monthly */
  @Column({ type: 'smallint', default: 1 })
  frequency: number;

  /** PayoutMethod enum: 0=Lottery, 1=Rotation, 2=Bid */
  @Column({ type: 'smallint', default: 0 })
  payoutMethod: number;

  @Column({ type: 'int', default: 604800 }) // 7 days in seconds
  gracePeriodSeconds: number;

  @Column({ type: 'int', default: 10 })
  penaltySeverity: number;

  @Column({ type: 'int', default: 2592000 }) // 30 days
  roundDurationSeconds: number;

  @Column({ type: 'int', default: 0 })
  lateFeePercent: number;

  @OneToOne(() => Pool, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'poolId' })
  pool: Pool;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
