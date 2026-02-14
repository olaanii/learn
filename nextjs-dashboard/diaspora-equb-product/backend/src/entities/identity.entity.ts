import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  Index,
} from 'typeorm';

@Entity('identities')
export class Identity {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'varchar', length: 66, unique: true })
  @Index()
  identityHash: string;

  @Column({ type: 'varchar', length: 42, unique: true, nullable: true })
  @Index()
  walletAddress: string;

  @Column({ type: 'varchar', default: 'unbound' })
  bindingStatus: string; // 'unbound' | 'bound' | 'queued-for-onchain' | 'onchain'

  @CreateDateColumn()
  boundAt: Date;
}
