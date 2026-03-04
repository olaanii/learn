import { Controller, Get, Post, Param, Body } from '@nestjs/common';
import { GovernanceService } from './governance.service';

@Controller('pools/:poolId/proposals')
export class GovernanceController {
  constructor(private readonly governanceService: GovernanceService) {}

  @Get()
  getProposals(@Param('poolId') poolId: string) {
    return this.governanceService.getProposals(poolId);
  }

  @Get(':proposalId')
  getProposal(
    @Param('poolId') poolId: string,
    @Param('proposalId') proposalId: string,
  ) {
    return this.governanceService.getProposal(poolId, proposalId);
  }

  @Post()
  buildProposeTx(
    @Param('poolId') poolId: string,
    @Body() body: { rules: any; description: string; callerAddress: string },
  ) {
    return this.governanceService.buildProposeTx(
      poolId,
      body.rules,
      body.description,
      body.callerAddress,
    );
  }

  @Post(':onChainProposalId/vote')
  buildVoteTx(
    @Param('onChainProposalId') onChainProposalId: string,
    @Body() body: { support: boolean; callerAddress: string },
  ) {
    return this.governanceService.buildVoteTx(
      Number(onChainProposalId),
      body.support,
      body.callerAddress,
    );
  }

  @Post(':onChainProposalId/execute')
  buildExecuteTx(
    @Param('onChainProposalId') onChainProposalId: string,
    @Body() body: { callerAddress: string },
  ) {
    return this.governanceService.buildExecuteTx(
      Number(onChainProposalId),
      body.callerAddress,
    );
  }
}
