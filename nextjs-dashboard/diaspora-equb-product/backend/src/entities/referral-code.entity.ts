import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
} from 'typeorm';

@Entity('referral_codes')
export class ReferralCode {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'varchar', length: 42, unique: true })
  walletAddress: string;

  @Column({ type: 'varchar', length: 12, unique: true })
  code: string;

  @CreateDateColumn()
  createdAt: Date;
}
