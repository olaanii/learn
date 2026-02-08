import { Injectable } from '@nestjs/common';

@Injectable()
export class IdentityService {
  bindWallet(identityHash: string, walletAddress: string) {
    return {
      identityHash,
      walletAddress,
      status: 'bound',
    };
  }
}
