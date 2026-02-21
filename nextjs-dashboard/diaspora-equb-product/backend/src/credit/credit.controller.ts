import { Body, Controller, Post, Get, Query } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth, ApiQuery } from '@nestjs/swagger';
import { CreditService } from './credit.service';
import { UpdateCreditDto } from './dto/credit.dto';

@ApiTags('Credit')
@ApiBearerAuth()
@Controller('credit')
export class CreditController {
  constructor(private readonly creditService: CreditService) {}

  @Post('update')
  @ApiOperation({ summary: 'Update a credit score' })
  updateScore(@Body() dto: UpdateCreditDto) {
    return this.creditService.updateScore(
      dto.walletAddress,
      dto.delta,
      dto.reason,
    );
  }

  @Get()
  @ApiOperation({ summary: 'Get credit score for a wallet address' })
  @ApiQuery({ name: 'walletAddress', description: 'EVM wallet address' })
  getScore(@Query('walletAddress') walletAddress: string) {
    return this.creditService.getScore(walletAddress);
  }
}
