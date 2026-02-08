import { Body, Controller, Post } from '@nestjs/common';
import { IdentityService } from './identity.service';

@Controller('wallet')
export class IdentityController {
  constructor(private readonly identityService: IdentityService) {}

  @Post('bind')
  bindWallet(@Body() body: { identityHash: string; walletAddress: string }) {
    return this.identityService.bindWallet(body.identityHash, body.walletAddress);
  }
}
