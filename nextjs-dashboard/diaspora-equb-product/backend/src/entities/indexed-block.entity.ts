import { Entity, PrimaryGeneratedColumn, Column, UpdateDateColumn } from 'typeorm';

/**
 * Tracks the last block processed by the event indexer.
 * One row per contract so each can be indexed independently.
 */
@Entity('indexed_blocks')
export class IndexedBlock {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'varchar', length: 64, unique: true })
  contractName: string;

  @Column({ type: 'bigint', default: 0 })
  lastBlockNumber: number;

  @UpdateDateColumn()
  updatedAt: Date;
}
