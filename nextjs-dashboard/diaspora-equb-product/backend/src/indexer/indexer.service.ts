import { Injectable, Logger, OnModuleInit, OnModuleDestroy } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { ethers } from 'ethers';
import { Web3Service } from '../web3/web3.service';
import { Pool } from '../entities/pool.entity';
import { PoolMember } from '../entities/pool-member.entity';
import { Contribution } from '../entities/contribution.entity';
import { PayoutStreamEntity } from '../entities/payout-stream.entity';
import { CreditScore } from '../entities/credit-score.entity';
import { Collateral } from '../entities/collateral.entity';
import { Identity } from '../entities/identity.entity';
import { IndexedBlock } from '../entities/indexed-block.entity';

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
@Injectable()
export class IndexerService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(IndexerService.name);
  private isRunning = false;
  private lastError: string | null = null;
  private indexedEventCount = 0;
  private startedAt: Date | null = null;

  constructor(
    private readonly web3Service: Web3Service,
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
  ) {}

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

      // 2. Subscribe to real-time events
      this.subscribeToEvents();

      this.lastError = null;
      this.logger.log('Event indexer started and listening for events');
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

    // Remove all event listeners
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
    } catch {
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
    const txHash = 'log' in event ? event.log?.transactionHash : (event as any).transactionHash;
    const existing = await this.poolRepo.findOne({
      where: { onChainPoolId: Number(onChainPoolId) },
    });
    if (existing) return; // Already indexed

    const pool = this.poolRepo.create({
      onChainPoolId: Number(onChainPoolId),
      tier: 0, // Will be updated if we read from chain
      contributionAmount: contributionAmount.toString(),
      maxMembers: Number(maxMembers),
      currentRound: 1,
      treasury: '0x0000000000000000000000000000000000000000',
      token: token || '0x0000000000000000000000000000000000000000',
      status: 'active',
      txHash: txHash || null,
    });
    await this.poolRepo.save(pool);
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
    await this.poolRepo.save(pool);
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
    return record ? Number(record.lastBlockNumber) : 0;
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
