import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  ManyToOne,
  JoinColumn,
  Unique,
} from 'typeorm';
import { Pool } from './pool.entity';
import { Season } from './season.entity';

@Entity('rounds')
@Unique('uq_round_pool_season_number', ['poolId', 'seasonId', 'roundNumber'])
export class Round {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'uuid' })
  poolId: string;

  @ManyToOne(() => Pool, (pool) => pool.rounds, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'poolId' })
  pool: Pool;

  @Column({ type: 'uuid' })
  seasonId: string;

  @ManyToOne(() => Season, (season) => season.rounds, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'seasonId' })
  season: Season;

  @Column({ type: 'int' })
  roundNumber: number;

  @Column({ type: 'varchar', length: 32, default: 'open' })
  status: 'open' | 'closed' | 'winner_picked';

  @Column({ type: 'timestamptz', nullable: true })
  closedAt: Date | null;

  @Column({ type: 'timestamptz', nullable: true })
  winnerPickedAt: Date | null;

  @Column({ type: 'varchar', length: 42, nullable: true })
  winnerWallet: string | null;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
