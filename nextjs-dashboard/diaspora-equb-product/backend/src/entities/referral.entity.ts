import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  Index,
} from 'typeorm';

@Entity('referrals')
@Index(['referrerWallet'])
export class Referral {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'varchar', length: 42 })
  referrerWallet: string;

  @Column({ type: 'varchar', length: 42, unique: true })
  referredWallet: string;

  @Column({ type: 'decimal', precision: 36, scale: 18, default: '0' })
  totalCommission: string;

  @Column({ type: 'boolean', default: true })
  active: boolean;

  @CreateDateColumn()
  joinedAt: Date;
}
