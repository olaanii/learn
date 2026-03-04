import {
  Injectable,
  Logger,
  NotFoundException,
  ConflictException,
  BadRequestException,
  HttpException,
  HttpStatus,
  OnModuleInit,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { DataSource, EntityManager, Repository } from 'typeorm';
import { Pool } from '../entities/pool.entity';
import { PoolMember } from '../entities/pool-member.entity';
import { Contribution } from '../entities/contribution.entity';
import { PayoutStreamEntity } from '../entities/payout-stream.entity';
import { Season } from '../entities/season.entity';
import { Round } from '../entities/round.entity';
import { IdempotencyKey } from '../entities/idempotency-key.entity';
import { ethers } from 'ethers';
import { createHash, randomInt } from 'crypto';
import { Web3Service, UnsignedTxDto } from '../web3/web3.service';
import { NotificationsService } from '../notifications/notifications.service';
import { RulesService } from '../rules/rules.service';
import { EventsGateway } from '../websocket/events.gateway';

@Injectable()
export class PoolsService implements OnModuleInit {
  private readonly logger = new Logger(PoolsService.name);
  private readonly selectWinnerCloseCooldownMs = 8000;
  private readonly selectWinnerCloseGuard = new Map<string, number>();

  private logPoolLifecycleTelemetry(payload: {
    action: 'close_active_round' | 'pick_winner_active_round' | 'create_next_season';
    poolId: string;
    seasonId?: string;
    roundId?: string;
    status: 'success' | 'error';
    durationMs: number;
    errorCode?: string;
  }) {
    this.logger.log(`telemetry.pool_lifecycle ${JSON.stringify(payload)}`);
  }

  private enforceSelectWinnerCloseCooldown(
    poolId: string,
    caller: string,
  ): void {
    const now = Date.now();
    const key = `${poolId}:${caller.toLowerCase()}`;
    const lastAttempt = this.selectWinnerCloseGuard.get(key);

    if (lastAttempt) {
      const elapsed = now - lastAttempt;
      if (elapsed < this.selectWinnerCloseCooldownMs) {
        const waitSec = Math.ceil(
          (this.selectWinnerCloseCooldownMs - elapsed) / 1000,
        );
        throw new HttpException(
          `Please wait ${waitSec}s before retrying close-round winner selection for this pool.`,
          HttpStatus.TOO_MANY_REQUESTS,
        );
      }
    }

    this.selectWinnerCloseGuard.set(key, now);

    if (this.selectWinnerCloseGuard.size > 1000) {
      const cutoff = now - this.selectWinnerCloseCooldownMs * 2;
      for (const [guardKey, timestamp] of this.selectWinnerCloseGuard) {
        if (timestamp < cutoff) this.selectWinnerCloseGuard.delete(guardKey);
      }
    }
  }

  constructor(
    @InjectRepository(Pool)
    private readonly poolRepo: Repository<Pool>,
    @InjectRepository(PoolMember)
    private readonly memberRepo: Repository<PoolMember>,
    @InjectRepository(Contribution)
    private readonly contributionRepo: Repository<Contribution>,
    @InjectRepository(PayoutStreamEntity)
    private readonly payoutStreamRepo: Repository<PayoutStreamEntity>,
    @InjectRepository(Season)
    private readonly seasonRepo: Repository<Season>,
    @InjectRepository(Round)
    private readonly roundRepo: Repository<Round>,
    @InjectRepository(IdempotencyKey)
    private readonly idempotencyKeyRepo: Repository<IdempotencyKey>,
    private readonly dataSource: DataSource,
    private readonly web3Service: Web3Service,
    private readonly notifications: NotificationsService,
    private readonly rulesService: RulesService,
    private readonly eventsGateway: EventsGateway,
  ) {}

  async onModuleInit() {
    try {
      const result = await this.configureTiersOnChain();
      this.logger.log(
        `Auto-configured tiers on startup: ${JSON.stringify(result)}`,
      );
    } catch (e) {
      this.logger.warn(`Auto-configure tiers skipped: ${e.message}`);
    }
  }

  private explicitError(
    code: string,
    message: string,
    status = HttpStatus.BAD_REQUEST,
  ): never {
    throw new HttpException({ code, message }, status);
  }

  private poolRepository(manager?: EntityManager): Repository<Pool> {
    return manager ? manager.getRepository(Pool) : this.poolRepo;
  }

  private seasonRepository(manager?: EntityManager): Repository<Season> {
    return manager ? manager.getRepository(Season) : this.seasonRepo;
  }

  private roundRepository(manager?: EntityManager): Repository<Round> {
    return manager ? manager.getRepository(Round) : this.roundRepo;
  }

  private idempotencyRepository(
    manager?: EntityManager,
  ): Repository<IdempotencyKey> {
    return manager
      ? manager.getRepository(IdempotencyKey)
      : this.idempotencyKeyRepo;
  }

  private deriveCompletedRounds(currentRound: number, totalRounds: number): number {
    return Math.min(Math.max(currentRound - 1, 0), totalRounds);
  }

  private pickRandomIndex(maxExclusive: number): number {
    if (maxExclusive <= 0) {
      this.explicitError(
        'VALIDATION_ERROR',
        'No candidates available for winner selection.',
        HttpStatus.BAD_REQUEST,
      );
    }

    return randomInt(maxExclusive);
  }

  private async ensureSeasonState(
    pool: Pool,
    manager?: EntityManager,
  ): Promise<Season> {
    const seasonRepo = this.seasonRepository(manager);
    const poolRepo = this.poolRepository(manager);

    let latestSeason = await seasonRepo.findOne({
      where: { poolId: pool.id },
      order: { seasonNumber: 'DESC' },
    });

    if (!latestSeason) {
      latestSeason = seasonRepo.create({
        poolId: pool.id,
        seasonNumber: 1,
        status: 'active',
        totalRounds: pool.maxMembers,
        completedRounds: 0,
        contributionAmount: pool.contributionAmount,
        token: pool.token,
        payoutSplitPct: 20,
        cadence: null,
        startedAt: new Date(),
        completedAt: null,
      });
    }

    let changed = false;
    const completedRounds = this.deriveCompletedRounds(
      pool.currentRound,
      latestSeason.totalRounds,
    );

    if (latestSeason.completedRounds !== completedRounds) {
      latestSeason.completedRounds = completedRounds;
      changed = true;
    }

    const shouldComplete = completedRounds >= latestSeason.totalRounds;
    if (shouldComplete && latestSeason.status !== 'completed') {
      latestSeason.status = 'completed';
      latestSeason.completedAt = latestSeason.completedAt ?? new Date();
      changed = true;
    }

    if (!shouldComplete && latestSeason.status === 'completed') {
      latestSeason.status = 'active';
      latestSeason.completedAt = null;
      changed = true;
    }

    if (changed || !latestSeason.id) {
      latestSeason = await seasonRepo.save(latestSeason);
    }

    if (shouldComplete && pool.status !== 'completed') {
      pool.status = 'completed';
      await poolRepo.save(pool);
    }

    return latestSeason;
  }

  private async assertSeasonActive(
    pool: Pool,
    manager?: EntityManager,
  ): Promise<Season> {
    const season = await this.ensureSeasonState(pool, manager);
    if (season.status === 'completed') {
      this.explicitError(
        'SEASON_COMPLETE',
        'Season is completed. Configure next season to continue.',
        HttpStatus.CONFLICT,
      );
    }
    return season;
  }

  private normalizeWallet(wallet: string | undefined | null): string {
    if (!wallet) {
      this.explicitError(
        'NOT_POOL_ADMIN',
        'Only pool admin can perform this action.',
        HttpStatus.FORBIDDEN,
      );
    }
    try {
      return ethers.getAddress(wallet!);
    } catch {
      this.explicitError(
        'NOT_POOL_ADMIN',
        'Only pool admin can perform this action.',
        HttpStatus.FORBIDDEN,
      );
    }
  }

  private assertAdmin(pool: Pool, caller: string): void {
    if (!pool.createdBy) {
      this.explicitError(
        'NOT_POOL_ADMIN',
        'Only pool admin can perform this action.',
        HttpStatus.FORBIDDEN,
      );
    }
    if (pool.createdBy.toLowerCase() !== caller.toLowerCase()) {
      this.explicitError(
        'NOT_POOL_ADMIN',
        'Only pool admin can perform this action.',
        HttpStatus.FORBIDDEN,
      );
    }
  }

  private toRoundStatus(status: string): 'open' | 'closed' | 'winner_picked' {
    if (status === 'winner_picked') return 'winner_picked';
    if (status === 'closed' || status === 'round-closed') return 'closed';
    return 'open';
  }

  private buildStateResponse(pool: Pool, season: Season, round: Round) {
    const winnerVisible = round.status === 'winner_picked';
    return {
      pool: {
        ...pool,
        activeSeasonId: season.id,
        activeRoundId: round.id,
        currentRound: round.roundNumber,
      },
      season: {
        id: season.id,
        seasonNumber: season.seasonNumber,
        status: season.status,
        totalRounds: season.totalRounds,
        completedRounds: season.completedRounds,
      },
      round: {
        id: round.id,
        roundNumber: round.roundNumber,
        status: round.status,
        closedAt: round.closedAt,
        winnerPickedAt: winnerVisible ? round.winnerPickedAt : null,
        winnerWallet: winnerVisible ? round.winnerWallet : null,
      },
    };
  }

  private async ensureActiveRound(
    pool: Pool,
    season: Season,
    manager?: EntityManager,
  ): Promise<Round> {
    const roundRepo = this.roundRepository(manager);
    const poolRepo = this.poolRepository(manager);

    let activeRound: Round | null = null;
    if (pool.activeRoundId) {
      activeRound = await roundRepo.findOne({
        where: { id: pool.activeRoundId, poolId: pool.id, seasonId: season.id },
      });
    }

    if (!activeRound) {
      const targetRoundNumber =
        pool.currentRound && pool.currentRound > 0
          ? pool.currentRound
          : season.completedRounds + 1;
      activeRound = await roundRepo.findOne({
        where: {
          poolId: pool.id,
          seasonId: season.id,
          roundNumber: targetRoundNumber,
        },
      });

      if (!activeRound) {
        activeRound = roundRepo.create({
          poolId: pool.id,
          seasonId: season.id,
          roundNumber: targetRoundNumber,
          status: this.toRoundStatus(pool.status),
          closedAt: null,
          winnerPickedAt: null,
          winnerWallet: null,
        });
        activeRound = await roundRepo.save(activeRound);
      }

      pool.activeRoundId = activeRound.id;
      pool.currentRound = activeRound.roundNumber;
      await poolRepo.save(pool);
    }

    return activeRound;
  }

  async closeActiveRound(poolId: string, callerRaw: string | undefined) {
    const startedAt = Date.now();
    const caller = this.normalizeWallet(callerRaw);

    try {
      const result = await this.dataSource.transaction(async (manager) => {
        const poolRepo = this.poolRepository(manager);
        const roundRepo = this.roundRepository(manager);

        const pool = await poolRepo.findOne({
          where: { id: poolId },
          lock: { mode: 'pessimistic_write' },
        });
        if (!pool) {
          throw new NotFoundException(`Pool ${poolId} not found`);
        }

        this.assertAdmin(pool, caller);
        const season = await this.assertSeasonActive(pool, manager);
        const activeRound = await this.ensureActiveRound(pool, season, manager);
        const lockedRound = await roundRepo.findOne({
          where: { id: activeRound.id },
          lock: { mode: 'pessimistic_write' },
        });

        if (!lockedRound) {
          throw new NotFoundException('Active round not found');
        }

        if (lockedRound.status !== 'open') {
          this.explicitError(
            'ROUND_NOT_OPEN',
            'Active round is not open.',
            HttpStatus.CONFLICT,
          );
        }

        lockedRound.status = 'closed';
        lockedRound.closedAt = new Date();
        await roundRepo.save(lockedRound);

        pool.status = 'round-closed';
        await poolRepo.save(pool);

        return this.buildStateResponse(pool, season, lockedRound);
      });

      this.logPoolLifecycleTelemetry({
        action: 'close_active_round',
        poolId,
        seasonId: result.season?.id,
        roundId: result.round?.id,
        status: 'success',
        durationMs: Date.now() - startedAt,
      });

      return result;
    } catch (error) {
      this.logPoolLifecycleTelemetry({
        action: 'close_active_round',
        poolId,
        status: 'error',
        durationMs: Date.now() - startedAt,
        errorCode:
          error instanceof HttpException
            ? ((error.getResponse() as any)?.code ?? 'HTTP_EXCEPTION')
            : 'UNHANDLED_ERROR',
      });
      throw error;
    }
  }

  async pickWinnerForActiveRound(params: {
    poolId: string;
    mode: 'auto';
    idempotencyKey?: string;
    caller?: string;
  }) {
    const startedAt = Date.now();
    const caller = this.normalizeWallet(params.caller);
    const route = `POST:/pools/${params.poolId}/rounds/active/pick-winner`;
    const idempotencyKey = (params.idempotencyKey ?? '').trim();
    if (!idempotencyKey) {
      this.explicitError(
        'VALIDATION_ERROR',
        'Idempotency-Key header is required.',
        HttpStatus.BAD_REQUEST,
      );
    }

    const requestHash = createHash('sha256')
      .update(JSON.stringify({ mode: params.mode }))
      .digest('hex');

    try {
      const result = await this.dataSource.transaction(async (manager) => {
        const poolRepo = this.poolRepository(manager);
        const seasonRepo = this.seasonRepository(manager);
        const roundRepo = this.roundRepository(manager);
        const memberRepo = manager.getRepository(PoolMember);
        const idempotencyRepo = this.idempotencyRepository(manager);

        const replay = await idempotencyRepo.findOne({
          where: { route, key: idempotencyKey },
        });
        if (replay) {
          if (replay.requestHash !== requestHash) {
            this.explicitError(
              'IDEMPOTENCY_REPLAY_CONFLICT',
              'Idempotency key already used with a different payload.',
              HttpStatus.CONFLICT,
            );
          }
          return replay.responseBody;
        }

        const pool = await poolRepo.findOne({
          where: { id: params.poolId },
          lock: { mode: 'pessimistic_write' },
        });
        if (!pool) {
          throw new NotFoundException(`Pool ${params.poolId} not found`);
        }

        this.assertAdmin(pool, caller);
        const season = await this.assertSeasonActive(pool, manager);
        const activeRound = await this.ensureActiveRound(pool, season, manager);
        const lockedRound = await roundRepo.findOne({
          where: { id: activeRound.id },
          lock: { mode: 'pessimistic_write' },
        });

        if (!lockedRound) {
          throw new NotFoundException('Active round not found');
        }

        if (lockedRound.status === 'open') {
          this.explicitError(
            'WINNER_BEFORE_CLOSE',
            'Close the active round before picking winner.',
            HttpStatus.CONFLICT,
          );
        }

        if (lockedRound.status === 'winner_picked') {
          this.explicitError(
            'ROUND_ALREADY_PICKED',
            'Winner is already picked for the active round.',
            HttpStatus.CONFLICT,
          );
        }

        const members = await memberRepo.find({
          where: { poolId: pool.id },
          order: { joinedAt: 'ASC' },
        });
        if (!members.length) {
          this.explicitError(
            'VALIDATION_ERROR',
            'No pool members available for winner selection.',
            HttpStatus.BAD_REQUEST,
          );
        }

        const priorWinners = await roundRepo.find({
          where: {
            poolId: pool.id,
            seasonId: season.id,
            status: 'winner_picked',
          },
        });
        const priorWinnerWallets = new Set(
          priorWinners
            .map((round) => round.winnerWallet?.toLowerCase())
            .filter((wallet): wallet is string => !!wallet),
        );

        const eligibleMembers = members.filter(
          (member) => !priorWinnerWallets.has(member.walletAddress.toLowerCase()),
        );
        if (!eligibleMembers.length) {
          this.explicitError(
            'NO_ELIGIBLE_WINNER',
            'All members have already won in this season. Configure next season to continue.',
            HttpStatus.CONFLICT,
          );
        }

        const contributionNum =
          parseFloat(pool.contributionAmount?.toString() ?? '0');
        const totalPrize = contributionNum * members.length;

        this.eventsGateway.emitWinnerRandomizing(pool.id, {
          roundNumber: lockedRound.roundNumber,
          eligibleMembers: eligibleMembers.map((m) => m.walletAddress),
          totalPrize,
        });

        const winnerIndex = this.pickRandomIndex(eligibleMembers.length);
        const winnerWallet = ethers.getAddress(
          eligibleMembers[winnerIndex].walletAddress,
        );

        lockedRound.status = 'winner_picked';
        lockedRound.winnerWallet = winnerWallet;
        lockedRound.winnerPickedAt = new Date();
        await roundRepo.save(lockedRound);

        season.completedRounds += 1;

        let responseRound = lockedRound;
        if (season.completedRounds >= season.totalRounds) {
          season.status = 'completed';
          season.completedAt = season.completedAt ?? new Date();
          pool.status = 'completed';
        } else {
          const nextRound = roundRepo.create({
            poolId: pool.id,
            seasonId: season.id,
            roundNumber: lockedRound.roundNumber + 1,
            status: 'open',
            closedAt: null,
            winnerPickedAt: null,
            winnerWallet: null,
          });
          responseRound = await roundRepo.save(nextRound);
          pool.activeRoundId = responseRound.id;
          pool.currentRound = responseRound.roundNumber;
          pool.status = 'active';
        }

        await seasonRepo.save(season);
        pool.activeSeasonId = season.id;
        if (season.status === 'completed') {
          pool.activeRoundId = lockedRound.id;
        }
        await poolRepo.save(pool);

        const response = {
          ...this.buildStateResponse(pool, season, responseRound),
          winner: {
            wallet: winnerWallet,
          },
        };

        await idempotencyRepo.save(
          idempotencyRepo.create({
            route,
            key: idempotencyKey,
            requestHash,
            responseBody: response,
          }),
        );

        return response;
      });

      const resultRound = (result as any)?.round;
      const resultSeason = (result as any)?.season;
      this.logPoolLifecycleTelemetry({
        action: 'pick_winner_active_round',
        poolId: params.poolId,
        seasonId: resultSeason?.id,
        roundId: resultRound?.id,
        status: 'success',
        durationMs: Date.now() - startedAt,
      });

      const winnerResult = (result as any)?.winner;
      if (winnerResult?.wallet) {
        this.eventsGateway.emitWinnerPicked(params.poolId, {
          roundNumber: resultRound?.roundNumber ?? 0,
          winnerWallet: winnerResult.wallet,
          payoutAmount: (result as any)?.pool?.contributionAmount
            ? parseFloat((result as any).pool.contributionAmount) *
              ((result as any).pool?.maxMembers ?? 0)
            : 0,
        });
      }

      return result;
    } catch (error) {
      this.logPoolLifecycleTelemetry({
        action: 'pick_winner_active_round',
        poolId: params.poolId,
        status: 'error',
        durationMs: Date.now() - startedAt,
        errorCode:
          error instanceof HttpException
            ? ((error.getResponse() as any)?.code ?? 'HTTP_EXCEPTION')
            : 'UNHANDLED_ERROR',
      });
      throw error;
    }
  }

  // ─── TX Builder Methods (return unsigned calldata for client-side signing) ───

  /**
   * Build unsigned TX to create a new Equb pool on-chain.
   * The user signs this with their wallet via WalletConnect.
   * All pools use native CTC/tCTC exclusively.
   */
  async buildCreatePool(
    tier: number,
    contributionAmount: string,
    maxMembers: number,
    treasury: string,
    token?: string,
  ): Promise<UnsignedTxDto> {
    const tokenAddress = '0x0000000000000000000000000000000000000000';
    this.logger.log(
      `Building createPool TX: tier=${tier}, contribution=${contributionAmount}, maxMembers=${maxMembers}, token=${tokenAddress}`,
    );

    // Validate params that would cause contract revert (so user gets a clear error instead of failed tx)
    const contributionBig = BigInt(contributionAmount);
    if (contributionBig <= 0n) {
      throw new BadRequestException(
        'Invalid contribution: amount must be greater than 0 (contract: "invalid contribution")',
      );
    }
    if (maxMembers <= 1) {
      throw new BadRequestException(
        'Invalid members: maxMembers must be greater than 1 (contract: "invalid members")',
      );
    }
    const zeroAddr = '0x0000000000000000000000000000000000000000';
    if (!treasury || treasury.toLowerCase() === zeroAddr.toLowerCase()) {
      throw new BadRequestException(
        'Invalid treasury: treasury address cannot be zero (contract: "invalid treasury")',
      );
    }

    const tierRegistry = this.web3Service.getTierRegistry();
    const config = await tierRegistry.tierConfig(tier);
    if (!config.enabled) {
      throw new BadRequestException(
        `Tier ${tier} is disabled on-chain. The network admin must call configureTier to enable this tier (contract: "tier disabled")`,
      );
    }
    const maxPoolSize = BigInt(config.maxPoolSize.toString());
    if (contributionBig > maxPoolSize) {
      throw new BadRequestException(
        `Contribution amount (${contributionAmount}) exceeds tier ${tier} max pool size (${config.maxPoolSize}) (contract: "pool size exceeds tier")`,
      );
    }

    const equbPool = this.web3Service.getEqubPool();
    const wantsTokenPool = tokenAddress.toLowerCase() != zeroAddr.toLowerCase();
    const v2Sig = 'createPool(uint8,uint256,uint256,address,address)';
    const legacySig = 'createPool(uint8,uint256,uint256,address)';
    const v2Selector = ethers.id(v2Sig).slice(2, 10).toLowerCase();
    const equbPoolAddress = await equbPool.getAddress();
    const code = (
      await this.web3Service.getProvider().getCode(equbPoolAddress)
    ).toLowerCase();
    const supportsV2 = code.includes(v2Selector);

    let data: string;
    if (supportsV2) {
      data = equbPool.interface.encodeFunctionData(
        v2Sig,
        [tier, contributionAmount, maxMembers, treasury, tokenAddress],
      );
    } else {
      if (wantsTokenPool) {
        throw new BadRequestException(
          `Deployed EQUB_POOL_ADDRESS (${equbPoolAddress}) is a legacy EqubPool and does not support token pools (missing createPool(uint8,uint256,uint256,address,address)). Redeploy v2 EqubPool and update EQUB_POOL_ADDRESS.`,
        );
      }

      this.logger.warn(
        `Deployed EQUB_POOL_ADDRESS (${equbPoolAddress}) does not expose createPool(uint8,uint256,uint256,address,address); falling back to legacy createPool(uint8,uint256,uint256,address).`,
      );
      data = equbPool.interface.encodeFunctionData(
        legacySig,
        [tier, contributionAmount, maxMembers, treasury],
      );
    }
    const to = equbPoolAddress;

    return this.web3Service.buildUnsignedTx(to, data, '0', '500000');
  }

  /**
   * Build unsigned TX to join an existing pool on-chain.
   */
  async buildJoinPool(
    onChainPoolId: number,
    caller?: string,
  ): Promise<UnsignedTxDto> {
    this.logger.log(`Building joinPool TX: poolId=${onChainPoolId}`);

    if (caller) {
      if (!ethers.isAddress(caller)) {
        throw new BadRequestException('Invalid caller address');
      }
      const normalizedCaller = ethers.getAddress(caller);
      const identityRegistry = this.web3Service.getIdentityRegistry();
      const identity = await identityRegistry.identityOf(normalizedCaller);
      if (identity === ethers.ZeroHash) {
        throw new BadRequestException(
          'Wallet identity is not bound on-chain. Complete wallet binding (store on-chain) before joining a pool.',
        );
      }
    }

    const equbPool = this.web3Service.getEqubPool();
    const data = equbPool.interface.encodeFunctionData('joinPool', [
      onChainPoolId,
    ]);
    const to = await equbPool.getAddress();

    return this.web3Service.buildUnsignedTx(to, data, '0', '200000');
  }

  /**
   * Build unsigned TX to contribute to a pool round on-chain.
   * All pools use native CTC/tCTC -- value equals the contribution amount.
   */
  async buildContribute(
    onChainPoolId: number,
    contributionAmount: string,
    tokenAddress?: string,
  ): Promise<UnsignedTxDto> {
    this.logger.log(
      `Building contribute TX: poolId=${onChainPoolId}, amount=${contributionAmount}, native=true`,
    );

    const equbPool = this.web3Service.getEqubPool();
    const equbPoolAddress = await equbPool.getAddress();

    const data = equbPool.interface.encodeFunctionData('contribute', [
      onChainPoolId,
    ]);
    const to = equbPoolAddress;

    const value = await this.resolveNativeContributionValue(onChainPoolId, contributionAmount);

    return this.web3Service.buildUnsignedTx(to, data, value, '200000');
  }

  private async resolveNativeContributionValue(
    onChainPoolId: number,
    fallbackContributionAmount: string,
  ): Promise<string> {
    const pool = await this.poolRepo.findOne({ where: { onChainPoolId } });
    if (!pool?.txHash) {
      return fallbackContributionAmount;
    }

    try {
      const tx = await this.web3Service.getProvider().getTransaction(pool.txHash);
      if (!tx?.data) {
        return fallbackContributionAmount;
      }

      const equbPool = this.web3Service.getEqubPool();
      const parsed = equbPool.interface.parseTransaction({ data: tx.data });
      if (!parsed?.args || parsed.args.length < 2) {
        return fallbackContributionAmount;
      }

      const amountArg = parsed.args[1];
      const amount =
        typeof amountArg === 'bigint'
          ? amountArg.toString()
          : String((amountArg as any)?.toString?.() ?? amountArg);

      if (amount && /^\d+$/.test(amount)) {
        return amount;
      }

      return fallbackContributionAmount;
    } catch (e) {
      this.logger.warn(
        `Could not resolve native contribution amount from create tx for onChainPoolId=${onChainPoolId}: ${e}`,
      );
      return fallbackContributionAmount;
    }
  }

  /**
   * Build unsigned TX to approve the EqubPool contract to spend ERC-20 tokens.
   * Must be signed and sent BEFORE contributing to an ERC-20 pool.
   */
  async buildApproveToken(
    tokenAddress: string,
    amount: string,
  ): Promise<UnsignedTxDto> {
    this.logger.log(
      `Building approve TX: token=${tokenAddress}, amount=${amount}`,
    );

    const { ethers: ethersLib } = await import('ethers');
    const erc20Iface = new ethersLib.Interface([
      'function approve(address spender, uint256 amount) external returns (bool)',
      'function decimals() external view returns (uint8)',
    ]);

    const equbPool = this.web3Service.getEqubPool();
    const equbPoolAddress = await equbPool.getAddress();

    // Resolve the amount to wei. The frontend may send a human-readable
    // value (e.g. "2.0") or already-wei integer string (e.g. "2000000").
    let amountWei: string;
    if (/^\d+$/.test(amount)) {
      amountWei = amount;
    } else {
      let decimals = 18;
      try {
        const tokenContract = new ethersLib.Contract(
          tokenAddress,
          erc20Iface,
          this.web3Service.getProvider(),
        );
        decimals = Number(await tokenContract.decimals());
      } catch {
        this.logger.warn(
          `Could not read decimals for ${tokenAddress}, defaulting to 18`,
        );
      }
      amountWei = ethersLib.parseUnits(amount, decimals).toString();
    }

    const data = erc20Iface.encodeFunctionData('approve', [
      equbPoolAddress,
      amountWei,
    ]);

    return this.web3Service.buildUnsignedTx(
      tokenAddress,
      data,
      '0',
      '60000',
    );
  }

  /**
   * Build unsigned TX to close a round on-chain.
   */
  async buildCloseRound(onChainPoolId: number): Promise<UnsignedTxDto> {
    this.logger.log(`Building closeRound TX: poolId=${onChainPoolId}`);

    const pool = await this.poolRepo.findOne({ where: { onChainPoolId } });
    if (pool) {
      await this.assertSeasonActive(pool);
    }

    const equbPool = this.web3Service.getEqubPool();
    const data = equbPool.interface.encodeFunctionData('closeRound', [
      onChainPoolId,
    ]);
    const to = await equbPool.getAddress();

    return this.web3Service.buildUnsignedTx(to, data, '0', '500000');
  }

  /**
   * Build unsigned TX to schedule a payout stream on-chain.
   */
  async buildScheduleStream(
    onChainPoolId: number,
    beneficiary: string,
    total: string,
    upfrontPercent: number,
    totalRounds: number,
  ): Promise<UnsignedTxDto> {
    this.logger.log(
      `Building schedulePayoutStream TX: poolId=${onChainPoolId}, beneficiary=${beneficiary}`,
    );

    const equbPool = this.web3Service.getEqubPool();
    const data = equbPool.interface.encodeFunctionData(
      'schedulePayoutStream',
      [onChainPoolId, beneficiary, total, upfrontPercent, totalRounds],
    );
    const to = await equbPool.getAddress();

    return this.web3Service.buildUnsignedTx(to, data, '0', '400000');
  }

  // ─── Read Methods (from DB cache, populated by Event Indexer) ───────────────

  /** Backfill treasury and createdBy from createPool tx when missing. */
  private async backfillPoolFromCreationTx(pool: Pool): Promise<void> {
    if (!pool.txHash) return;
    const zero = '0x0000000000000000000000000000000000000000';
    const needsTreasury = pool.treasury === zero;
    const needsCreatedBy = !pool.createdBy;
    if (!needsTreasury && !needsCreatedBy) return;
    try {
      const provider = this.web3Service.getProvider();
      const equbPool = this.web3Service.getEqubPool();
      const tx = await provider.getTransaction(pool.txHash);
      if (!tx) return;
      let updated = false;
      if (needsCreatedBy && tx.from) {
        const { ethers } = await import('ethers');
        pool.createdBy = ethers.getAddress(tx.from);
        updated = true;
        this.logger.log(`Backfilled createdBy for pool ${pool.id}: ${pool.createdBy}`);
      }
      if (needsTreasury && tx.data) {
        const parsed = equbPool.interface.parseTransaction({ data: tx.data });
        if (parsed?.args && parsed.args.length >= 4) {
          const t = parsed.args[3];
          const treasury =
            typeof t === 'string' && t.startsWith('0x')
              ? t
              : String((t as any)?.toString?.() ?? t);
          if (treasury && treasury !== zero) {
            pool.treasury = treasury;
            updated = true;
            this.logger.log(`Backfilled treasury for pool ${pool.id}: ${treasury}`);
          }
        }
      }
      if (updated) await this.poolRepo.save(pool);
    } catch (e) {
      this.logger.warn(`Could not backfill pool ${pool.id} from tx: ${e}`);
    }
  }

  async getEligibleWinners(poolId: string) {
    const pool = await this.poolRepo.findOne({
      where: { id: poolId },
      relations: ['members'],
    });
    if (!pool) {
      throw new NotFoundException(`Pool ${poolId} not found`);
    }

    const season = await this.ensureSeasonState(pool);
    const members = pool.members ?? [];
    if (!members.length) {
      return { eligible: [], roundNumber: pool.currentRound ?? 1 };
    }

    const priorWinners = await this.roundRepo.find({
      where: {
        poolId: pool.id,
        seasonId: season.id,
        status: 'winner_picked' as any,
      },
    });
    const priorWinnerWallets = new Set(
      priorWinners
        .map((r) => r.winnerWallet?.toLowerCase())
        .filter((w): w is string => !!w),
    );

    const eligible = members
      .filter((m) => !priorWinnerWallets.has(m.walletAddress.toLowerCase()))
      .map((m) => m.walletAddress);

    return {
      eligible,
      roundNumber: pool.currentRound ?? 1,
      seasonNumber: season.seasonNumber,
    };
  }

  async getPool(poolId: string) {
    const pool = await this.poolRepo.findOne({
      where: { id: poolId },
      relations: ['members', 'contributions'],
    });
    if (!pool) {
      throw new NotFoundException(`Pool ${poolId} not found`);
    }
    await this.backfillPoolFromCreationTx(pool);

    const zeroAddr = '0x0000000000000000000000000000000000000000';
    if (pool.token && pool.token !== zeroAddr) {
      pool.token = zeroAddr;
      await this.poolRepo.save(pool);
    }
    const season = await this.ensureSeasonState(pool);
    const activeRound = await this.ensureActiveRound(pool, season);
    const currentRoundStatus =
      activeRound.status === 'winner_picked'
        ? 'winner_picked'
        : activeRound.status === 'closed'
          ? 'closed'
          : 'open';
    pool.activeSeasonId = season.id;
    pool.activeRoundId = activeRound.id;
    pool.currentRound = activeRound.roundNumber;
    await this.poolRepo.save(pool);

    const winnerVisible = activeRound.status === 'winner_picked';

    return {
      ...pool,
      createdBy: pool.createdBy ?? null,
      currentRoundStatus,
      currentRoundWinner: winnerVisible ? activeRound.winnerWallet : null,
      season: {
        id: season.id,
        seasonNumber: season.seasonNumber,
        status: season.status,
        totalRounds: season.totalRounds,
        completedRounds: season.completedRounds,
        contributionAmount: season.contributionAmount,
        token: season.token,
        payoutSplitPct: season.payoutSplitPct,
        cadence: season.cadence,
        startedAt: season.startedAt,
        completedAt: season.completedAt,
      },
      activeRound: {
        id: activeRound.id,
        roundNumber: activeRound.roundNumber,
        status: activeRound.status,
        closedAt: activeRound.closedAt,
        winnerPickedAt: winnerVisible ? activeRound.winnerPickedAt : null,
        winnerWallet: winnerVisible ? activeRound.winnerWallet : null,
      },
      seasonComplete: season.status === 'completed',
    };
  }

  /**
   * Get the token info for a pool.
   * This app exclusively uses native CTC/tCTC for all pool operations.
   */
  async getPoolToken(poolId: string) {
    const pool = await this.poolRepo.findOne({ where: { id: poolId } });
    if (!pool) {
      throw new NotFoundException(`Pool ${poolId} not found`);
    }

    const nativeSym = this.web3Service.getChainId() === 102030 ? 'CTC' : 'tCTC';

    return {
      poolId: pool.id,
      isErc20: false,
      token: null,
      nativeSymbol: nativeSym,
      message: `This pool uses native ${nativeSym} for contributions`,
    };
  }

  async listPools(tier?: number) {
    const tierNum =
      tier !== null && tier !== undefined ? Number(tier) : undefined;
    const where =
      tierNum !== undefined && !isNaN(tierNum) ? { tier: tierNum } : {};
    return this.poolRepo.find({
      where,
      relations: ['members'],
      order: { createdAt: 'DESC' },
    });
  }

  // ─── Legacy DB Methods (kept for dev/test; indexer replaces these in prod) ──

  async createPool(
    tier: number,
    contributionAmount: string,
    maxMembers: number,
    treasury: string,
    token?: string,
  ) {
    const tokenAddress = '0x0000000000000000000000000000000000000000';

    this.logger.log(
      `Creating pool (DB-only): tier=${tier}, contribution=${contributionAmount}, maxMembers=${maxMembers}, token=${tokenAddress}`,
    );

    const pool = this.poolRepo.create({
      tier,
      contributionAmount,
      maxMembers,
      treasury,
      token: tokenAddress,
      currentRound: 1,
      status: 'pending-onchain',
    });

    const saved = await this.poolRepo.save(pool);

    return {
      id: saved.id,
      tier: saved.tier,
      contributionAmount: saved.contributionAmount,
      maxMembers: saved.maxMembers,
      treasury: saved.treasury,
      token: saved.token,
      status: saved.status,
    };
  }

  /**
   * Create pool from a mined createPool tx. Waits for receipt, parses PoolCreated,
   * and creates the pool with onChainPoolId and status active immediately.
   */
  async createPoolFromCreationTx(txHash: string): Promise<Pool> {
    const hash = txHash.trim();
    this.logger.log(`createPoolFromCreationTx: waiting for receipt txHash=${hash}`);
    const provider = this.web3Service.getProvider();
    const equbPool = this.web3Service.getEqubPool();
    const equbPoolAddress = (await equbPool.getAddress()).toLowerCase();
    const tx = await provider.getTransaction(hash);
    const createdBy = tx?.from ? ethers.getAddress(tx.from) : null;

    // Wait for receipt (poll up to ~2 min)
    let receipt: ethers.TransactionReceipt | null = null;
    for (let i = 0; i < 24; i++) {
      await new Promise((r) => setTimeout(r, 5000));
      receipt = await provider.getTransactionReceipt(hash);
      if (receipt && receipt.blockNumber) break;
    }
    if (!receipt || !receipt.blockNumber) {
      throw new BadRequestException('Transaction not mined yet. Try again in a moment.');
    }
    if (receipt.status === 0) {
      if (createdBy) {
        this.notifications
          .create(
            createdBy,
            'pool_created',
            'Pool Creation Failed',
            'Pool creation transaction reverted on-chain.',
            {
              txHash: hash.toLowerCase(),
              status: 'failed',
              kind: 'transaction',
              idempotencyKey: `pool_created_failed:${createdBy.toLowerCase()}:${hash.toLowerCase()}`,
            },
          )
          .catch((error) => {
            this.logger.warn(`Failed to emit pool_created failure notification: ${error?.message ?? error}`);
          });
      }
      throw new BadRequestException(
        'Transaction reverted on-chain. Pool was not created. If your EqubPool address points to an older contract version, update EQUB_POOL_ADDRESS (and related contracts) in .env and restart backend.',
      );
    }
    if (!tx) throw new BadRequestException('Transaction not found');

    let treasury = '0x0000000000000000000000000000000000000000';
    if (tx.data) {
      const parsed = equbPool.interface.parseTransaction({ data: tx.data });
      if (parsed?.args && parsed.args.length >= 4) {
        const t = parsed.args[3];
        const addr = typeof t === 'string' && t.startsWith('0x') ? t : String((t as any)?.toString?.() ?? t);
        if (addr && addr !== '0x0000000000000000000000000000000000000000') treasury = ethers.getAddress(addr);
      }
    }

    const iface = equbPool.interface;
    const zeroAddr = '0x0000000000000000000000000000000000000000';

    let poolId: bigint | undefined;
    let contributionAmount: bigint | undefined;
    let maxMembers: bigint | undefined;
    let token: string = zeroAddr;

    // Try v2 PoolCreated(poolId, contributionAmount, maxMembers, token) first.
    const v2Topic = iface.getEvent('PoolCreated')?.topicHash;
    const v2Log = receipt.logs.find(
      (l) => l.address.toLowerCase() === equbPoolAddress && (v2Topic && l.topics[0] === v2Topic),
    );
    if (v2Log) {
      const decoded = iface.parseLog({
        topics: v2Log.topics as string[],
        data: v2Log.data,
      });
      if (decoded && decoded.name === 'PoolCreated') {
        [poolId, contributionAmount, maxMembers, token] = decoded.args as unknown as [
          bigint,
          bigint,
          bigint,
          string,
        ];
      }
    }

    // Fallback for legacy deployment:
    // PoolCreated(poolId, contributionAmount, maxMembers) without token arg.
    if (poolId === undefined) {
      const legacyEventIface = new ethers.Interface([
        'event PoolCreated(uint256 indexed poolId, uint256 contributionAmount, uint256 maxMembers)',
      ]);
      const legacyTopic = legacyEventIface.getEvent('PoolCreated')?.topicHash;
      const legacyLog = receipt.logs.find(
        (l) =>
          l.address.toLowerCase() === equbPoolAddress &&
          (legacyTopic && l.topics[0] === legacyTopic),
      );
      if (legacyLog) {
        const decodedLegacy = legacyEventIface.parseLog({
          topics: legacyLog.topics as string[],
          data: legacyLog.data,
        });
        if (decodedLegacy && decodedLegacy.name === 'PoolCreated') {
          [poolId, contributionAmount, maxMembers] = decodedLegacy.args as unknown as [
            bigint,
            bigint,
            bigint,
          ];
        }
      }
    }

    if (
      poolId === undefined ||
      contributionAmount === undefined ||
      maxMembers === undefined
    ) {
      throw new BadRequestException(
        'PoolCreated event not found or could not be parsed from transaction logs. Ensure EQUB_POOL_ADDRESS matches the deployed EqubPool contract for this tx.',
      );
    }

    const onChainPoolId = Number(poolId);
    const existing = await this.poolRepo.findOne({ where: { onChainPoolId } });
    if (existing) return existing;

    // Convert wei to ether (18 decimals) for DB storage — the column is decimal(36,18)
    const contributionWei = contributionAmount.toString();
    const contributionEther = ethers.formatUnits(contributionWei, 18);

    const pool = this.poolRepo.create({
      onChainPoolId,
      tier: 0,
      contributionAmount: contributionEther,
      maxMembers: Number(maxMembers),
      currentRound: 1,
      treasury,
      createdBy,
      token: zeroAddr,
      status: 'active',
      txHash: hash.toLowerCase(),
    });
    const saved = await this.poolRepo.save(pool);
    this.logger.log(`createPoolFromCreationTx: created pool id=${saved.id}, onChainPoolId=${onChainPoolId}, contribution=${contributionEther} CTC`);

    try {
      const onChainRules = await this.rulesService.fetchRulesFromChain(onChainPoolId);
      if (onChainRules) {
        await this.rulesService.upsertRulesFromChain(saved.id, onChainPoolId, onChainRules);
      }
    } catch (e) {
      this.logger.warn(`Could not fetch rules for pool ${saved.id}: ${e?.message ?? e}`);
    }

    if (createdBy) {
      this.notifications
        .create(
          createdBy,
          'pool_created',
          'Pool Created',
          `Your pool was created successfully (Pool #${onChainPoolId}).`,
          {
            poolId: saved.id,
            onChainPoolId,
            contributionAmount: contributionEther,
            maxMembers: Number(maxMembers),
            token: pool.token,
            txHash: hash.toLowerCase(),
            idempotencyKey: `pool_created:${createdBy.toLowerCase()}:${onChainPoolId}:${hash.toLowerCase()}`,
          },
        )
        .catch((error) => {
          this.logger.warn(`Failed to emit pool_created notification: ${error?.message ?? error}`);
        });
    }

    return saved;
  }

  async joinPool(poolId: string, walletAddress: string) {
    this.logger.log(`User ${walletAddress} joining pool ${poolId}`);

    const pool = await this.poolRepo.findOne({
      where: { id: poolId },
      relations: ['members'],
    });
    if (!pool) {
      throw new NotFoundException(`Pool ${poolId} not found`);
    }

    if (pool.members.length >= pool.maxMembers) {
      throw new ConflictException('Pool is full');
    }

    const existingMember = await this.memberRepo.findOne({
      where: { poolId, walletAddress },
    });
    if (existingMember) {
      throw new ConflictException('Already a member of this pool');
    }

    const member = this.memberRepo.create({ poolId, walletAddress });
    await this.memberRepo.save(member);

    return {
      poolId,
      walletAddress,
      status: 'joined',
      memberCount: pool.members.length + 1,
    };
  }

  async recordContribution(
    poolId: string,
    walletAddress: string,
    round: number,
  ) {
    this.logger.log(
      `Recording contribution: pool=${poolId}, wallet=${walletAddress}, round=${round}`,
    );

    const pool = await this.poolRepo.findOne({ where: { id: poolId } });
    if (!pool) {
      throw new NotFoundException(`Pool ${poolId} not found`);
    }

    let isMember = await this.memberRepo.findOne({
      where: { poolId, walletAddress },
    });
    if (!isMember) {
      this.logger.log(
        `Recording contribution: wallet ${walletAddress} not in pool_members (e.g. joined on-chain); adding member for pool ${poolId}`,
      );
      const member = this.memberRepo.create({ poolId, walletAddress });
      await this.memberRepo.save(member);
      isMember = member;
    }

    const existing = await this.contributionRepo.findOne({
      where: { poolId, walletAddress, round },
    });
    if (existing) {
      throw new ConflictException('Already contributed for this round');
    }

    const contribution = this.contributionRepo.create({
      poolId,
      walletAddress,
      round,
      status: 'pending-onchain',
    });
    await this.contributionRepo.save(contribution);

    return {
      poolId,
      walletAddress,
      round,
      status: 'pending-onchain',
    };
  }

  async closeRound(poolId: string, round: number) {
    this.logger.log(`Closing round ${round} for pool ${poolId}`);

    const pool = await this.poolRepo.findOne({
      where: { id: poolId },
      relations: ['members'],
    });
    if (!pool) {
      throw new NotFoundException(`Pool ${poolId} not found`);
    }

    await this.assertSeasonActive(pool);

    const contributions = await this.contributionRepo.find({
      where: { poolId, round },
    });
    const contributedAddresses = new Set(
      contributions.map((c) => c.walletAddress),
    );

    const contributors: string[] = [];
    const defaulters: string[] = [];

    for (const member of pool.members) {
      if (contributedAddresses.has(member.walletAddress)) {
        contributors.push(member.walletAddress);
      } else {
        defaulters.push(member.walletAddress);
      }
    }

    pool.currentRound = round + 1;
    const seasonCompleted = pool.currentRound > pool.maxMembers;
    pool.status = seasonCompleted ? 'completed' : 'round-closed';
    await this.poolRepo.save(pool);
    const season = await this.ensureSeasonState(pool);

    return {
      poolId,
      round,
      contributors,
      defaulters,
      nextRound: round + 1,
      status: seasonCompleted ? 'completed' : 'round-closed',
      season,
    };
  }

  async createNextSeason(
    poolId: string,
    dto: {
      caller: string;
      contributionAmount?: string;
      token?: string;
      payoutSplitPct?: number;
      cadence?: string;
    },
  ) {
    const startedAt = Date.now();

    try {
      const result = await this.dataSource.transaction(async (manager) => {
        const poolRepo = this.poolRepository(manager);
        const seasonRepo = this.seasonRepository(manager);

        const pool = await poolRepo.findOne({ where: { id: poolId } });
        if (!pool) {
          throw new NotFoundException(`Pool ${poolId} not found`);
        }

        if (!pool.createdBy) {
          this.explicitError(
            'NOT_POOL_ADMIN',
            'Only pool admin can create a new season.',
            HttpStatus.FORBIDDEN,
          );
        }

        const caller = ethers.getAddress(dto.caller);
        if (caller.toLowerCase() !== pool.createdBy.toLowerCase()) {
          this.explicitError(
            'NOT_POOL_ADMIN',
            'Only pool admin can create a new season.',
            HttpStatus.FORBIDDEN,
          );
        }

        const latestSeason = await this.ensureSeasonState(pool, manager);
        if (latestSeason.status !== 'completed') {
          this.explicitError(
            'SEASON_NOT_COMPLETED',
            'Current season must be completed before creating the next season.',
            HttpStatus.CONFLICT,
          );
        }

        const contributionAmount =
          dto.contributionAmount ?? latestSeason.contributionAmount ?? pool.contributionAmount;
        const token = '0x0000000000000000000000000000000000000000';
        const payoutSplitPct = dto.payoutSplitPct ?? latestSeason.payoutSplitPct ?? 20;
        const cadence = dto.cadence ?? latestSeason.cadence ?? null;

        const newSeason = seasonRepo.create({
          poolId: pool.id,
          seasonNumber: latestSeason.seasonNumber + 1,
          status: 'active',
          totalRounds: pool.maxMembers,
          completedRounds: 0,
          contributionAmount,
          token,
          payoutSplitPct,
          cadence,
          startedAt: new Date(),
          completedAt: null,
        });
        const savedSeason = await seasonRepo.save(newSeason);

        pool.currentRound = 1;
        pool.status = 'active';
        pool.contributionAmount = contributionAmount;
        pool.token = token;
        const savedPool = await poolRepo.save(pool);

        return {
          pool: savedPool,
          season: savedSeason,
          round: {
            roundNumber: 1,
            status: 'open',
          },
        };
      });

      this.logPoolLifecycleTelemetry({
        action: 'create_next_season',
        poolId,
        seasonId: (result as any)?.season?.id,
        status: 'success',
        durationMs: Date.now() - startedAt,
      });

      return result;
    } catch (error) {
      this.logPoolLifecycleTelemetry({
        action: 'create_next_season',
        poolId,
        status: 'error',
        durationMs: Date.now() - startedAt,
        errorCode:
          error instanceof HttpException
            ? ((error.getResponse() as any)?.code ?? 'HTTP_EXCEPTION')
            : 'UNHANDLED_ERROR',
      });
      throw error;
    }
  }

  async scheduleStream(
    poolId: string,
    beneficiary: string,
    total: string,
    upfrontPercent: number,
    totalRounds: number,
  ) {
    this.logger.log(
      `Scheduling payout stream: pool=${poolId}, beneficiary=${beneficiary}`,
    );

    const pool = await this.poolRepo.findOne({ where: { id: poolId } });
    if (!pool) {
      throw new NotFoundException(`Pool ${poolId} not found`);
    }

    if (upfrontPercent > 30) {
      throw new BadRequestException('Upfront percent cannot exceed 30%');
    }

    const totalNum = BigInt(total);
    const upfront = (totalNum * BigInt(upfrontPercent)) / BigInt(100);
    const remaining = totalNum - upfront;
    const roundAmount = remaining / BigInt(totalRounds);

    const stream = this.payoutStreamRepo.create({
      poolId,
      beneficiary,
      total,
      upfrontPercent,
      roundAmount: roundAmount.toString(),
      totalRounds,
      releasedRounds: 0,
      released: upfront.toString(),
      frozen: false,
    });
    await this.payoutStreamRepo.save(stream);

    return {
      poolId,
      beneficiary,
      total,
      upfrontPercent,
      roundAmount: roundAmount.toString(),
      totalRounds,
      status: 'stream-created',
    };
  }

  /**
   * Build unsigned transactions for selecting a winner and scheduling payout.
    * Winner selection is chain-authoritative (set on closeRound in EqubPool).
    * Flow:
    *  1) Call once to get closeTx and sign/send it.
    *  2) After close tx confirms, call again to receive scheduleTx with on-chain winner.
   */
  async buildSelectWinner(
    poolId: string,
    dto: {
      phase?: 'auto' | 'close' | 'schedule';
      winner?: string;
      total: string;
      upfrontPercent: number;
      totalRounds: number;
      caller?: string;
    },
  ) {
    const pool = await this.poolRepo.findOne({ where: { id: poolId }, relations: ['members'] });
    if (!pool) throw new NotFoundException(`Pool ${poolId} not found`);
    await this.assertSeasonActive(pool);

    // Verify caller is pool creator
    if (!pool.createdBy) throw new BadRequestException('Pool creator not known; cannot authorize winner selection');
    if (!dto.caller) throw new BadRequestException('Caller address required');
    const { ethers } = await import('ethers');
    const callerNorm = ethers.getAddress(dto.caller);
    if (callerNorm.toLowerCase() !== pool.createdBy.toLowerCase()) {
      throw new BadRequestException('Only pool creator may select the winner');
    }

    if (!pool.onChainPoolId) throw new BadRequestException('Pool not linked to on-chain pool');

    const phase = dto.phase ?? 'auto';

    const shouldBuildCloseTx = phase !== 'schedule';
    const shouldAttemptSchedule = phase !== 'close';

    if (shouldBuildCloseTx) {
      this.enforceSelectWinnerCloseCooldown(poolId, callerNorm);
    }

    let closeTx: UnsignedTxDto | null = null;
    if (shouldBuildCloseTx) {
      closeTx = await this.buildCloseRound(pool.onChainPoolId);
    }

    if (!shouldAttemptSchedule) {
      return {
        closeTx,
        scheduleTx: null,
        winner: null,
        round: pool.currentRound,
        warning: null,
        nextAction: 'sign_close_tx_then_requery_for_schedule',
      };
    }

    const equbPool = this.web3Service.getEqubPool();
    const zero = '0x0000000000000000000000000000000000000000';

    let closedRound = 0;
    let winnerRaw: string = zero;
    let winnerViewUnavailable = false;

    try {
      const [closedRoundRaw, lastWinnerRaw] =
        await equbPool.rotatingWinnerForLastClosedRound(pool.onChainPoolId);
      closedRound = Number(closedRoundRaw);
      winnerRaw = typeof lastWinnerRaw === 'string' ? lastWinnerRaw : String(lastWinnerRaw);
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      const likelyNotReady =
        msg.includes('require(false)') || msg.includes('no data present');

      if (!likelyNotReady) {
        winnerViewUnavailable = true;
        this.logger.warn(
          `rotatingWinnerForLastClosedRound unavailable/reverted for poolId=${pool.onChainPoolId}: ${e}`,
        );
      }

      // Fallback for contracts exposing roundWinner/currentRound but not rotatingWinnerForLastClosedRound.
      try {
        const currentRoundRaw = await equbPool.currentRound(pool.onChainPoolId);
        const candidateRound = Number(currentRoundRaw) - 1;
        if (candidateRound > 0) {
          const candidateWinner = await equbPool.roundWinner(
            pool.onChainPoolId,
            candidateRound,
          );
          closedRound = candidateRound;
          winnerRaw =
            typeof candidateWinner === 'string'
              ? candidateWinner
              : String(candidateWinner);
          winnerViewUnavailable = false;
        }
      } catch (fallbackErr) {
        const fallbackMsg =
          fallbackErr instanceof Error ? fallbackErr.message : String(fallbackErr);
        const likelyNotReady =
          fallbackMsg.includes('require(false)') ||
          fallbackMsg.includes('no data present');
        if (!likelyNotReady) {
          this.logger.warn(
            `roundWinner/currentRound fallback unavailable for poolId=${pool.onChainPoolId}: ${fallbackErr}`,
          );
        }
      }
    }

    let scheduleTx: UnsignedTxDto | null = null;
    let winner: string | null = null;

    if (closedRound > 0 && typeof winnerRaw === 'string' && winnerRaw.toLowerCase() !== zero.toLowerCase()) {
      let alreadyScheduled = false;
      try {
        alreadyScheduled = await equbPool.winnerScheduled(
          pool.onChainPoolId,
          closedRound,
        );
      } catch (e) {
        this.logger.warn(
          `winnerScheduled unavailable/reverted for poolId=${pool.onChainPoolId}, round=${closedRound}: ${e}`,
        );
      }

      if (!alreadyScheduled) {
        winner = ethers.getAddress(winnerRaw);

        if (dto.winner) {
          const provided = ethers.getAddress(dto.winner);
          if (provided.toLowerCase() !== winner.toLowerCase()) {
            throw new BadRequestException(
              `Provided winner does not match on-chain selected winner for closed round ${closedRound}`,
            );
          }
        }

        scheduleTx = await this.buildScheduleStream(
          pool.onChainPoolId,
          winner,
          dto.total,
          dto.upfrontPercent,
          dto.totalRounds,
        );
      }
    }

    return {
      closeTx,
      scheduleTx,
      winner,
      round: closedRound || pool.currentRound,
      warning:
        winnerViewUnavailable && !scheduleTx
          ? 'Winner read method is unavailable on deployed EqubPool. Close the round and requery. If scheduleTx never appears, deploy the latest EqubPool or use manual winner flow.'
          : null,
      nextAction: scheduleTx
        ? 'sign_schedule_tx'
        : winnerViewUnavailable
          ? 'sign_close_tx_then_requery_or_upgrade_contract'
          : phase === 'schedule'
            ? 'await_close_confirmation_then_requery_schedule'
            : 'sign_close_tx_then_requery_for_schedule',
    };
  }

  // ─── Admin: Configure Tiers ─────────────────────────────────────────────────

  /**
   * Enable tiers 1-3 on-chain via the deployer signer.
   * Each tier gets a generous maxPoolSize so dev/test pools aren't rejected.
   */
  async configureTiersOnChain(): Promise<{ configured: number[]; txHashes: string[] }> {
    const deployer = this.web3Service.getDeployerSigner();
    if (!deployer) {
      throw new BadRequestException(
        'Deployer signer not configured. Set DEPLOYER_PRIVATE_KEY in .env',
      );
    }

    const tierRegistryAddr =
      this.web3Service.getTierRegistry().target?.toString();
    if (
      !tierRegistryAddr ||
      tierRegistryAddr === '0x0000000000000000000000000000000000000000'
    ) {
      throw new BadRequestException(
        'TierRegistry contract address is not configured',
      );
    }

    const tierRegistry = this.web3Service.getTierRegistry().connect(deployer) as ethers.Contract;

    const tiers = [
      { tier: 1, maxPoolSize: ethers.parseEther('100'), collateralRateBps: 0, enabled: true },
      { tier: 2, maxPoolSize: ethers.parseEther('1000'), collateralRateBps: 500, enabled: true },
      { tier: 3, maxPoolSize: ethers.parseEther('10000'), collateralRateBps: 1000, enabled: true },
    ];

    const configured: number[] = [];
    const txHashes: string[] = [];

    for (const t of tiers) {
      try {
        const existing = await this.web3Service.getTierRegistry().tierConfig(t.tier);
        if (existing.enabled) {
          this.logger.log(`Tier ${t.tier} already enabled, skipping`);
          configured.push(t.tier);
          continue;
        }
      } catch {
        // tierConfig might revert if never set — proceed to configure
      }

      this.logger.log(`Configuring tier ${t.tier}...`);
      const tx = await tierRegistry.configureTier(
        t.tier,
        t.maxPoolSize,
        t.collateralRateBps,
        t.enabled,
      );
      const receipt = await tx.wait();
      this.logger.log(`Tier ${t.tier} configured: ${receipt.hash}`);
      configured.push(t.tier);
      txHashes.push(receipt.hash);
    }

    return { configured, txHashes };
  }
}
