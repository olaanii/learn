import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  Index,
} from 'typeorm';

@Entity('tier_configs')
export class TierConfig {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'smallint', unique: true })
  @Index()
  tier: number;

  @Column({ type: 'decimal', precision: 36, scale: 18 })
  maxPoolSize: string;

  @Column({ type: 'int' })
  collateralRateBps: number;

  @Column({ type: 'boolean', default: true })
  enabled: boolean;
}
