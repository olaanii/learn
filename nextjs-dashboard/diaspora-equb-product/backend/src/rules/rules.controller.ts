import { Controller, Get, Post, Patch, Body, Param, Req, UnauthorizedException } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { RulesService } from './rules.service';
import { CreateEqubRulesDto, UpdateEqubRulesDto } from './dto/equb-rules.dto';

@ApiTags('Rules')
@ApiBearerAuth()
@Controller('pools/:poolId/rules')
export class RulesController {
  constructor(private readonly rulesService: RulesService) {}

  @Get()
  @ApiOperation({ summary: 'Get equb rules for a pool' })
  getRules(@Param('poolId') poolId: string, @Req() req: any) {
    return this.rulesService.getRules(poolId, req?.user?.walletAddress);
  }

  @Post()
  @ApiOperation({ summary: 'Set equb rules (creator only)' })
  setRules(
    @Param('poolId') poolId: string,
    @Body() dto: CreateEqubRulesDto,
    @Req() req: any,
  ) {
    const wallet = req?.user?.walletAddress;
    if (!wallet) throw new Error('Unauthorized');
    return this.rulesService.setRules(poolId, dto, wallet);
  }

  @Patch()
  @ApiOperation({ summary: 'Update equb rules (creator only, partial update)' })
  updateRules(
    @Param('poolId') poolId: string,
    @Body() dto: UpdateEqubRulesDto,
    @Req() req: any,
  ) {
    const wallet = req?.user?.walletAddress;
    if (!wallet) throw new UnauthorizedException('Wallet required');
    return this.rulesService.updateRules(poolId, dto, wallet);
  }
}
