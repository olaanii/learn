import { Injectable, Logger, OnModuleInit, OnModuleDestroy } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { ConfigService } from '@nestjs/config';
import { Repository } from 'typeorm';
import { ethers } from 'ethers';
import { Web3Service } from '../web3/web3.service';
import { NotificationsService } from '../notifications/notifications.service';
import { NotificationType } from '../entities/notification.entity';
import { Pool } from '../entities/pool.entity';
import { PoolMember } from '../entities/pool-member.entity';
import { Contribution } from '../entities/contribution.entity';
import { PayoutStreamEntity } from '../entities/payout-stream.entity';
import { CreditScore } from '../entities/credit-score.entity';
import { Collateral } from '../entities/collateral.entity';
import { Identity } from '../entities/identity.entity';
import { IndexedBlock } from '../entities/indexed-block.entity';
import { TokenTransfer } from '../entities/token-transfer.entity';

const ERC20_TRANSFER_ABI = [
  'event Transfer(address indexed from, address indexed to, uint256 value)',
  'function decimals() view returns (uint8)',
];

/**
 * IndexerService listens to smart contract events on Creditcoin and
 * syncs on-chain state into the PostgreSQL cache.
 *
 * On startup it:
 *   1. Catches up from the last indexed block (stored in DB)
 *   2. Subscribes to real-time events via `contract.on()`
 *
 * Events indexed:
 *   - EqubPool: PoolCreated, JoinedPool, ContributionReceived, RoundClosed, DefaultTriggered
 *   - PayoutStream: StreamCreated, RoundReleased, StreamFrozen
 *   - CreditRegistry: ScoreUpdated
 *   - CollateralVault: CollateralDeposited, CollateralLocked, CollateralSlashed
 *   - IdentityRegistry: IdentityBound
 */
/** Polling interval (ms) for catch-up when RPC does not support persistent log filters. */
const CATCH_UP_POLL_MS = 60_000;

