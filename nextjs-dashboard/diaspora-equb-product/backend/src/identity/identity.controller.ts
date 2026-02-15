import { Body, Controller, Post } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { IdentityService } from './identity.service';
import { BindWalletDto, StoreOnChainDto } from './dto/bind-wallet.dto';

@ApiTags('Identity')
@ApiBearerAuth()
@Controller('wallet')
export class IdentityController {
  constructor(private readonly identityService: IdentityService) {}

  @Post('bind')
  @ApiOperation({ summary: 'Bind a wallet address to an identity hash' })
  bindWallet(@Body() dto: BindWalletDto) {
    return this.identityService.bindWallet(dto.identityHash, dto.walletAddress);
  }

  @Post('build/store-onchain')
  @ApiOperation({
    summary:
      'Build unsigned TX to bind identity on-chain via IdentityRegistry',
  })
  buildStoreOnChain(@Body() dto: StoreOnChainDto) {
    return this.identityService.buildStoreOnChain(
      dto.identityHash,
      dto.walletAddress,
    );
  }

  @Post('store-onchain')
  @ApiOperation({
    summary: '[Legacy] Queue identity binding for on-chain storage (dev/test)',
  })
  storeOnChain(@Body() dto: StoreOnChainDto) {
    return this.identityService.storeOnChain(
      dto.identityHash,
      dto.walletAddress,
    );
  }
}
