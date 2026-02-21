import { Body, Controller, Get, Post, ForbiddenException } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse } from '@nestjs/swagger';
import { ConfigService } from '@nestjs/config';
import { AuthService } from './auth.service';
import { FaydaService } from './fayda.service';
import { VerifyFaydaDto } from './dto/verify-fayda.dto';
import { WalletChallengeDto } from './dto/wallet-challenge.dto';
import { WalletVerifyDto } from './dto/wallet-verify.dto';
import { Public } from '../common/decorators/public.decorator';

@ApiTags('Authentication')
@Controller('auth')
export class AuthController {
  constructor(
    private readonly authService: AuthService,
    private readonly configService: ConfigService,
    private readonly faydaService: FaydaService,
  ) {}

  @Get('fayda/status')
  @Public()
  @ApiOperation({ summary: 'Check if real Fayda integration is configured' })
  faydaStatus() {
    return {
      mode: this.faydaService.isRealIntegration ? 'real' : 'mock',
      available: this.faydaService.isRealIntegration,
    };
  }

  @Post('fayda/verify')
  @Public()
  @ApiOperation({ summary: 'Verify Fayda e-ID and receive JWT' })
  @ApiResponse({ status: 201, description: 'Verification successful, JWT returned' })
  @ApiResponse({ status: 401, description: 'Invalid Fayda token' })
  verifyFayda(@Body() dto: VerifyFaydaDto) {
    return this.authService.verifyFayda(dto.token);
  }

  @Post('wallet/challenge')
  @Public()
  @ApiOperation({ summary: 'Request a sign-in challenge for wallet-based authentication' })
  @ApiResponse({ status: 201, description: 'Challenge message returned' })
  walletChallenge(@Body() dto: WalletChallengeDto) {
    return this.authService.walletChallenge(dto.walletAddress);
  }

  @Post('wallet/verify')
  @Public()
  @ApiOperation({ summary: 'Verify wallet signature and receive JWT' })
  @ApiResponse({ status: 201, description: 'Signature verified, JWT returned' })
  @ApiResponse({ status: 401, description: 'Invalid signature or expired challenge' })
  walletVerify(@Body() dto: WalletVerifyDto) {
    return this.authService.walletVerify(dto.walletAddress, dto.signature, dto.message);
  }

  @Post('dev-login')
  @Public()
  @ApiOperation({
    summary: 'Dev-only login: generates JWT for testing without Fayda (development only)',
  })
  @ApiResponse({ status: 201, description: 'Dev JWT returned' })
  @ApiResponse({ status: 403, description: 'Forbidden in production' })
  devLogin(@Body() body: { walletAddress?: string }) {
    const nodeEnv = this.configService.get<string>('NODE_ENV', 'development');
    if (nodeEnv === 'production') {
      throw new ForbiddenException('Dev login is disabled in production');
    }
    return this.authService.devLogin(body.walletAddress);
  }
}
