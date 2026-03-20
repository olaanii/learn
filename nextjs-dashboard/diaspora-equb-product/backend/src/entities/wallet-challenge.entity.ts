import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  Index,
} from 'typeorm';

export type WalletChallengePurpose = 'login' | 'bind';

@Entity('wallet_challenges')
@Index('IDX_wallet_challenges_key', ['challengeKey'], { unique: true })
export class WalletChallenge {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'varchar', length: 160 })
  challengeKey: string;

  @Column({ type: 'varchar', length: 16 })
  purpose: WalletChallengePurpose;

  @Column({ type: 'varchar', length: 42 })
  walletAddress: string;

  @Column({ type: 'varchar', length: 66, nullable: true })
  identityHash: string | null;

  @Column({ type: 'varchar', length: 64 })
  nonce: string;

  @Column({ type: 'text' })
  message: string;

  @Column({ type: 'timestamptz' })
  expiresAt: Date;

  @Column({ type: 'timestamptz', nullable: true })
  consumedAt: Date | null;

  @CreateDateColumn({ type: 'timestamptz' })
  createdAt: Date;

  @UpdateDateColumn({ type: 'timestamptz' })
  updatedAt: Date;
}
