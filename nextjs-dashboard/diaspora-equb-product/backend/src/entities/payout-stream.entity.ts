import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  Index,
} from 'typeorm';

@Entity('payout_streams')
@Index(['poolId', 'beneficiary'], { unique: true })
export class PayoutStreamEntity {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'uuid' })
  poolId: string;

  @Column({ type: 'varchar', length: 42 })
  beneficiary: string;

  @Column({ type: 'decimal', precision: 36, scale: 18 })
  total: string;

  @Column({ type: 'smallint' })
  upfrontPercent: number;

  @Column({ type: 'decimal', precision: 36, scale: 18 })
  roundAmount: string;

  @Column({ type: 'int' })
  totalRounds: number;

  @Column({ type: 'int', default: 0 })
  releasedRounds: number;

  @Column({ type: 'decimal', precision: 36, scale: 18, default: '0' })
  released: string;

  @Column({ type: 'boolean', default: false })
  frozen: boolean;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
