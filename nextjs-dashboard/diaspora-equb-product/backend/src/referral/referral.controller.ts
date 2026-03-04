import {
  Controller,
  Get,
  Post,
  Body,
  Query,
  Req,
} from '@nestjs/common';
import {
  ApiTags,
  ApiOperation,
  ApiBearerAuth,
} from '@nestjs/swagger';
import { ReferralService } from './referral.service';
import { ApplyReferralDto } from './dto/apply-referral.dto';
import { CommissionQueryDto } from './dto/commission-query.dto';

@ApiTags('Referral')
@ApiBearerAuth()
@Controller('referral')
export class ReferralController {
  constructor(private readonly referralService: ReferralService) {}

  @Get('code')
  @ApiOperation({ summary: 'Get or create referral code for authenticated wallet' })
  getOrCreateCode(@Req() req: any) {
    const wallet: string = req.user?.walletAddress;
    return this.referralService.getOrCreateCode(wallet);
  }

  @Get('stats')
  @ApiOperation({ summary: 'Get referral stats for authenticated wallet' })
  getStats(@Req() req: any) {
    const wallet: string = req.user?.walletAddress;
    return this.referralService.getReferralStats(wallet);
  }

  @Get('commissions')
  @ApiOperation({ summary: 'Get paginated commission history' })
  getCommissions(@Req() req: any, @Query() query: CommissionQueryDto) {
    const wallet: string = req.user?.walletAddress;
    return this.referralService.getCommissionHistory(
      wallet,
      query.page ?? 1,
      query.limit ?? 20,
    );
  }

  @Post('apply')
  @ApiOperation({ summary: 'Apply a referral code to link current wallet to a referrer' })
  applyReferral(@Req() req: any, @Body() dto: ApplyReferralDto) {
    const wallet: string = req.user?.walletAddress;
    return this.referralService.applyReferral(dto.code, wallet);
  }
}
