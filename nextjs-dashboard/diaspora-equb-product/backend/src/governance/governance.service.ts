import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Proposal } from '../entities/proposal.entity';
import { Pool } from '../entities/pool.entity';
import { Web3Service, UnsignedTxDto } from '../web3/web3.service';

@Injectable()
export class GovernanceService {
  constructor(
    @InjectRepository(Proposal)
    private readonly proposalRepo: Repository<Proposal>,
    @InjectRepository(Pool)
    private readonly poolRepo: Repository<Pool>,
    private readonly web3: Web3Service,
  ) {}

  async getProposals(poolId: string): Promise<Proposal[]> {
    return this.proposalRepo.find({
      where: { poolId },
      order: { createdAt: 'DESC' },
    });
  }

  async getProposal(poolId: string, proposalId: string): Promise<Proposal> {
    const proposal = await this.proposalRepo.findOne({
      where: { poolId, id: proposalId },
    });
    if (!proposal) {
      throw new NotFoundException('Proposal not found');
    }
    return proposal;
  }

  async buildProposeTx(
    poolId: string,
    rules: {
      equbType: number;
      frequency: number;
      payoutMethod: number;
      gracePeriodSeconds: number;
      penaltySeverity: number;
      roundDurationSeconds: number;
      lateFeePercent: number;
    },
    description: string,
    callerAddress: string,
  ): Promise<UnsignedTxDto> {
    const pool = await this.poolRepo.findOne({ where: { id: poolId } });
    if (!pool) throw new NotFoundException('Pool not found');

    const governor = this.web3.getEqubGovernor();
    const rulesTuple = [
      rules.equbType,
      rules.frequency,
      rules.payoutMethod,
      rules.gracePeriodSeconds,
      rules.penaltySeverity,
      rules.roundDurationSeconds,
      rules.lateFeePercent,
    ];

    const data = governor.interface.encodeFunctionData('proposeRuleChange', [
      pool.onChainPoolId,
      rulesTuple,
      description,
    ]);

    return this.web3.buildUnsignedTx(
      await governor.getAddress(),
      data,
    );
  }

  async buildVoteTx(
    proposalId: number,
    support: boolean,
    callerAddress: string,
  ): Promise<UnsignedTxDto> {
    const governor = this.web3.getEqubGovernor();

    const data = governor.interface.encodeFunctionData('vote', [
      proposalId,
      support,
    ]);

    return this.web3.buildUnsignedTx(
      await governor.getAddress(),
      data,
    );
  }

  async buildExecuteTx(
    proposalId: number,
    callerAddress: string,
  ): Promise<UnsignedTxDto> {
    const governor = this.web3.getEqubGovernor();

    const data = governor.interface.encodeFunctionData('executeProposal', [
      proposalId,
    ]);

    return this.web3.buildUnsignedTx(
      await governor.getAddress(),
      data,
    );
  }
}
