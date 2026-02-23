import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  ManyToOne,
  JoinColumn,
  OneToMany,
} from 'typeorm';
import { Pool } from './pool.entity';
import { Round } from './round.entity';

@Entity('seasons')
export class Season {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'uuid' })
  poolId: string;

  @ManyToOne(() => Pool, (pool) => pool.seasons, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'poolId' })
  pool: Pool;

  @Column({ type: 'int' })
  seasonNumber: number;

  @Column({ type: 'varchar', default: 'active' })
  status: 'active' | 'completed' | 'config_pending';

  @Column({ type: 'int' })
  totalRounds: number;

  @Column({ type: 'int', default: 0 })
  completedRounds: number;

  @Column({ type: 'decimal', precision: 36, scale: 18 })
  contributionAmount: string;

  @Column({ type: 'varchar', length: 42, default: '0x0000000000000000000000000000000000000000' })
  token: string;

  @Column({ type: 'int', default: 20 })
  payoutSplitPct: number;

  @Column({ type: 'varchar', length: 64, nullable: true })
  cadence: string | null;

  @Column({ type: 'timestamptz', default: () => 'CURRENT_TIMESTAMP' })
  startedAt: Date;

  @Column({ type: 'timestamptz', nullable: true })
  completedAt: Date | null;

  @OneToMany(() => Round, (round) => round.season)
  rounds: Round[];

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}