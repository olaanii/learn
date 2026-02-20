import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  OneToMany,
} from 'typeorm';
import { PoolMember } from './pool-member.entity';
import { Contribution } from './contribution.entity';

@Entity('pools')
export class Pool {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'int', nullable: true })
  onChainPoolId: number;

  @Column({ type: 'smallint' })
  tier: number;

  @Column({ type: 'decimal', precision: 36, scale: 18 })
  contributionAmount: string;

  @Column({ type: 'int' })
  maxMembers: number;

  @Column({ type: 'int', default: 1 })
  currentRound: number;

  @Column({ type: 'varchar', length: 42 })
  treasury: string;

  @Column({ type: 'varchar', length: 42, default: '0x0000000000000000000000000000000000000000' })
  token: string; // ERC-20 token address, or zero address for native CTC

  @Column({ type: 'varchar', default: 'pending-onchain' })
  status: string; // 'pending-onchain' | 'active' | 'completed' | 'cancelled'

  @Column({ type: 'varchar', length: 66, nullable: true })
  txHash: string;

  /** Address that signed the createPool transaction (pool creator / admin for close round, pick winner). */
  @Column({ type: 'varchar', length: 42, nullable: true })
  createdBy: string | null;

  @OneToMany(() => PoolMember, (member) => member.pool)
  members: PoolMember[];

  @OneToMany(() => Contribution, (contribution) => contribution.pool)
  contributions: Contribution[];

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
