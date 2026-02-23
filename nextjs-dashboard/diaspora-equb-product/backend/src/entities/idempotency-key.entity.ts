import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  Unique,
} from 'typeorm';

@Entity('idempotency_keys')
@Unique('uq_idempotency_route_key', ['route', 'key'])
export class IdempotencyKey {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'varchar', length: 128 })
  route: string;

  @Column({ type: 'varchar', length: 128 })
  key: string;

  @Column({ type: 'varchar', length: 128 })
  requestHash: string;

  @Column({ type: 'jsonb' })
  responseBody: Record<string, unknown>;

  @CreateDateColumn()
  createdAt: Date;
}
