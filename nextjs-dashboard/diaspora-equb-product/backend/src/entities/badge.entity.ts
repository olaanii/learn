import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  Index,
} from 'typeorm';

@Entity('badges')
@Index(['walletAddress'])
export class BadgeEntity {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'varchar', length: 42 })
  walletAddress: string;

  @Column({ type: 'int' })
  badgeType: number;

  @Column({ type: 'int', nullable: true })
  onChainTokenId: number | null;

  @Column({ type: 'varchar', length: 66, nullable: true })
  txHash: string | null;

  @Column({ type: 'varchar', nullable: true })
  metadataURI: string | null;

  @CreateDateColumn()
  earnedAt: Date;
}
