import { Body, Controller, ForbiddenException, Post, Req } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { IdentityService } from './identity.service';
import {
  BindWalletChallengeDto,
  BindWalletVerifyDto,
  StoreOnChainDto,
} from './dto/bind-wallet.dto';
import { AuthService } from '../auth/auth.service';

@ApiTags('Identity')
@ApiBearerAuth()
@Controller('wallet')
export class IdentityController {
  constructor(
    private readonly identityService: IdentityService,
    private readonly authService: AuthService,
  ) {}

  private assertAuthenticatedIdentity(req: any, identityHash: string) {
    if (req?.user?.identityHash != identityHash) {
      throw new ForbiddenException(
        'You can only act on the authenticated identity.',
      );
    }
  }

  @Post('bind/challenge')
  @ApiOperation({ summary: 'Issue a wallet-signature challenge for secure wallet binding' })
  bindWalletChallenge(@Req() req: any, @Body() dto: BindWalletChallengeDto) {
    this.assertAuthenticatedIdentity(req, dto.identityHash);
    return this.authService.walletBindChallenge(dto.identityHash, dto.walletAddress);
  }

  @Post('bind/verify')
  @ApiOperation({ summary: 'Verify bind signature and bind wallet to authenticated identity' })
  async bindWalletVerify(@Req() req: any, @Body() dto: BindWalletVerifyDto) {
    this.assertAuthenticatedIdentity(req, dto.identityHash);
    const verified = await this.authService.walletBindVerify(
      dto.identityHash,
      dto.walletAddress,
      dto.signature,
      dto.message,
    );

    return this.identityService.bindWallet(dto.identityHash, verified.walletAddress, {
      firebaseUid: req.user?.firebaseUid,
      email: req.user?.email,
      displayName: req.user?.displayName,
    });
  }

  @Post('build/store-onchain')
  @ApiOperation({
    summary:
      'Build unsigned TX to bind identity on-chain via IdentityRegistry',
  })
  buildStoreOnChain(@Req() req: any, @Body() dto: StoreOnChainDto) {
    this.assertAuthenticatedIdentity(req, dto.identityHash);
    return this.identityService.buildStoreOnChain(
      dto.identityHash,
      dto.walletAddress,
    );
  }

  @Post('store-onchain')
  @ApiOperation({
    summary: '[Legacy] Queue identity binding for on-chain storage (dev/test)',
  })
  storeOnChain(@Req() req: any, @Body() dto: StoreOnChainDto) {
    this.assertAuthenticatedIdentity(req, dto.identityHash);
    return this.identityService.storeOnChain(
      dto.identityHash,
      dto.walletAddress,
    );
  }
}
