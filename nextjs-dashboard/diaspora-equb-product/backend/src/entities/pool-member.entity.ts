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

@Entity('pool_members')
@Index(['poolId', 'walletAddress'], { unique: true })
export class PoolMember {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'uuid' })
  poolId: string;

  @Column({ type: 'varchar', length: 42 })
  walletAddress: string;

  @ManyToOne(() => Pool, (pool) => pool.members)
  @JoinColumn({ name: 'poolId' })
  pool: Pool;

  @CreateDateColumn()
  joinedAt: Date;
}
