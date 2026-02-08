import { Injectable } from '@nestjs/common';

@Injectable()
export class AuthService {
  verifyFayda(token: string) {
    return {
      identityHash: '0x',
      walletBindingStatus: 'unbound',
      token,
    };
  }
}
