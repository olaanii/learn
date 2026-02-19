import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  Index,
} from 'typeorm';

@Entity('token_transfers')
@Index(['from'])
@Index(['to'])
@Index(['txHash'], { unique: true })
@Index(['blockNumber'])
export class TokenTransfer {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'varchar', length: 66 })
  txHash: string;

  @Column({ type: 'varchar', length: 42 })
  from: string;

  @Column({ type: 'varchar', length: 42 })
  to: string;

  @Column({ type: 'varchar' })
  amount: string;

  @Column({ type: 'varchar' })
  rawAmount: string;

  @Column({ type: 'varchar', length: 10 })
  token: string;

  @Column({ type: 'varchar', length: 42 })
  tokenAddress: string;

  @Column({ type: 'int' })
  blockNumber: number;

  @Column({ type: 'bigint', nullable: true })
  timestamp: number | null;

  @CreateDateColumn()
  createdAt: Date;
}