@Injectable()
export class IndexerService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(IndexerService.name);
  private isRunning = false;
  private lastError: string | null = null;
  private indexedEventCount = 0;
  private startedAt: Date | null = null;
  private catchUpIntervalId: ReturnType<typeof setInterval> | null = null;

  private tokenAddresses: Record<string, string> = {};

  constructor(
    private readonly web3Service: Web3Service,
    private readonly notifications: NotificationsService,
    private readonly configService: ConfigService,
    @InjectRepository(Pool)
    private readonly poolRepo: Repository<Pool>,
    @InjectRepository(PoolMember)
    private readonly memberRepo: Repository<PoolMember>,
    @InjectRepository(Contribution)
    private readonly contributionRepo: Repository<Contribution>,
    @InjectRepository(PayoutStreamEntity)
    private readonly payoutStreamRepo: Repository<PayoutStreamEntity>,
    @InjectRepository(CreditScore)
    private readonly creditScoreRepo: Repository<CreditScore>,
    @InjectRepository(Collateral)
    private readonly collateralRepo: Repository<Collateral>,
    @InjectRepository(Identity)
    private readonly identityRepo: Repository<Identity>,
    @InjectRepository(IndexedBlock)
    private readonly indexedBlockRepo: Repository<IndexedBlock>,
    @InjectRepository(TokenTransfer)
    private readonly tokenTransferRepo: Repository<TokenTransfer>,
  ) {
    this.tokenAddresses = {
      USDC: this.configService.get<string>('TEST_USDC_ADDRESS', ''),
      USDT: this.configService.get<string>('TEST_USDT_ADDRESS', ''),
    };
  }

  async onModuleInit() {
    // Start indexing after a short delay to let the provider connect
    setTimeout(() => this.startIndexing(), 3000);
  }

  onModuleDestroy() {
    this.stopIndexing();
  }

  // ─── Main Indexer Loop ──────────────────────────────────────────────────────

  private async startIndexing() {
    this.logger.log('Starting event indexer...');
    this.isRunning = true;
    this.startedAt = new Date();

    try {
      // 1. Catch up from last indexed block
      await this.catchUp();

      // 2. Poll for new events (Creditcoin RPC does not support eth_newFilter/eth_getFilterChanges)
      this.catchUpIntervalId = setInterval(() => {
        if (this.isRunning) {
          this.catchUp().catch((e) =>
            this.logger.warn(`Catch-up poll failed: ${e?.message ?? e}`),
          );
        }
      }, CATCH_UP_POLL_MS);

      this.lastError = null;
      this.logger.log(
        `Event indexer started (polling every ${CATCH_UP_POLL_MS / 1000}s)`,
      );
    } catch (error) {
      this.lastError = error.message;
      this.logger.error(`Indexer startup failed: ${error.message}`);
      this.logger.warn(
        'Indexer will retry in 30s. Ensure RPC_URL and contract addresses are configured.',
      );
      setTimeout(() => {
        if (this.isRunning) this.startIndexing();
      }, 30000);
    }
  }

  private stopIndexing() {
    this.logger.log('Stopping event indexer...');
    this.isRunning = false;

    if (this.catchUpIntervalId) {
      clearInterval(this.catchUpIntervalId);
      this.catchUpIntervalId = null;
    }

    try {
      const equbPool = this.web3Service.getEqubPool();
      const payoutStream = this.web3Service.getPayoutStream();
      const creditRegistry = this.web3Service.getCreditRegistry();
      const collateralVault = this.web3Service.getCollateralVault();
      const identityRegistry = this.web3Service.getIdentityRegistry();
      equbPool.removeAllListeners();
      payoutStream.removeAllListeners();
      creditRegistry.removeAllListeners();
      collateralVault.removeAllListeners();
      identityRegistry.removeAllListeners();

      const tokens = this.getTokenContracts();
      for (const { contract } of tokens) {
        contract.removeAllListeners();
      }
    } catch (_e) {
      // Ignore cleanup errors
    }
  }

  // ─── Catch-Up: Process Historical Events ────────────────────────────────────

  private async catchUp() {
    const provider = this.web3Service.getProvider();
    const currentBlock = await provider.getBlockNumber();

    await Promise.all([
      this.catchUpContract('EqubPool', this.web3Service.getEqubPool(), currentBlock),
      this.catchUpContract('PayoutStream', this.web3Service.getPayoutStream(), currentBlock),
      this.catchUpContract('CreditRegistry', this.web3Service.getCreditRegistry(), currentBlock),
      this.catchUpContract('CollateralVault', this.web3Service.getCollateralVault(), currentBlock),
      this.catchUpContract('IdentityRegistry', this.web3Service.getIdentityRegistry(), currentBlock),
      this.catchUpTokenTransfers(currentBlock),
    ]);
  }

  private async catchUpContract(
    name: string,
    contract: ethers.Contract,
    currentBlock: number,
  ) {
    const lastBlock = await this.getLastIndexedBlock(name);
    const fromBlock = lastBlock + 1;

    if (fromBlock > currentBlock) {
      this.logger.log(`${name}: already up to date (block ${currentBlock})`);
      return;
    }

    this.logger.log(
      `${name}: catching up from block ${fromBlock} to ${currentBlock}`,
    );

    const eventNames = this.getContractEventNames(name);

    // Query events in chunks of 2000 blocks to avoid RPC limits
    const CHUNK_SIZE = 2000;
    for (let start = fromBlock; start <= currentBlock; start += CHUNK_SIZE) {
      const end = Math.min(start + CHUNK_SIZE - 1, currentBlock);

      // Query each event type individually and merge, sorted by block+index
      const allEvents: ethers.EventLog[] = [];
      for (const eventName of eventNames) {
        try {
          const events = await contract.queryFilter(eventName, start, end);
          for (const event of events) {
            if (event instanceof ethers.EventLog) {
              allEvents.push(event);
            }
          }
        } catch (e) {
          this.logger.warn(
            `Failed to query ${name}.${eventName} blocks ${start}-${end}: ${e.message}`,
          );
        }
      }

      // Sort events by block number then log index to process in order
      allEvents.sort((a, b) => {
        if (a.blockNumber !== b.blockNumber) return a.blockNumber - b.blockNumber;
        return a.index - b.index;
      });

      for (const event of allEvents) {
        await this.handleEvent(name, event);
        this.indexedEventCount++;
      }
    }

    await this.setLastIndexedBlock(name, currentBlock);
    this.logger.log(`${name}: catch-up complete at block ${currentBlock}`);
  }

  /**
   * Returns the event names to query for each contract during catch-up.
   */
  private getContractEventNames(contractName: string): string[] {
    switch (contractName) {
      case 'EqubPool':
        return ['PoolCreated', 'JoinedPool', 'ContributionReceived', 'RoundClosed', 'DefaultTriggered'];
      case 'PayoutStream':
        return ['StreamCreated', 'RoundReleased', 'StreamFrozen'];
      case 'CreditRegistry':
        return ['ScoreUpdated'];
      case 'CollateralVault':
        return ['CollateralDeposited', 'CollateralLocked', 'CollateralSlashed'];
      case 'IdentityRegistry':
        return ['IdentityBound'];
      default:
        return [];
    }
  }

  // ─── Real-Time Event Subscription ──────────────────────────────────────────

  private subscribeToEvents() {
    this.subscribeEqubPool();
    this.subscribePayoutStream();
    this.subscribeCreditRegistry();
    this.subscribeCollateralVault();
    this.subscribeIdentityRegistry();
    this.subscribeTokenTransfers();
  }

  private subscribeEqubPool() {
    const equbPool = this.web3Service.getEqubPool();

    equbPool.on('PoolCreated', async (poolId, contributionAmount, maxMembers, token, event) => {
      this.logger.log(`[EqubPool] PoolCreated: poolId=${poolId}, token=${token}`);
      await this.handlePoolCreated(poolId, contributionAmount, maxMembers, event, token);
      this.indexedEventCount++;
      await this.updateBlockForEvent('EqubPool', event);
    });

    equbPool.on('JoinedPool', async (poolId, member, event) => {
      this.logger.log(`[EqubPool] JoinedPool: poolId=${poolId}, member=${member}`);
      await this.handleJoinedPool(poolId, member, event);
      this.indexedEventCount++;
      await this.updateBlockForEvent('EqubPool', event);
    });

    equbPool.on('ContributionReceived', async (poolId, member, round, event) => {
      this.logger.log(`[EqubPool] ContributionReceived: poolId=${poolId}, member=${member}, round=${round}`);
      await this.handleContributionReceived(poolId, member, round, event);
      this.indexedEventCount++;
      await this.updateBlockForEvent('EqubPool', event);
    });

    equbPool.on('RoundClosed', async (poolId, round, event) => {
      this.logger.log(`[EqubPool] RoundClosed: poolId=${poolId}, round=${round}`);
      await this.handleRoundClosed(poolId, round);
      this.indexedEventCount++;
      await this.updateBlockForEvent('EqubPool', event);
    });

    equbPool.on('DefaultTriggered', async (poolId, member, round, event) => {
      this.logger.log(`[EqubPool] DefaultTriggered: poolId=${poolId}, member=${member}, round=${round}`);
      await this.handleDefaultTriggered(poolId, member, round);
      this.indexedEventCount++;
      await this.updateBlockForEvent('EqubPool', event);
    });
  }

  private subscribePayoutStream() {
    const payoutStream = this.web3Service.getPayoutStream();

    payoutStream.on('StreamCreated', async (poolId, beneficiary, total, upfrontPercent, roundAmount, totalRounds, event) => {
      this.logger.log(`[PayoutStream] StreamCreated: poolId=${poolId}, beneficiary=${beneficiary}`);
      await this.handleStreamCreated(poolId, beneficiary, total, upfrontPercent, roundAmount, totalRounds);
      this.indexedEventCount++;
      await this.updateBlockForEvent('PayoutStream', event);
    });

    payoutStream.on('RoundReleased', async (poolId, beneficiary, amount, event) => {
      this.logger.log(`[PayoutStream] RoundReleased: poolId=${poolId}, beneficiary=${beneficiary}`);
      await this.handleRoundReleased(poolId, beneficiary, amount);
      this.indexedEventCount++;
      await this.updateBlockForEvent('PayoutStream', event);
    });

    payoutStream.on('StreamFrozen', async (poolId, beneficiary, event) => {
      this.logger.log(`[PayoutStream] StreamFrozen: poolId=${poolId}, beneficiary=${beneficiary}`);
      await this.handleStreamFrozen(poolId, beneficiary);
      this.indexedEventCount++;
      await this.updateBlockForEvent('PayoutStream', event);
    });
  }

  private subscribeCreditRegistry() {
    const creditRegistry = this.web3Service.getCreditRegistry();

    creditRegistry.on('ScoreUpdated', async (user, newScore, delta, event) => {
      this.logger.log(`[CreditRegistry] ScoreUpdated: user=${user}, score=${newScore}`);
      await this.handleScoreUpdated(user, newScore);
      this.indexedEventCount++;
      await this.updateBlockForEvent('CreditRegistry', event);
    });
  }

  private subscribeCollateralVault() {
    const collateralVault = this.web3Service.getCollateralVault();

    collateralVault.on('CollateralDeposited', async (user, amount, event) => {
      this.logger.log(`[CollateralVault] CollateralDeposited: user=${user}, amount=${amount}`);
      await this.handleCollateralDeposited(user, amount);
      this.indexedEventCount++;
      await this.updateBlockForEvent('CollateralVault', event);
    });

    collateralVault.on('CollateralLocked', async (user, amount, event) => {
      this.logger.log(`[CollateralVault] CollateralLocked: user=${user}, amount=${amount}`);
      await this.handleCollateralLocked(user, amount);
      this.indexedEventCount++;
      await this.updateBlockForEvent('CollateralVault', event);
    });

    collateralVault.on('CollateralSlashed', async (user, amount, event) => {
      this.logger.log(`[CollateralVault] CollateralSlashed: user=${user}, amount=${amount}`);
      await this.handleCollateralSlashed(user, amount);
      this.indexedEventCount++;
      await this.updateBlockForEvent('CollateralVault', event);
    });
  }

  private subscribeIdentityRegistry() {
    const identityRegistry = this.web3Service.getIdentityRegistry();

    identityRegistry.on('IdentityBound', async (wallet, identityHash, event) => {
      this.logger.log(`[IdentityRegistry] IdentityBound: wallet=${wallet}`);
      await this.handleIdentityBound(wallet, identityHash);
      this.indexedEventCount++;
      await this.updateBlockForEvent('IdentityRegistry', event);
    });
  }

  // ─── Event Handlers ─────────────────────────────────────────────────────────

  private async handleEvent(contractName: string, event: ethers.EventLog) {
    if (!event.eventName) return;

    try {
      switch (contractName) {
        case 'EqubPool':
          await this.handleEqubPoolEvent(event);
          break;
        case 'PayoutStream':
          await this.handlePayoutStreamEvent(event);
          break;
        case 'CreditRegistry':
          if (event.eventName === 'ScoreUpdated') {
            const [user, newScore] = event.args;
            await this.handleScoreUpdated(user, newScore);
          }
          break;
        case 'CollateralVault':
          if (event.eventName === 'CollateralDeposited') {
            const [user, amount] = event.args;
            await this.handleCollateralDeposited(user, amount);
          } else if (event.eventName === 'CollateralLocked') {
            const [user, amount] = event.args;
            await this.handleCollateralLocked(user, amount);
          } else if (event.eventName === 'CollateralSlashed') {
            const [user, amount] = event.args;
            await this.handleCollateralSlashed(user, amount);
          }
          break;
        case 'IdentityRegistry':
          if (event.eventName === 'IdentityBound') {
            const [wallet, identityHash] = event.args;
            await this.handleIdentityBound(wallet, identityHash);
          }
          break;
      }
    } catch (error) {
      this.logger.error(
        `Error handling ${contractName}.${event.eventName}: ${error.message}`,
      );
    }
  }

  private async handleEqubPoolEvent(event: ethers.EventLog) {
    switch (event.eventName) {
      case 'PoolCreated': {
        const [poolId, contributionAmount, maxMembers, token] = event.args;
        await this.handlePoolCreated(poolId, contributionAmount, maxMembers, event, token);
        break;
      }
      case 'JoinedPool': {
        const [poolId, member] = event.args;
        await this.handleJoinedPool(poolId, member, event);
        break;
      }
      case 'ContributionReceived': {
        const [poolId, member, round] = event.args;
        await this.handleContributionReceived(poolId, member, round, event);
        break;
      }
      case 'RoundClosed': {
        const [poolId, round] = event.args;
        await this.handleRoundClosed(poolId, round);
        break;
      }
      case 'DefaultTriggered': {
        const [poolId, member, round] = event.args;
        await this.handleDefaultTriggered(poolId, member, round);
        break;
      }
    }
  }

  private async handlePayoutStreamEvent(event: ethers.EventLog) {
    switch (event.eventName) {
      case 'StreamCreated': {
        const [poolId, beneficiary, total, upfrontPercent, roundAmount, totalRounds] = event.args;
        await this.handleStreamCreated(poolId, beneficiary, total, upfrontPercent, roundAmount, totalRounds);
        break;
      }
      case 'RoundReleased': {
        const [poolId, beneficiary, amount] = event.args;
        await this.handleRoundReleased(poolId, beneficiary, amount);
        break;
      }
      case 'StreamFrozen': {
        const [poolId, beneficiary] = event.args;
        await this.handleStreamFrozen(poolId, beneficiary);
        break;
      }
    }
  }

  // ─── DB Write Helpers ───────────────────────────────────────────────────────

  private async handlePoolCreated(
    onChainPoolId: bigint,
    contributionAmount: bigint,
    maxMembers: bigint,
    event: ethers.EventLog | ethers.ContractEventPayload,
    token?: string,
  ) {
    const txHashRaw = 'log' in event ? event.log?.transactionHash : (event as any).transactionHash;
    const txHash = txHashRaw ? String(txHashRaw).trim().toLowerCase() : null;
    this.logger.log(
      `[EqubPool] PoolCreated: onChainPoolId=${onChainPoolId}, txHash=${txHash ?? 'none'}`,
    );
    const existingByOnChain = await this.poolRepo.findOne({
      where: { onChainPoolId: Number(onChainPoolId) },
    });
    if (existingByOnChain) return; // Already indexed

    // Decode treasury from calldata and get creator (tx signer) from tx.from
    let treasury = '0x0000000000000000000000000000000000000000';
    let createdBy: string | null = null;
    if (txHash) {
      try {
        const provider = this.web3Service.getProvider();
        const equbPool = this.web3Service.getEqubPool();
        const tx = await provider.getTransaction(txHash);
        if (tx) {
          if (tx.from) createdBy = ethers.getAddress(tx.from);
          if (tx?.data) {
            const parsed = equbPool.interface.parseTransaction({ data: tx.data });
            if (parsed?.args && parsed.args.length >= 4) {
              const t = parsed.args[3];
              const addr = typeof t === 'string' && t.startsWith('0x') ? t : String((t as any)?.toString?.() ?? t);
              if (addr && addr !== '0x0000000000000000000000000000000000000000') treasury = ethers.getAddress(addr);
            }
          }
        }
      } catch (e) {
        this.logger.warn(`Could not decode treasury/creator from PoolCreated tx ${txHash}: ${e}`);
      }
    }

    const pool = this.poolRepo.create({
      onChainPoolId: Number(onChainPoolId),
      tier: 0,
      contributionAmount: contributionAmount.toString(),
      maxMembers: Number(maxMembers),
      currentRound: 1,
      treasury,
      createdBy,
      token: token || '0x0000000000000000000000000000000000000000',
      status: 'active',
      ...(txHash ? { txHash } : {}),
    });
    await this.poolRepo.save(pool);
    this.logger.log(`[EqubPool] PoolCreated: created new pool id=${pool.id}, onChainPoolId=${onChainPoolId}`);
  }

  private async handleJoinedPool(
    onChainPoolId: bigint,
    member: string,
    event: ethers.EventLog | ethers.ContractEventPayload,
  ) {
    const pool = await this.poolRepo.findOne({
      where: { onChainPoolId: Number(onChainPoolId) },
    });
    if (!pool) return;

    const existing = await this.memberRepo.findOne({
      where: { poolId: pool.id, walletAddress: member },
    });
    if (existing) return;

    const poolMember = this.memberRepo.create({
      poolId: pool.id,
      walletAddress: member,
    });
    await this.memberRepo.save(poolMember);

    const txHash = this.extractTxHash(event);
    this.emitNotification(
      member,
      'pool_joined',
      'Joined Pool',
      `You joined Tier ${pool.tier} pool #${pool.onChainPoolId}.`,
      {
        poolId: pool.id,
        onChainPoolId: pool.onChainPoolId,
        txHash,
        idempotencyKey: `pool_joined:${pool.id}:${member}:${txHash ?? 'no_tx'}`,
      },
    );
  }

  private async handleContributionReceived(
    onChainPoolId: bigint,
    member: string,
    round: bigint,
    event: ethers.EventLog | ethers.ContractEventPayload,
  ) {
    const pool = await this.poolRepo.findOne({
      where: { onChainPoolId: Number(onChainPoolId) },
    });
    if (!pool) return;

    const txHash = 'log' in event ? event.log?.transactionHash : (event as any).transactionHash;
    const roundNum = Number(round);

    const existing = await this.contributionRepo.findOne({
      where: { poolId: pool.id, walletAddress: member, round: roundNum },
    });
    if (existing) {
      // Update status if we had a pending record
      if (existing.status === 'pending-onchain') {
        existing.status = 'confirmed';
        existing.txHash = txHash || null;
        await this.contributionRepo.save(existing);
      }
      // If the pool was marked as 'round-closed', restore to 'active' on new confirmed contribution
      if (pool.status === 'round-closed') {
        pool.status = 'active';
        await this.poolRepo.save(pool).catch(() => {});
      }
      // Check whether all members have now contributed for this round and notify creator
      try {
        const roundNum = Number(round);
        const members = await this.memberRepo.find({ where: { poolId: pool.id } });
        if (members.length > 0) {
          const contribCount = await this.contributionRepo.count({ where: { poolId: pool.id, round: roundNum } });
          if (contribCount >= members.length) {
            if (pool.createdBy) {
              const _t: NotificationType = 'all_contributed';
              this.emitNotification(
                pool.createdBy,
                _t,
                'All Members Contributed',
                `All ${members.length} members have contributed for round ${roundNum} of pool #${pool.onChainPoolId}. Please select the winner.`,
                {
                  poolId: pool.id,
                  round: roundNum,
                  idempotencyKey: `all_contributed:${pool.id}:${roundNum}`,
                },
              );
            }
          }
        }
      } catch (e) {
        this.logger.warn(`Failed to check/notify all_contributed for pool ${pool.id}: ${e}`);
      }
      return;
    }

    const contribution = this.contributionRepo.create({
      poolId: pool.id,
      walletAddress: member,
      round: roundNum,
      status: 'confirmed',
      txHash: txHash || null,
    });
    await this.contributionRepo.save(contribution);

    // If the pool was marked 'round-closed' (e.g. by close event), set it back to active
    if (pool.status === 'round-closed') {
      pool.status = 'active';
      await this.poolRepo.save(pool).catch(() => {});
    }

    this.emitNotification(
      member,
      'contribution_confirmed',
      'Contribution Confirmed',
      `Your round ${roundNum} contribution to pool #${pool.onChainPoolId} is confirmed on-chain.`,
      {
        poolId: pool.id,
        round: roundNum,
        txHash,
        idempotencyKey: `contribution_confirmed:${pool.id}:${member}:${roundNum}:${txHash ?? 'no_tx'}`,
      },
    );
    // After recording contribution, check if all members have contributed for this round and notify pool creator
    try {
      const members = await this.memberRepo.find({ where: { poolId: pool.id } });
      if (members.length > 0) {
        const contribCount = await this.contributionRepo.count({ where: { poolId: pool.id, round: roundNum } });
        if (contribCount >= members.length) {
          if (pool.createdBy) {
            const _t: NotificationType = 'all_contributed';
            this.emitNotification(
              pool.createdBy,
              _t,
              'All Members Contributed',
              `All ${members.length} members have contributed for round ${roundNum} of pool #${pool.onChainPoolId}. Please select the winner.`,
              {
                poolId: pool.id,
                round: roundNum,
                idempotencyKey: `all_contributed:${pool.id}:${roundNum}`,
              },
            );
          }
        }
      }
    } catch (e) {
      this.logger.warn(`Failed to check/notify all_contributed for pool ${pool.id}: ${e}`);
    }
  }

  private async handleRoundClosed(
    onChainPoolId: bigint,
    round: bigint,
  ) {
    const pool = await this.poolRepo.findOne({
      where: { onChainPoolId: Number(onChainPoolId) },
    });
    if (!pool) return;

    pool.currentRound = Number(round) + 1;
    // Mark pool as round-closed so UI can display transient closed status
    pool.status = 'round-closed';
    await this.poolRepo.save(pool);

    const members = await this.memberRepo.find({ where: { poolId: pool.id } });
    for (const m of members) {
      this.emitNotification(
        m.walletAddress,
        'round_closed',
        'Round Closed',
        `Round ${Number(round)} of pool #${pool.onChainPoolId} is closed. Round ${pool.currentRound} begins.`,
        {
          poolId: pool.id,
          round: Number(round),
          idempotencyKey: `round_closed:${pool.id}:${Number(round)}:${m.walletAddress}`,
        },
      );
    }
  }

  private async handleStreamCreated(
    onChainPoolId: bigint,
    beneficiary: string,
    total: bigint,
    upfrontPercent: bigint,
    roundAmount: bigint,
    totalRounds: bigint,
  ) {
    const pool = await this.poolRepo.findOne({
      where: { onChainPoolId: Number(onChainPoolId) },
    });
    if (!pool) return;

    const existing = await this.payoutStreamRepo.findOne({
      where: { poolId: pool.id, beneficiary },
    });
    if (existing) return;

    const upfront =
      (BigInt(total) * BigInt(upfrontPercent)) / BigInt(100);

    const stream = this.payoutStreamRepo.create({
      poolId: pool.id,
      beneficiary,
      total: total.toString(),
      upfrontPercent: Number(upfrontPercent),
      roundAmount: roundAmount.toString(),
      totalRounds: Number(totalRounds),
      releasedRounds: 0,
      released: upfront.toString(),
      frozen: false,
    });
    await this.payoutStreamRepo.save(stream);
  }

  private async handleRoundReleased(
    onChainPoolId: bigint,
    beneficiary: string,
    amount: bigint,
  ) {
    const pool = await this.poolRepo.findOne({
      where: { onChainPoolId: Number(onChainPoolId) },
    });
    if (!pool) return;

    const stream = await this.payoutStreamRepo.findOne({
      where: { poolId: pool.id, beneficiary },
    });
    if (!stream) return;

    stream.releasedRounds += 1;
    stream.released = (
      BigInt(stream.released) + BigInt(amount)
    ).toString();
    await this.payoutStreamRepo.save(stream);

    this.emitNotification(
      beneficiary,
      'payout_received',
      'Payout Received',
      `You received a payout of ${ethers.formatUnits(amount, 6)} from pool #${pool.onChainPoolId}.`,
      {
        poolId: pool.id,
        amount: amount.toString(),
        idempotencyKey: `payout_received:${pool.id}:${beneficiary}:${stream.releasedRounds}`,
      },
    );
  }

  private async handleScoreUpdated(user: string, newScore: bigint) {
    let creditScore = await this.creditScoreRepo.findOne({
      where: { walletAddress: user },
    });

    if (!creditScore) {
      creditScore = this.creditScoreRepo.create({
        walletAddress: user,
        score: Number(newScore),
      });
    } else {
      creditScore.score = Number(newScore);
    }

    await this.creditScoreRepo.save(creditScore);
  }

  private async handleCollateralDeposited(user: string, amount: bigint) {
    let collateral = await this.collateralRepo.findOne({
      where: { walletAddress: user },
    });

    if (!collateral) {
      collateral = this.collateralRepo.create({
        walletAddress: user,
        lockedAmount: '0',
        slashedAmount: '0',
        availableBalance: amount.toString(),
      });
    } else {
      const current = BigInt(collateral.availableBalance || '0');
      collateral.availableBalance = (current + BigInt(amount)).toString();
    }

    await this.collateralRepo.save(collateral);
  }

  private async handleCollateralLocked(user: string, amount: bigint) {
    let collateral = await this.collateralRepo.findOne({
      where: { walletAddress: user },
    });
    if (!collateral) return;

    const currentAvailable = BigInt(collateral.availableBalance || '0');
    const currentLocked = BigInt(collateral.lockedAmount || '0');
    const lockAmt = BigInt(amount);

    collateral.availableBalance = (currentAvailable - lockAmt).toString();
    collateral.lockedAmount = (currentLocked + lockAmt).toString();
    await this.collateralRepo.save(collateral);
  }

  private async handleCollateralSlashed(user: string, amount: bigint) {
    let collateral = await this.collateralRepo.findOne({
      where: { walletAddress: user },
    });
    if (!collateral) return;

    const currentLocked = BigInt(collateral.lockedAmount || '0');
    const currentSlashed = BigInt(collateral.slashedAmount || '0');
    const slashAmt = BigInt(amount);
    const actualSlash = slashAmt > currentLocked ? currentLocked : slashAmt;

    collateral.lockedAmount = (currentLocked - actualSlash).toString();
    collateral.slashedAmount = (currentSlashed + actualSlash).toString();
    await this.collateralRepo.save(collateral);

    this.emitNotification(
      user,
      'collateral_slashed',
      'Collateral Slashed',
      `${ethers.formatUnits(actualSlash, 6)} of your collateral has been slashed.`,
      {
        amount: actualSlash.toString(),
        idempotencyKey: `collateral_slashed:${user}:${actualSlash.toString()}:${currentSlashed.toString()}`,
      },
    );
  }

  private async handleDefaultTriggered(
    onChainPoolId: bigint,
    member: string,
    round: bigint,
  ) {
    const pool = await this.poolRepo.findOne({
      where: { onChainPoolId: Number(onChainPoolId) },
    });
    if (!pool) return;

    const roundNum = Number(round);

    // Mark the member's contribution record as defaulted (or create one)
    let contribution = await this.contributionRepo.findOne({
      where: { poolId: pool.id, walletAddress: member, round: roundNum },
    });

    if (contribution) {
      contribution.status = 'defaulted';
      await this.contributionRepo.save(contribution);
    } else {
      contribution = this.contributionRepo.create({
        poolId: pool.id,
        walletAddress: member,
        round: roundNum,
        status: 'defaulted',
        txHash: null,
      });
      await this.contributionRepo.save(contribution);
    }

    this.emitNotification(
      member,
      'default_triggered',
      'Default Warning',
      `You defaulted on round ${roundNum} of pool #${pool.onChainPoolId}. Collateral may be slashed.`,
      {
        poolId: pool.id,
        round: roundNum,
        idempotencyKey: `default_triggered:${pool.id}:${member}:${roundNum}`,
      },
    );
  }

  private async handleStreamFrozen(
    onChainPoolId: bigint,
    beneficiary: string,
  ) {
    const pool = await this.poolRepo.findOne({
      where: { onChainPoolId: Number(onChainPoolId) },
    });
    if (!pool) return;

    const stream = await this.payoutStreamRepo.findOne({
      where: { poolId: pool.id, beneficiary },
    });
    if (!stream) return;

    stream.frozen = true;
    await this.payoutStreamRepo.save(stream);

    this.emitNotification(
      beneficiary,
      'stream_frozen',
      'Payout Stream Frozen',
      `Your payout stream for pool #${pool.onChainPoolId} has been frozen due to a default.`,
      {
        poolId: pool.id,
        idempotencyKey: `stream_frozen:${pool.id}:${beneficiary}`,
      },
    );
  }

  private extractTxHash(
    event: ethers.EventLog | ethers.ContractEventPayload,
  ): string | null {
    if ('log' in event) {
      return event.log?.transactionHash ?? null;
    }
    return (event as any).transactionHash ?? null;
  }

  private emitNotification(
    walletAddress: string,
    type: NotificationType,
    title: string,
    body: string,
    metadata?: Record<string, unknown>,
  ) {
    this.notifications
      .create(walletAddress, type, title, body, metadata)
      .catch((error) => {
        this.logger.warn(
          `Failed to emit notification [${type}] for ${walletAddress}: ${error?.message ?? error}`,
        );
      });
  }

  private async handleIdentityBound(wallet: string, identityHash: string) {
    let identity = await this.identityRepo.findOne({
      where: { walletAddress: wallet },
    });

    if (!identity) {
      identity = await this.identityRepo.findOne({
        where: { identityHash },
      });
    }

    if (identity) {
      identity.walletAddress = wallet;
      identity.bindingStatus = 'onchain';
      await this.identityRepo.save(identity);
    } else {
      // Identity was bound on-chain without going through backend first
      const newIdentity = this.identityRepo.create({
        identityHash,
        walletAddress: wallet,
        bindingStatus: 'onchain',
      });
      await this.identityRepo.save(newIdentity);
    }
  }

  // ─── ERC-20 Token Transfer Indexing ─────────────────────────────────────────

  private getTokenContracts(): { symbol: string; contract: ethers.Contract; address: string }[] {
    const provider = this.web3Service.getProvider();
    const result: { symbol: string; contract: ethers.Contract; address: string }[] = [];
    for (const [symbol, address] of Object.entries(this.tokenAddresses)) {
      if (address && address !== '0x0000000000000000000000000000000000000000') {
        result.push({
          symbol,
          address,
          contract: new ethers.Contract(address, ERC20_TRANSFER_ABI, provider),
        });
      }
    }
    return result;
  }

  private async catchUpTokenTransfers(currentBlock: number) {
    const tokens = this.getTokenContracts();
    if (tokens.length === 0) {
      this.logger.warn('No token addresses configured — skipping transfer indexing');
      return;
    }

    for (const { symbol, contract, address } of tokens) {
      const contractKey = `TokenTransfer_${symbol}`;
      const lastBlock = await this.getLastIndexedBlock(contractKey);
      const fromBlock = lastBlock + 1;

      if (fromBlock > currentBlock) {
        this.logger.log(`${contractKey}: already up to date (block ${currentBlock})`);
        continue;
      }

      this.logger.log(`${contractKey}: catching up from block ${fromBlock} to ${currentBlock}`);

      let decimals = 6;
      try {
        decimals = Number(await contract.decimals());
      } catch { /* use default */ }

      const CHUNK_SIZE = 2000;
      for (let start = fromBlock; start <= currentBlock; start += CHUNK_SIZE) {
        const end = Math.min(start + CHUNK_SIZE - 1, currentBlock);
        try {
          const events = await contract.queryFilter('Transfer', start, end);
          for (const event of events) {
            if (!(event instanceof ethers.EventLog)) continue;
            await this.saveTokenTransfer(event, symbol, address, decimals);
            this.indexedEventCount++;
          }
        } catch (e) {
          this.logger.warn(`Failed to query ${contractKey} Transfer blocks ${start}-${end}: ${e.message}`);
        }
      }

      await this.setLastIndexedBlock(contractKey, currentBlock);
      this.logger.log(`${contractKey}: catch-up complete at block ${currentBlock}`);
    }
  }

  private subscribeTokenTransfers() {
    const tokens = this.getTokenContracts();
    for (const { symbol, contract, address } of tokens) {
      let decimals = 6;
      contract.decimals().then((d: bigint) => { decimals = Number(d); }).catch(() => {});

      contract.on('Transfer', async (from: string, to: string, value: bigint, event: any) => {
        const log = event?.log ?? event;
        const txHash = log?.transactionHash;
        const blockNumber = log?.blockNumber;
        this.logger.debug(`[${symbol}] Transfer: ${from} -> ${to}, amount=${ethers.formatUnits(value, decimals)}`);

        await this.saveTokenTransfer(
          { args: [from, to, value], transactionHash: txHash, blockNumber } as any,
          symbol, address, decimals,
        );
        this.indexedEventCount++;
        if (blockNumber) {
          await this.setLastIndexedBlock(`TokenTransfer_${symbol}`, blockNumber);
        }
      });
    }
  }

  private async saveTokenTransfer(
    event: any,
    symbol: string,
    tokenAddress: string,
    decimals: number,
  ) {
    const from: string = event.args?.[0] ?? event.args?.from;
    const to: string = event.args?.[1] ?? event.args?.to;
    const value: bigint = event.args?.[2] ?? event.args?.value;
    const txHash = event.transactionHash;
    const blockNumber = event.blockNumber;

    if (!txHash) return;

    const existing = await this.tokenTransferRepo.findOne({ where: { txHash } });
    if (existing) return;

    let timestamp: number | null = null;
    try {
      const block = await this.web3Service.getProvider().getBlock(blockNumber);
      if (block) timestamp = block.timestamp * 1000;
    } catch { /* non-fatal */ }

    const transfer = this.tokenTransferRepo.create({
      txHash,
      from: from.toLowerCase(),
      to: to.toLowerCase(),
      amount: ethers.formatUnits(value, decimals),
      rawAmount: value.toString(),
      token: symbol.toUpperCase(),
      tokenAddress,
      blockNumber,
      timestamp,
    });

    try {
      await this.tokenTransferRepo.save(transfer);
    } catch (e) {
      if (!e.message?.includes('duplicate')) {
        this.logger.warn(`Failed to save transfer ${txHash}: ${e.message}`);
      }
    }
  }

  /**
   * Query persisted token transfers for a wallet from the database.
   * Returns full history (not limited to recent blocks).
   */
  async getTransfersForWallet(
    walletAddress: string,
    token?: string,
    limit = 50,
  ): Promise<TokenTransfer[]> {
    const addr = walletAddress.toLowerCase();
    const qb = this.tokenTransferRepo
      .createQueryBuilder('t')
      .where('(t.from = :addr OR t.to = :addr)', { addr });

    if (token) {
      qb.andWhere('t.token = :token', { token: token.toUpperCase() });
    }

    return qb
      .orderBy('t.blockNumber', 'DESC')
      .limit(limit)
      .getMany();
  }

  // ─── Public API ─────────────────────────────────────────────────────────────

  /**
   * Returns the current health/status of the indexer.
   * Used by the health controller and admin dashboards.
   */
  async getStatus() {
    const blocks: Record<string, number> = {};
    const records = await this.indexedBlockRepo.find();
    for (const record of records) {
      blocks[record.contractName] = Number(record.lastBlockNumber);
    }

    let currentBlock: number | null = null;
    try {
      currentBlock = await this.web3Service.getProvider().getBlockNumber();
    } catch {
      // Chain unreachable
    }

    return {
      isRunning: this.isRunning,
      startedAt: this.startedAt?.toISOString() ?? null,
      lastError: this.lastError,
      indexedEventCount: this.indexedEventCount,
      currentChainBlock: currentBlock,
      lastIndexedBlocks: blocks,
    };
  }

  /**
   * Force a re-index from a specific block number (or from scratch if 0).
   * Useful for admin recovery.
   */
  async reindex(fromBlock = 0) {
    this.logger.warn(`Forcing re-index from block ${fromBlock}`);
    const records = await this.indexedBlockRepo.find();
    for (const record of records) {
      record.lastBlockNumber = fromBlock;
      await this.indexedBlockRepo.save(record);
    }

    // Restart the indexer
    this.stopIndexing();
    setTimeout(() => this.startIndexing(), 1000);
  }

  // ─── Block Tracking ─────────────────────────────────────────────────────────

  private async getLastIndexedBlock(contractName: string): Promise<number> {
    const record = await this.indexedBlockRepo.findOne({
      where: { contractName },
    });
    if (record) return Number(record.lastBlockNumber);

    // No record: estimate a reasonable start block so we don't scan from genesis.
    // Contracts on testnet are recent; scanning from 100k blocks ago covers deployment.
    try {
      const currentBlock = await this.web3Service.getProvider().getBlockNumber();
      const defaultStart = Math.max(0, currentBlock - 100_000);
      this.logger.log(
        `${contractName}: no indexed block record, defaulting to ${defaultStart} (~100k blocks ago)`,
      );
      return defaultStart;
    } catch (_e) {
      return 0;
    }
  }

  private async setLastIndexedBlock(
    contractName: string,
    blockNumber: number,
  ) {
    let record = await this.indexedBlockRepo.findOne({
      where: { contractName },
    });

    if (!record) {
      record = this.indexedBlockRepo.create({
        contractName,
        lastBlockNumber: blockNumber,
      });
    } else {
      record.lastBlockNumber = blockNumber;
    }

    await this.indexedBlockRepo.save(record);
  }

  private async updateBlockForEvent(
    contractName: string,
    event: ethers.EventLog | ethers.ContractEventPayload,
  ) {
    const blockNumber =
      'log' in event ? event.log?.blockNumber : (event as any).blockNumber;
    if (blockNumber) {
      await this.setLastIndexedBlock(contractName, blockNumber);
    }
  }
}
