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

  @Post('store-onchain')
  @ApiOperation({ summary: 'Queue identity binding for on-chain storage' })
  storeOnChain(@Body() dto: StoreOnChainDto) {
    return this.identityService.storeOnChain(dto.identityHash, dto.walletAddress);
  }
}
