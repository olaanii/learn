import { Body, Controller, ForbiddenException, Post, Req } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { IdentityService } from './identity.service';
import { BindWalletDto, StoreOnChainDto } from './dto/bind-wallet.dto';

@ApiTags('Identity')
@ApiBearerAuth()
@Controller('wallet')
export class IdentityController {
  constructor(private readonly identityService: IdentityService) {}

  private assertAuthenticatedIdentity(req: any, identityHash: string) {
    if (req?.user?.identityHash != identityHash) {
      throw new ForbiddenException(
        'You can only act on the authenticated identity.',
      );
    }
  }

  @Post('bind')
  @ApiOperation({ summary: 'Bind a wallet address to an identity hash' })
  bindWallet(@Req() req: any, @Body() dto: BindWalletDto) {
    this.assertAuthenticatedIdentity(req, dto.identityHash);
    return this.identityService.bindWallet(dto.identityHash, dto.walletAddress, {
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
