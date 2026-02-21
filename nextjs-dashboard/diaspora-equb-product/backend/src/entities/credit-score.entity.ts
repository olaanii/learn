import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  UpdateDateColumn,
  Index,
} from 'typeorm';

@Entity('credit_scores')
export class CreditScore {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'varchar', length: 42, unique: true })
  @Index()
  walletAddress: string;

  @Column({ type: 'int', default: 0 })
  score: number;

  @UpdateDateColumn()
  lastUpdated: Date;
}
