import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
} from 'typeorm';

@Entity('proposals')
export class Proposal {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'int' })
  onChainProposalId: number;

  @Column({ type: 'uuid' })
  poolId: string;

  @Column({ type: 'int' })
  onChainEqubId: number;

  @Column({ type: 'varchar', length: 42 })
  proposer: string;

  @Column({ type: 'varchar', length: 66 })
  ruleHash: string;

  @Column({ type: 'text', nullable: true })
  description: string | null;

  @Column({ type: 'int', default: 0 })
  yesVotes: number;

  @Column({ type: 'int', default: 0 })
  noVotes: number;

  @Column({ type: 'timestamp' })
  deadline: Date;

  @Column({ type: 'varchar', default: 'active' })
  status: string;

  @Column({ type: 'jsonb', nullable: true })
  proposedRules: Record<string, number> | null;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
