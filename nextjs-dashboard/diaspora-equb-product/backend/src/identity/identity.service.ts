import { Injectable } from '@nestjs/common';

@Injectable()
export class IdentityService {
  private readonly identityByWallet = new Map<string, string>();
  private readonly walletByIdentity = new Map<string, string>();

  bindWallet(identityHash: string, walletAddress: string) {
    const existingIdentity = this.identityByWallet.get(walletAddress);
    if (existingIdentity && existingIdentity !== identityHash) {
      return {
        identityHash,
        walletAddress,
        status: 'wallet-already-bound',
      };
    }

    const existingWallet = this.walletByIdentity.get(identityHash);
    if (existingWallet && existingWallet !== walletAddress) {
      return {
        identityHash,
        walletAddress,
        status: 'identity-already-bound',
      };
    }

    this.identityByWallet.set(walletAddress, identityHash);
    this.walletByIdentity.set(identityHash, walletAddress);

    return {
      identityHash,
      walletAddress,
      status: 'bound',
    };
  }
}
