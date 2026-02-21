import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  ManyToOne,
  JoinColumn,
  Index,
} from 'typeorm';
import { Pool } from './pool.entity';

@Entity('contributions')
@Index(['poolId', 'walletAddress', 'round'], { unique: true })
export class Contribution {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'uuid' })
  poolId: string;

  @Column({ type: 'varchar', length: 42 })
  walletAddress: string;

  @Column({ type: 'int' })
  round: number;

  @Column({ type: 'varchar', length: 66, nullable: true })
  txHash: string | null;

  @Column({ type: 'varchar', default: 'pending-onchain' })
  status: string; // 'pending-onchain' | 'confirmed' | 'failed'

  @ManyToOne(() => Pool, (pool) => pool.contributions)
  @JoinColumn({ name: 'poolId' })
  pool: Pool;

  @CreateDateColumn()
  createdAt: Date;
}
