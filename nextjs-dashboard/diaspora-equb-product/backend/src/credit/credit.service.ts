import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { CreditScore } from '../entities/credit-score.entity';
import { Web3Service } from '../web3/web3.service';

@Injectable()
export class CreditService {
  private readonly logger = new Logger(CreditService.name);

  constructor(
    @InjectRepository(CreditScore)
    private readonly creditScoreRepo: Repository<CreditScore>,
    private readonly web3Service: Web3Service,
  ) {}

  /**
   * Get credit score: tries on-chain CreditRegistry first, falls back to DB cache.
   */
  async getScore(walletAddress: string) {
    // Try reading from on-chain CreditRegistry
    try {
      const creditRegistry = this.web3Service.getCreditRegistry();
      const onChainScore: bigint =
        await creditRegistry.scoreOf(walletAddress);

      return {
        walletAddress,
        score: Number(onChainScore),
        source: 'on-chain',
        lastUpdated: new Date().toISOString(),
      };
    } catch (e) {
      this.logger.warn(
        `On-chain credit score read failed, falling back to DB: ${e.message}`,
      );
    }

    // Fall back to DB cache
    const creditScore = await this.creditScoreRepo.findOne({
      where: { walletAddress },
    });

    return {
      walletAddress,
      score: creditScore?.score ?? 0,
      source: 'cache',
      lastUpdated: creditScore?.lastUpdated ?? null,
    };
  }

  /**
   * Legacy: update credit score in DB cache only (kept for dev/test).
   * In production, scores are updated on-chain by the EqubPool contract
   * during closeRound / triggerDefault, and synced by the indexer.
   */
  async updateScore(walletAddress: string, delta: number, reason?: string) {
    this.logger.log(
      `Updating credit score (DB): wallet=${walletAddress}, delta=${delta}, reason=${reason || 'N/A'}`,
    );

    let creditScore = await this.creditScoreRepo.findOne({
      where: { walletAddress },
    });

    if (!creditScore) {
      creditScore = this.creditScoreRepo.create({
        walletAddress,
        score: 0,
      });
    }

    creditScore.score += delta;
    await this.creditScoreRepo.save(creditScore);

    return {
      walletAddress,
      previousScore: creditScore.score - delta,
      delta,
      newScore: creditScore.score,
      reason,
      status: 'updated',
    };
  }
}
