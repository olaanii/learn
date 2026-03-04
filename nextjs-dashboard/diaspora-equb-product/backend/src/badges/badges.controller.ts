import {
  Controller,
  Get,
  Post,
  Param,
  Req,
} from '@nestjs/common';
import {
  ApiTags,
  ApiOperation,
  ApiBearerAuth,
} from '@nestjs/swagger';
import { BadgesService } from './badges.service';

@ApiTags('Badges')
@ApiBearerAuth()
@Controller('badges')
export class BadgesController {
  constructor(private readonly badgesService: BadgesService) {}

  @Get('available')
  @ApiOperation({ summary: 'List all badge type definitions' })
  getAvailableBadges() {
    return this.badgesService.getAvailableBadges();
  }

  @Get(':wallet')
  @ApiOperation({ summary: 'List earned badges for a wallet address' })
  getBadges(@Param('wallet') wallet: string) {
    return this.badgesService.getBadges(wallet);
  }

  @Post('check-eligibility')
  @ApiOperation({ summary: 'Check badge eligibility for the authenticated wallet' })
  checkEligibility(@Req() req: any) {
    const wallet: string = req.user?.walletAddress;
    return this.badgesService.checkEligibility(wallet);
  }
}
