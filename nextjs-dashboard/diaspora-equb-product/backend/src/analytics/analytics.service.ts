import { BadRequestException, Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { In, Repository, SelectQueryBuilder } from 'typeorm';
import { Contribution } from '../entities/contribution.entity';
import { PoolMember } from '../entities/pool-member.entity';
import { Pool } from '../entities/pool.entity';
import { PayoutStreamEntity } from '../entities/payout-stream.entity';
import { Round } from '../entities/round.entity';
import { Season } from '../entities/season.entity';
import {
  GlobalStatsQueryDto,
  JoinedProgressQueryDto,
  LeaderboardQueryDto,
  PopularSeriesQueryDto,
  SummaryQueryDto,
} from './dto/equb-insights-query.dto';

type Bucket = 'hour' | 'day';

@Injectable()
export class AnalyticsService {
  private readonly logger = new Logger(AnalyticsService.name);
  constructor(
    @InjectRepository(Pool)
    private readonly poolRepo: Repository<Pool>,
    @InjectRepository(PoolMember)
    private readonly memberRepo: Repository<PoolMember>,
    @InjectRepository(Contribution)
    private readonly contributionRepo: Repository<Contribution>,
    @InjectRepository(Season)
    private readonly seasonRepo: Repository<Season>,
    @InjectRepository(Round)
    private readonly roundRepo: Repository<Round>,
    @InjectRepository(PayoutStreamEntity)
    private readonly payoutStreamRepo: Repository<PayoutStreamEntity>,
  ) {}

  private logAnalyticsTelemetry(payload: {
    endpoint: 'popular_series' | 'joined_progress' | 'summary';
    wallet?: string;
    from?: string;
    to?: string;
    limit?: number;
    offset?: number;
    status: 'success' | 'error';
    durationMs: number;
    itemCount?: number;
    pointCount?: number;
    errorCode?: string;
  }) {
    this.logger.log(`telemetry.analytics ${JSON.stringify(payload)}`);
  }

  async getPopularSeries(query: PopularSeriesQueryDto) {
    const startedAt = Date.now();
    const bucket = query.bucket ?? 'day';
    const { from, to } = this.resolveWindow(query.from, query.to, bucket);
    const limit = Math.min(query.limit ?? 5, 50);
    const offset = query.offset ?? 0;
    const metric = (query.metric ?? 'joins').toLowerCase();

    try {
      const poolQuery = this.poolRepo
        .createQueryBuilder('pool')
        .where('pool.createdAt BETWEEN :from AND :to', { from, to });

      this.applyPoolFilters(poolQuery, query.token, query.status);

      const pools = await poolQuery.getMany();
      if (!pools.length) {
        this.logAnalyticsTelemetry({
          endpoint: 'popular_series',
          from: from.toISOString(),
          to: to.toISOString(),
          limit,
          offset,
          status: 'success',
          durationMs: Date.now() - startedAt,
          itemCount: 0,
          pointCount: 0,
        });
        return { series: [] };
      }

      const poolIds = pools.map((pool) => pool.id);
      const [members, contributions] = await Promise.all([
        this.memberRepo.find({ where: { poolId: In(poolIds) } }),
        this.contributionRepo.find({ where: { poolId: In(poolIds) } }),
      ]);

      const scoreByPool = new Map<string, number>();
      for (const pool of pools) {
        const joins = members.filter((row) => row.poolId === pool.id).length;
        const contributionCount = contributions.filter(
          (row) => row.poolId === pool.id,
        ).length;

        scoreByPool.set(
          pool.id,
          metric === 'contributions' ? contributionCount : joins,
        );
      }

      const rankedPools = [...pools].sort(
        (a, b) => (scoreByPool.get(b.id) ?? 0) - (scoreByPool.get(a.id) ?? 0),
      );
      const totalPools = rankedPools.length;
      const topPools = rankedPools.slice(offset, offset + limit);

      const pointsByPool = new Map<string, Map<number, number>>();
      for (const pool of topPools) {
        pointsByPool.set(pool.id, new Map<number, number>());
      }

      const sourceRows = metric === 'contributions' ? contributions : members;
      const rowDate = (row: Contribution | PoolMember) =>
        row instanceof Contribution ? row.createdAt : row.joinedAt;

      for (const row of sourceRows) {
        if (!pointsByPool.has(row.poolId)) {
          continue;
        }

        const ts = rowDate(row).getTime();
        if (ts < from.getTime() || ts > to.getTime()) {
          continue;
        }

        const alignedTs = this.alignTimestamp(ts, bucket);
        const bucketMap = pointsByPool.get(row.poolId)!;
        bucketMap.set(alignedTs, (bucketMap.get(alignedTs) ?? 0) + 1);
      }

      const series = topPools.map((pool) => {
        const bucketMap = pointsByPool.get(pool.id) ?? new Map<number, number>();
        const points = [...bucketMap.entries()]
          .sort((a, b) => a[0] - b[0])
          .map(([ts, value]) => ({ ts, value }));

        return {
          poolId: pool.id,
          poolName: `Pool #${pool.onChainPoolId ?? pool.id.slice(0, 8)}`,
          points: this.capPoints(points, 200),
        };
      });

      const pointCount = series.reduce(
        (sum, item) => sum + item.points.length,
        0,
      );
      this.logAnalyticsTelemetry({
        endpoint: 'popular_series',
        from: from.toISOString(),
        to: to.toISOString(),
        limit,
        offset,
        status: 'success',
        durationMs: Date.now() - startedAt,
        itemCount: series.length,
        pointCount,
      });

      return {
        series,
        pagination: {
          limit,
          offset,
          total: totalPools,
          hasMore: offset + topPools.length < totalPools,
        },
      };
    } catch (error) {
      this.logAnalyticsTelemetry({
        endpoint: 'popular_series',
        from: from.toISOString(),
        to: to.toISOString(),
        limit,
        offset,
        status: 'error',
        durationMs: Date.now() - startedAt,
        errorCode:
          error instanceof BadRequestException
            ? 'BAD_REQUEST'
            : 'UNHANDLED_ERROR',
      });
      throw error;
    }
  }

  async getJoinedProgress(query: JoinedProgressQueryDto) {
    const startedAt = Date.now();
    const bucket = query.bucket ?? 'day';
    const { from, to } = this.resolveWindow(query.from, query.to, bucket);
    const wallet = query.wallet.toLowerCase();

    try {
      const memberships = await this.memberRepo.find();
      const joined = memberships.filter(
        (row) => row.walletAddress.toLowerCase() === wallet,
      );

      if (!joined.length) {
        this.logAnalyticsTelemetry({
          endpoint: 'joined_progress',
          wallet,
          from: from.toISOString(),
          to: to.toISOString(),
          status: 'success',
          durationMs: Date.now() - startedAt,
          itemCount: 0,
          pointCount: 0,
        });
        return { pools: [] };
      }

      const poolIds = joined.map((row) => row.poolId);
      const poolQuery = this.poolRepo
        .createQueryBuilder('pool')
        .where('pool.id IN (:...poolIds)', { poolIds });

      this.applyPoolFilters(poolQuery, query.token, query.status);

      const pools = await poolQuery.getMany();
      if (!pools.length) {
        this.logAnalyticsTelemetry({
          endpoint: 'joined_progress',
          wallet,
          from: from.toISOString(),
          to: to.toISOString(),
          status: 'success',
          durationMs: Date.now() - startedAt,
          itemCount: 0,
          pointCount: 0,
        });
        return { pools: [] };
      }

      const filteredPoolIds = pools.map((pool) => pool.id);

      const [seasons, contributions, streams] = await Promise.all([
        this.seasonRepo.find({ where: { poolId: In(filteredPoolIds) } }),
        this.contributionRepo.find({ where: { poolId: In(filteredPoolIds) } }),
        this.payoutStreamRepo.find({ where: { poolId: In(filteredPoolIds) } }),
      ]);

      const latestSeasonByPool = new Map<string, Season>();
      for (const season of seasons) {
        const prev = latestSeasonByPool.get(season.poolId);
        if (!prev || season.seasonNumber > prev.seasonNumber) {
          latestSeasonByPool.set(season.poolId, season);
        }
      }

      const poolsPayload = pools.map((pool) => {
        const season = latestSeasonByPool.get(pool.id);
        const roundsDone =
          season?.completedRounds ?? Math.max(pool.currentRound - 1, 0);
        const roundsTotal = season?.totalRounds ?? pool.maxMembers;
        const completionPct =
          roundsTotal > 0 ? (roundsDone / roundsTotal) * 100 : 0;

        const stream = streams.find(
          (row) =>
            row.poolId === pool.id && row.beneficiary.toLowerCase() === wallet,
        );

        const payoutReleased = Number(stream?.released ?? '0');
        const payoutTotal = Number(stream?.total ?? '0');
        const payoutRemaining = Math.max(payoutTotal - payoutReleased, 0);

        const contributionBuckets = new Map<number, number>();
        for (const row of contributions) {
          if (row.poolId !== pool.id || row.walletAddress.toLowerCase() !== wallet) {
            continue;
          }

          const ts = row.createdAt.getTime();
          if (ts < from.getTime() || ts > to.getTime()) {
            continue;
          }

          const alignedTs = this.alignTimestamp(ts, bucket);
          contributionBuckets.set(
            alignedTs,
            (contributionBuckets.get(alignedTs) ?? 0) + 1,
          );
        }

        const points = [...contributionBuckets.entries()]
          .sort((a, b) => a[0] - b[0])
          .map(([ts, value]) => ({ ts, value }));

        return {
          poolId: pool.id,
          poolName: `Pool #${pool.onChainPoolId ?? pool.id.slice(0, 8)}`,
          completionPct: Number(completionPct.toFixed(2)),
          roundsDone,
          roundsTotal,
          payoutReleased,
          payoutRemaining,
          points: this.capPoints(points, 200),
        };
      });

      const pointCount = poolsPayload.reduce(
        (sum, pool) => sum + pool.points.length,
        0,
      );
      this.logAnalyticsTelemetry({
        endpoint: 'joined_progress',
        wallet,
        from: from.toISOString(),
        to: to.toISOString(),
        status: 'success',
        durationMs: Date.now() - startedAt,
        itemCount: poolsPayload.length,
        pointCount,
      });

      return { pools: poolsPayload };
    } catch (error) {
      this.logAnalyticsTelemetry({
        endpoint: 'joined_progress',
        wallet,
        from: from.toISOString(),
        to: to.toISOString(),
        status: 'error',
        durationMs: Date.now() - startedAt,
        errorCode:
          error instanceof BadRequestException
            ? 'BAD_REQUEST'
            : 'UNHANDLED_ERROR',
      });
      throw error;
    }
  }

  async getSummary(query: SummaryQueryDto) {
    const startedAt = Date.now();
    const { from, to } = this.resolveWindow(query.from, query.to, 'day');
    const wallet = query.wallet.toLowerCase();

    try {
      const memberships = await this.memberRepo.find();
      const joinedPoolIds = memberships
        .filter((row) => row.walletAddress.toLowerCase() === wallet)
        .map((row) => row.poolId);

      if (!joinedPoolIds.length) {
        this.logAnalyticsTelemetry({
          endpoint: 'summary',
          wallet,
          from: from.toISOString(),
          to: to.toISOString(),
          status: 'success',
          durationMs: Date.now() - startedAt,
          itemCount: 0,
        });
        return { activePools: 0, endingSoon: 0, winnerPending: 0 };
      }

      const poolQuery = this.poolRepo
        .createQueryBuilder('pool')
        .where('pool.id IN (:...joinedPoolIds)', { joinedPoolIds })
        .andWhere('pool.createdAt BETWEEN :from AND :to', { from, to });

      this.applyPoolFilters(poolQuery, query.token, query.status);
      const pools = await poolQuery.getMany();
      if (!pools.length) {
        this.logAnalyticsTelemetry({
          endpoint: 'summary',
          wallet,
          from: from.toISOString(),
          to: to.toISOString(),
          status: 'success',
          durationMs: Date.now() - startedAt,
          itemCount: 0,
        });
        return { activePools: 0, endingSoon: 0, winnerPending: 0 };
      }

      const poolIds = pools.map((pool) => pool.id);
      const [seasons, closedRounds] = await Promise.all([
        this.seasonRepo.find({ where: { poolId: In(poolIds) } }),
        this.roundRepo.find({ where: { poolId: In(poolIds), status: 'closed' } }),
      ]);

      const latestSeasonByPool = new Map<string, Season>();
      for (const season of seasons) {
        const prev = latestSeasonByPool.get(season.poolId);
        if (!prev || season.seasonNumber > prev.seasonNumber) {
          latestSeasonByPool.set(season.poolId, season);
        }
      }

      const activePools = pools.filter((pool) => pool.status === 'active').length;
      const endingSoon = pools.filter((pool) => {
        const season = latestSeasonByPool.get(pool.id);
        const total = season?.totalRounds ?? pool.maxMembers;
        const done = season?.completedRounds ?? Math.max(pool.currentRound - 1, 0);
        return total - done <= 1 && total - done > 0;
      }).length;

      const winnerPending = new Set(closedRounds.map((round) => round.poolId)).size;

      this.logAnalyticsTelemetry({
        endpoint: 'summary',
        wallet,
        from: from.toISOString(),
        to: to.toISOString(),
        status: 'success',
        durationMs: Date.now() - startedAt,
        itemCount: pools.length,
      });

      return { activePools, endingSoon, winnerPending };
    } catch (error) {
      this.logAnalyticsTelemetry({
        endpoint: 'summary',
        wallet,
        from: from.toISOString(),
        to: to.toISOString(),
        status: 'error',
        durationMs: Date.now() - startedAt,
        errorCode:
          error instanceof BadRequestException
            ? 'BAD_REQUEST'
            : 'UNHANDLED_ERROR',
      });
      throw error;
    }
  }

  async getGlobalStats(query: GlobalStatsQueryDto) {
    const qb = this.poolRepo.createQueryBuilder('pool');

    if (query.type !== undefined && query.type !== null) {
      qb.andWhere('pool.equbType = :equbType', { equbType: query.type });
    }

    const [totalCount, activeCount, completedCount] = await Promise.all([
      qb.clone().getCount(),
      qb.clone().andWhere('LOWER(pool.status) = :s', { s: 'active' }).getCount(),
      qb.clone().andWhere('LOWER(pool.status) = :s', { s: 'completed' }).getCount(),
    ]);

    const activePools = await qb
      .clone()
      .andWhere('LOWER(pool.status) = :s', { s: 'active' })
      .getMany();

    const activePoolIds = activePools.map((p) => p.id);

    let tvl = 0;
    let totalMembers = 0;

    if (activePoolIds.length > 0) {
      const memberCounts = await this.memberRepo
        .createQueryBuilder('pm')
        .select('pm.poolId', 'poolId')
        .addSelect('COUNT(pm.id)', 'cnt')
        .where('pm.poolId IN (:...ids)', { ids: activePoolIds })
        .groupBy('pm.poolId')
        .getRawMany<{ poolId: string; cnt: string }>();

      const memberCountMap = new Map(
        memberCounts.map((r) => [r.poolId, Number(r.cnt)]),
      );

      for (const pool of activePools) {
        const members = memberCountMap.get(pool.id) ?? 0;
        tvl += Number(pool.contributionAmount) * members;
      }

      const distinctMembers = await this.memberRepo
        .createQueryBuilder('pm')
        .select('COUNT(DISTINCT pm.walletAddress)', 'cnt')
        .where('pm.poolId IN (:...ids)', { ids: activePoolIds })
        .getRawOne<{ cnt: string }>();

      totalMembers = Number(distinctMembers?.cnt ?? 0);
    }

    const totalContributions = activePoolIds.length
      ? Number(
          (
            await this.contributionRepo
              .createQueryBuilder('c')
              .select('COUNT(c.id)', 'cnt')
              .where('c.poolId IN (:...ids)', { ids: activePoolIds })
              .getRawOne<{ cnt: string }>()
          )?.cnt ?? 0,
        )
      : 0;

    const defaultCount = activePoolIds.length
      ? Number(
          (
            await this.contributionRepo
              .createQueryBuilder('c')
              .select('COUNT(c.id)', 'cnt')
              .where('c.poolId IN (:...ids)', { ids: activePoolIds })
              .andWhere("LOWER(c.status) = 'failed'")
              .getRawOne<{ cnt: string }>()
          )?.cnt ?? 0,
        )
      : 0;

    const completionRate = totalCount > 0 ? (completedCount / totalCount) * 100 : 0;
    const defaultRate =
      totalContributions > 0 ? (defaultCount / totalContributions) * 100 : 0;

    return {
      tvl: Number(tvl.toFixed(4)),
      activeEqubs: activeCount,
      totalMembers,
      completionRate: Number(completionRate.toFixed(2)),
      defaultRate: Number(defaultRate.toFixed(2)),
    };
  }

  async getLeaderboard(query: LeaderboardQueryDto) {
    const sort = query.sort ?? 'members';
    const page = query.page ?? 1;
    const limit = Math.min(query.limit ?? 20, 100);
    const offset = (page - 1) * limit;

    const qb = this.poolRepo
      .createQueryBuilder('pool')
      .leftJoin('pool.members', 'pm')
      .leftJoin('pool.contributions', 'c')
      .select('pool.id', 'poolId')
      .addSelect('pool.onChainPoolId', 'onChainPoolId')
      .addSelect('pool.equbType', 'equbType')
      .addSelect('pool.frequency', 'frequency')
      .addSelect('pool.currentRound', 'currentRound')
      .addSelect('pool.maxMembers', 'maxMembers')
      .addSelect('pool.createdAt', 'createdAt')
      .addSelect('COUNT(DISTINCT pm.id)', 'memberCount')
      .addSelect('COUNT(DISTINCT c.id)', 'contributionCount')
      .groupBy('pool.id');

    if (query.type !== undefined && query.type !== null) {
      qb.andWhere('pool.equbType = :equbType', { equbType: query.type });
    }

    switch (sort) {
      case 'contributions':
        qb.orderBy('COUNT(DISTINCT c.id)', 'DESC');
        break;
      case 'completion':
        qb.orderBy(
          'CASE WHEN pool.maxMembers > 0 THEN CAST(pool.currentRound AS float) / pool.maxMembers ELSE 0 END',
          'DESC',
        );
        break;
      case 'newest':
        qb.orderBy('pool.createdAt', 'DESC');
        break;
      default:
        qb.orderBy('COUNT(DISTINCT pm.id)', 'DESC');
        break;
    }

    qb.offset(offset).limit(limit);

    const rows = await qb.getRawMany<{
      poolId: string;
      onChainPoolId: number | null;
      equbType: number | null;
      frequency: number | null;
      currentRound: number;
      maxMembers: number;
      createdAt: string;
      memberCount: string;
      contributionCount: string;
    }>();

    return rows.map((r) => ({
      poolId: r.poolId,
      onChainPoolId: r.onChainPoolId,
      equbType: r.equbType,
      frequency: r.frequency,
      memberCount: Number(r.memberCount),
      contributionCount: Number(r.contributionCount),
      completionPct:
        Number(r.maxMembers) > 0
          ? Number(
              ((Number(r.currentRound) / Number(r.maxMembers)) * 100).toFixed(2),
            )
          : 0,
      createdAt: r.createdAt,
    }));
  }

  async getTrending() {
    const sevenDaysAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);

    const fastestGrowingQb = this.poolRepo
      .createQueryBuilder('pool')
      .leftJoin('pool.members', 'pm', 'pm.joinedAt >= :since', {
        since: sevenDaysAgo,
      })
      .select('pool.id', 'poolId')
      .addSelect('pool.onChainPoolId', 'onChainPoolId')
      .addSelect('pool.equbType', 'equbType')
      .addSelect('pool.frequency', 'frequency')
      .addSelect('pool.currentRound', 'currentRound')
      .addSelect('pool.maxMembers', 'maxMembers')
      .addSelect('pool.createdAt', 'createdAt')
      .addSelect('COUNT(pm.id)', 'recentJoins')
      .where("LOWER(pool.status) = 'active'")
      .groupBy('pool.id')
      .orderBy('COUNT(pm.id)', 'DESC')
      .limit(5);

    const completingSoonQb = this.poolRepo
      .createQueryBuilder('pool')
      .select('pool.id', 'poolId')
      .addSelect('pool.onChainPoolId', 'onChainPoolId')
      .addSelect('pool.equbType', 'equbType')
      .addSelect('pool.frequency', 'frequency')
      .addSelect('pool.currentRound', 'currentRound')
      .addSelect('pool.maxMembers', 'maxMembers')
      .addSelect('pool.createdAt', 'createdAt')
      .where("LOWER(pool.status) = 'active'")
      .andWhere('pool.maxMembers > 0')
      .andWhere(
        'CAST(pool.currentRound AS float) / pool.maxMembers >= 0.75',
      )
      .orderBy(
        'CAST(pool.currentRound AS float) / pool.maxMembers',
        'DESC',
      )
      .limit(5);

    const newestQb = this.poolRepo
      .createQueryBuilder('pool')
      .select('pool.id', 'poolId')
      .addSelect('pool.onChainPoolId', 'onChainPoolId')
      .addSelect('pool.equbType', 'equbType')
      .addSelect('pool.frequency', 'frequency')
      .addSelect('pool.currentRound', 'currentRound')
      .addSelect('pool.maxMembers', 'maxMembers')
      .addSelect('pool.createdAt', 'createdAt')
      .where("LOWER(pool.status) = 'active'")
      .orderBy('pool.createdAt', 'DESC')
      .limit(5);

    const [fastestGrowing, completingSoon, newest] = await Promise.all([
      fastestGrowingQb.getRawMany(),
      completingSoonQb.getRawMany(),
      newestQb.getRawMany(),
    ]);

    const mapRow = (r: any) => ({
      poolId: r.poolId,
      onChainPoolId: r.onChainPoolId,
      equbType: r.equbType,
      frequency: r.frequency,
      currentRound: Number(r.currentRound),
      maxMembers: Number(r.maxMembers),
      completionPct:
        Number(r.maxMembers) > 0
          ? Number(
              ((Number(r.currentRound) / Number(r.maxMembers)) * 100).toFixed(2),
            )
          : 0,
      createdAt: r.createdAt,
      ...(r.recentJoins !== undefined
        ? { recentJoins: Number(r.recentJoins) }
        : {}),
    });

    return {
      fastestGrowing: fastestGrowing.map(mapRow),
      completingSoon: completingSoon.map(mapRow),
      newest: newest.map(mapRow),
    };
  }

  async getCreatorReputation(address: string) {
    const normalizedAddress = address.toLowerCase();

    const pools = await this.poolRepo
      .createQueryBuilder('pool')
      .where('LOWER(pool.createdBy) = :addr', { addr: normalizedAddress })
      .getMany();

    const totalCreated = pools.length;
    const activePools = pools.filter((p) => p.status === 'active');
    const activeCount = activePools.length;

    const poolIds = pools.map((p) => p.id);

    let totalMembers = 0;
    if (poolIds.length > 0) {
      const result = await this.memberRepo
        .createQueryBuilder('pm')
        .select('COUNT(pm.id)', 'cnt')
        .where('pm.poolId IN (:...ids)', { ids: poolIds })
        .getRawOne<{ cnt: string }>();
      totalMembers = Number(result?.cnt ?? 0);
    }

    let avgCompletionPct = 0;
    if (pools.length > 0) {
      const sum = pools.reduce((acc, p) => {
        if (p.maxMembers > 0) {
          return acc + (p.currentRound / p.maxMembers) * 100;
        }
        return acc;
      }, 0);
      avgCompletionPct = Number((sum / pools.length).toFixed(2));
    }

    return {
      totalCreated,
      activeCount,
      totalMembers,
      avgCompletionPct,
    };
  }

  private applyPoolFilters(
    query: SelectQueryBuilder<Pool>,
    token?: string,
    status?: string,
  ) {
    if (token && token.trim().length > 0) {
      const normalized = token.trim().toLowerCase();
      if (normalized === 'native') {
        query.andWhere(
          'pool.token = :zeroToken',
          { zeroToken: '0x0000000000000000000000000000000000000000' },
        );
      } else {
        query.andWhere('LOWER(pool.token) = :token', { token: normalized });
      }
    }

    if (status && status.trim().length > 0) {
      query.andWhere('LOWER(pool.status) = :status', {
        status: status.trim().toLowerCase(),
      });
    }
  }

  private resolveWindow(from?: string, to?: string, bucket: Bucket = 'day') {
    const now = Date.now();
    const defaultLookbackMs = 7 * 24 * 60 * 60 * 1000;
    const fromMs = from ? this.parseTime(from, 'from') : now - defaultLookbackMs;
    const toMs = to ? this.parseTime(to, 'to') : now;

    if (fromMs > toMs) {
      throw new BadRequestException('Invalid time range: from must be <= to');
    }

    const maxRangeMs = bucket === 'hour'
      ? 14 * 24 * 60 * 60 * 1000
      : 400 * 24 * 60 * 60 * 1000;

    if (toMs - fromMs > maxRangeMs) {
      throw new BadRequestException(
        `Range too large for bucket=${bucket}. Max supported is ${bucket === 'hour' ? 14 : 400} days`,
      );
    }

    return { from: new Date(fromMs), to: new Date(toMs) };
  }

  private parseTime(raw: string, fieldName: string): number {
    const trimmed = raw.trim();
    const asMillis = Number(trimmed);
    if (Number.isFinite(asMillis) && /^\d+$/.test(trimmed)) {
      return asMillis;
    }

    const parsed = Date.parse(trimmed);
    if (Number.isNaN(parsed)) {
      throw new BadRequestException(`Invalid ${fieldName} timestamp: ${raw}`);
    }

    return parsed;
  }

  private alignTimestamp(ts: number, bucket: Bucket): number {
    const date = new Date(ts);
    if (bucket === 'hour') {
      date.setMinutes(0, 0, 0);
    } else {
      date.setHours(0, 0, 0, 0);
    }

    return date.getTime();
  }

  private capPoints(
    points: Array<{ ts: number; value: number }>,
    maxPoints: number,
  ): Array<{ ts: number; value: number }> {
    if (points.length <= maxPoints) {
      return points;
    }

    const stride = Math.ceil(points.length / maxPoints);
    return points.filter((_, index) => index % stride === 0).slice(0, maxPoints);
  }
}
