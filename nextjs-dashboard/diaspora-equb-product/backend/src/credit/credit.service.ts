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

  async updateScore(walletAddress: string, delta: number, reason?: string) {
    this.logger.log(
      `Updating credit score: wallet=${walletAddress}, delta=${delta}, reason=${reason || 'N/A'}`,
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

    // In production: call CreditRegistry.updateScore on-chain
    // const contract = this.web3Service.getCreditRegistry();
    // const tx = await contract.updateScore(walletAddress, delta);

    return {
      walletAddress,
      previousScore: creditScore.score - delta,
      delta,
      newScore: creditScore.score,
      reason,
      status: 'updated',
    };
  }

  async getScore(walletAddress: string) {
    const creditScore = await this.creditScoreRepo.findOne({
      where: { walletAddress },
    });

    return {
      walletAddress,
      score: creditScore?.score ?? 0,
      lastUpdated: creditScore?.lastUpdated ?? null,
    };
  }
}
