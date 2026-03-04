import { Controller, Get } from '@nestjs/common';
import {
  HealthCheck,
  HealthCheckService,
  TypeOrmHealthIndicator,
} from '@nestjs/terminus';
import { ApiTags, ApiOperation } from '@nestjs/swagger';
import { Web3Service } from '../web3/web3.service';
import { IndexerService } from '../indexer/indexer.service';
import { CacheService } from '../cache/cache.service';
import { Public } from '../common/decorators/public.decorator';

@ApiTags('Health')
@Controller('health')
@Public()
export class HealthController {
  constructor(
    private health: HealthCheckService,
    private db: TypeOrmHealthIndicator,
    private web3: Web3Service,
    private indexer: IndexerService,
    private cache: CacheService,
  ) {}

  @Get()
  @HealthCheck()
  @ApiOperation({ summary: 'Application health check' })
  check() {
    return this.health.check([
      () => this.db.pingCheck('database'),
      async () => {
        const healthy = await this.web3.isRpcHealthy();
        if (healthy) {
          return { rpc: { status: 'up' } };
        }
        throw new Error('RPC node unreachable');
      },
    ]);
  }

  @Get('indexer')
  @ApiOperation({ summary: 'Event indexer status and sync progress' })
  async indexerStatus() {
    return this.indexer.getStatus();
  }

  @Get('detailed')
  @ApiOperation({
    summary: 'Detailed health: DB, RPC, indexer, Redis, block lag',
  })
  async detailed() {
    const startTime = Date.now();
    const [dbStatus, rpcStatus, indexerStatus, redisStatus] =
      await Promise.allSettled([
        this.checkDatabase(),
        this.checkRpc(),
        this.indexer.getStatus(),
        this.checkRedis(),
      ]);

    const db = dbStatus.status === 'fulfilled' ? dbStatus.value : { status: 'down', error: (dbStatus as PromiseRejectedResult).reason?.message };
    const rpc = rpcStatus.status === 'fulfilled' ? rpcStatus.value : { status: 'down', error: (rpcStatus as PromiseRejectedResult).reason?.message };
    const indexer = indexerStatus.status === 'fulfilled' ? indexerStatus.value : { status: 'down', error: (indexerStatus as PromiseRejectedResult).reason?.message };
    const redis = redisStatus.status === 'fulfilled' ? redisStatus.value : { status: 'down', error: (redisStatus as PromiseRejectedResult).reason?.message };

    const indexerData = indexerStatus.status === 'fulfilled' ? indexerStatus.value : null;
    const blockLag = this.computeBlockLag(indexerData);

    const allHealthy =
      db.status === 'up' &&
      rpc.status === 'up' &&
      redis.status === 'up' &&
      indexerData?.isRunning === true;

    return {
      status: allHealthy ? 'healthy' : 'degraded',
      timestamp: new Date().toISOString(),
      responseTimeMs: Date.now() - startTime,
      services: {
        database: db,
        rpc,
        indexer: {
          status: indexerData?.isRunning ? 'up' : 'down',
          startedAt: indexerData?.startedAt ?? null,
          lastError: indexerData?.lastError ?? null,
          indexedEventCount: indexerData?.indexedEventCount ?? 0,
        },
        redis,
      },
      chain: {
        currentBlock: indexerData?.currentChainBlock ?? null,
        lastIndexedBlocks: indexerData?.lastIndexedBlocks ?? {},
        maxBlockLag: blockLag,
      },
    };
  }

  private async checkDatabase(): Promise<{ status: string; latencyMs: number }> {
    const start = Date.now();
    await this.db.pingCheck('database');
    return { status: 'up', latencyMs: Date.now() - start };
  }

  private async checkRpc(): Promise<{
    status: string;
    latencyMs: number;
    blockNumber: number | null;
  }> {
    const start = Date.now();
    const provider = this.web3.getProvider();
    const blockNumber = await provider.getBlockNumber();
    return {
      status: 'up',
      latencyMs: Date.now() - start,
      blockNumber,
    };
  }

  private async checkRedis(): Promise<{
    status: string;
    latencyMs: number;
  }> {
    const start = Date.now();
    const testKey = '__health_check__';
    await this.cache.set(testKey, 'ok', 10);
    const value = await this.cache.get<string>(testKey);
    await this.cache.del(testKey);
    if (value !== 'ok') {
      throw new Error('Cache read-back mismatch');
    }
    return { status: 'up', latencyMs: Date.now() - start };
  }

  private computeBlockLag(
    indexerData: Awaited<ReturnType<IndexerService['getStatus']>> | null,
  ): number | null {
    if (!indexerData?.currentChainBlock || !indexerData.lastIndexedBlocks) {
      return null;
    }
    const blocks = Object.values(indexerData.lastIndexedBlocks);
    if (blocks.length === 0) return null;

    const minIndexed = Math.min(...blocks);
    return indexerData.currentChainBlock - minIndexed;
  }
}
