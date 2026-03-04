import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  ManyToOne,
  JoinColumn,
} from 'typeorm';
import { Referral } from './referral.entity';

@Entity('commissions')
export class Commission {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'uuid' })
  referralId: string;

  @Column({ type: 'uuid', nullable: true })
  poolId: string | null;

  @Column({ type: 'int', nullable: true })
  round: number | null;

  @Column({ type: 'decimal', precision: 36, scale: 18 })
  amount: string;

  @Column({ type: 'varchar', length: 66, nullable: true })
  txHash: string | null;

  @ManyToOne(() => Referral)
  @JoinColumn({ name: 'referralId' })
  referral: Referral;

  @CreateDateColumn()
  createdAt: Date;
}
