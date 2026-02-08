import { Injectable } from '@nestjs/common';
import { createHash } from 'crypto';

@Injectable()
export class AuthService {
  verifyFayda(token: string) {
    const identityHash = createHash('sha256').update(token).digest('hex');

    return {
      identityHash: `0x${identityHash}`,
      walletBindingStatus: 'unbound',
      token,
    };
  }
}
