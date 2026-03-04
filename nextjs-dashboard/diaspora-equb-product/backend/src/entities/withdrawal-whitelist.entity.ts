import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn } from 'typeorm';

@Entity('withdrawal_whitelist')
export class WithdrawalWhitelist {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'varchar', length: 42 })
  walletAddress: string;

  @Column({ type: 'varchar', length: 42 })
  whitelistedAddress: string;

  @Column({ type: 'varchar', nullable: true })
  label: string | null;

  @CreateDateColumn()
  addedAt: Date;
}
