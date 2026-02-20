/**
 * Lists current pools, which are available for draw, and which wallet (treasury) created each.
 * Run from backend dir: npx ts-node -r tsconfig-paths/register scripts/list-pools-for-draw.ts
 */
import { DataSource } from 'typeorm';
import * as dotenv from 'dotenv';
import { join } from 'path';
import { Pool } from '../src/entities/pool.entity';
import { PoolMember } from '../src/entities/pool-member.entity';
import { Contribution } from '../src/entities/contribution.entity';

// Load .env from backend root
dotenv.config({ path: join(__dirname, '..', '.env') });

const dataSource = new DataSource({
  type: 'postgres',
  host: process.env.DATABASE_HOST || 'localhost',
  port: parseInt(process.env.DATABASE_PORT || '5432', 10),
  username: process.env.DATABASE_USERNAME || 'equb',
  password: process.env.DATABASE_PASSWORD || 'change_me',
  database: process.env.DATABASE_NAME || 'diaspora_equb',
  entities: [Pool, PoolMember, Contribution],
  synchronize: false,
  logging: false,
});

const zero = '0x0000000000000000000000000000000000000000';

function truncate(s: string, len = 10): string {
  if (!s || s.length <= len) return s;
  return `${s.slice(0, 6)}...${s.slice(-4)}`;
}

async function main() {
  await dataSource.initialize();
  const poolRepo = dataSource.getRepository(Pool);

  const pools = await poolRepo.find({
    relations: ['members'],
    order: { createdAt: 'DESC' },
  });

  const poolsWithMembers = pools.map((p) => ({
    ...p,
    memberCount: p.members?.length ?? 0,
  }));

  console.log('\n--- Pools (current round, creator treasury, available for draw) ---\n');

  const availableForDraw: any[] = [];

  for (const pool of poolsWithMembers) {
    const id = pool.id;
    const onChainId = pool.onChainPoolId;
    const currentRound = pool.currentRound ?? 1;
    const maxMembers = pool.maxMembers ?? 0;
    const treasury = pool.treasury || zero;
    const status = pool.status || 'pending-onchain';
    const memberCount = pool.memberCount ?? 0;
    const contributionAmount = pool.contributionAmount ?? '0';

    const canDraw =
      onChainId != null &&
      status === 'active' &&
      memberCount > 0;

    if (canDraw) availableForDraw.push(pool);

    const creator =
      treasury === zero ? '(treasury not set – indexer/backfill may fix)' : truncate(treasury, 42);

    console.log(`Pool ID:        ${id}`);
    console.log(`On-chain ID:    ${onChainId ?? '—'}`);
    console.log(`Tier:           ${pool.tier ?? 0}`);
    console.log(`Current round:  ${currentRound}`);
    console.log(`Members:        ${memberCount} / ${maxMembers}`);
    console.log(`Contribution:   ${contributionAmount} (wei/smallest unit)`);
    console.log(`Status:         ${status}`);
    console.log(`Created by:     ${creator}`);
    console.log(`Available for draw (close round + pick winner): ${canDraw ? 'Yes' : 'No'}`);
    console.log('');
  }

  console.log('--- Summary ---');
  console.log(`Total pools: ${pools.length}`);
  console.log(`Pools available for draw (on-chain, active, have members): ${availableForDraw.length}`);
  if (availableForDraw.length > 0) {
    console.log('\nPools you can run a draw on (pool id → creator treasury):');
    availableForDraw.forEach((p) => {
      const creator = (p.treasury && p.treasury !== zero) ? p.treasury : '(treasury unknown)';
      console.log(`  ${p.id}  →  ${creator}`);
    });
  }
  console.log('');

  await dataSource.destroy();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
