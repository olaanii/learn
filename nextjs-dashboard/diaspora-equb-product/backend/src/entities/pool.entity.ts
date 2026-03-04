import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  OneToMany,
  ManyToOne,
  JoinColumn,
} from 'typeorm';
import { PoolMember } from './pool-member.entity';
import { Contribution } from './contribution.entity';
import { Season } from './season.entity';
import { Round } from './round.entity';

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

  /** EqubType enum for filtering: 0=Finance, 1=House, 2=Car, 3=Travel, 4=Special, etc. */
  @Column({ type: 'smallint', nullable: true })
  equbType: number | null;

  /** Frequency enum for filtering: 0=Daily, 1=Weekly, 2=BiWeekly, 3=Monthly */
  @Column({ type: 'smallint', nullable: true })
  frequency: number | null;

  @Column({ type: 'varchar', length: 42 })
  treasury: string;

  @Column({ type: 'varchar', length: 42, default: '0x0000000000000000000000000000000000000000' })
  token: string; // ERC-20 token address, or zero address for native CTC

  @Column({ type: 'varchar', default: 'pending-onchain' })
  status: string; // 'pending-onchain' | 'active' | 'completed' | 'cancelled'

  @Column({ type: 'varchar', length: 66, nullable: true })
  txHash: string;

  @Column({ type: 'uuid', nullable: true })
  activeSeasonId: string | null;

  @Column({ type: 'uuid', nullable: true })
  activeRoundId: string | null;

  /** Address that signed the createPool transaction (pool creator / admin for close round, pick winner). */
  @Column({ type: 'varchar', length: 42, nullable: true })
  createdBy: string | null;

  @OneToMany(() => PoolMember, (member) => member.pool)
  members: PoolMember[];

  @OneToMany(() => Contribution, (contribution) => contribution.pool)
  contributions: Contribution[];

  @OneToMany(() => Season, (season) => season.pool)
  seasons: Season[];

  @OneToMany(() => Round, (round) => round.pool)
  rounds: Round[];

  @ManyToOne(() => Season, { nullable: true, onDelete: 'SET NULL' })
  @JoinColumn({ name: 'activeSeasonId' })
  activeSeason: Season | null;

  @ManyToOne(() => Round, { nullable: true, onDelete: 'SET NULL' })
  @JoinColumn({ name: 'activeRoundId' })
  activeRound: Round | null;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
