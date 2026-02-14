import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  UpdateDateColumn,
  Index,
} from 'typeorm';

@Entity('collaterals')
@Index(['walletAddress', 'poolId'], { unique: true })
export class Collateral {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'varchar', length: 42 })
  walletAddress: string;

  @Column({ type: 'uuid', nullable: true })
  poolId: string;

  @Column({ type: 'decimal', precision: 36, scale: 18, default: '0' })
  lockedAmount: string;

  @Column({ type: 'decimal', precision: 36, scale: 18, default: '0' })
  slashedAmount: string;

  @Column({ type: 'decimal', precision: 36, scale: 18, default: '0' })
  availableBalance: string;

  @UpdateDateColumn()
  updatedAt: Date;
}
