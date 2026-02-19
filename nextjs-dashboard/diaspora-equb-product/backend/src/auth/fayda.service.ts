import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { HttpService } from '@nestjs/axios';
import { createHash } from 'crypto';
import { firstValueFrom, timeout, retry, catchError } from 'rxjs';

export interface FaydaVerificationResult {
  identityHash: string;
  verified: boolean;
  fullName?: string;
  faydaId?: string;
}

/**
 * Service for Fayda e-ID verification.
 *
 * - When `FAYDA_API_URL` is configured: calls the real Fayda API.
 * - When empty/unconfigured: uses a deterministic mock (development mode).
 *
 * The mock hashes the supplied token to produce a stable identityHash,
 * so the same token always returns the same identity in dev.
 */
@Injectable()
export class FaydaService {
  private readonly logger = new Logger(FaydaService.name);
  private readonly apiUrl: string;
  private readonly apiKey: string;

  constructor(
    private readonly configService: ConfigService,
    private readonly http: HttpService,
  ) {
    this.apiUrl = this.configService.get<string>('FAYDA_API_URL', '');
    this.apiKey = this.configService.get<string>('FAYDA_API_KEY', '');
  }

  get isRealIntegration(): boolean {
    return !!this.apiUrl && !!this.apiKey;
  }

  async verify(token: string): Promise<FaydaVerificationResult> {
    if (!this.isRealIntegration) {
      return this.verifyMock(token);
    }
    return this.verifyReal(token);
  }

  private async verifyReal(token: string): Promise<FaydaVerificationResult> {
    this.logger.log('Calling real Fayda API for verification...');

    try {
      const response = await firstValueFrom(
        this.http
          .post(
            `${this.apiUrl}/verify`,
            { token },
            {
              headers: {
                'Authorization': `Bearer ${this.apiKey}`,
                'Content-Type': 'application/json',
              },
              timeout: 15000,
            },
          )
          .pipe(
            timeout(15000),
            retry({ count: 2, delay: 1000 }),
            catchError((err) => {
              this.logger.error(`Fayda API error: ${err.message}`);
              throw err;
            }),
          ),
      );

      const data = response.data;

      if (!data || !data.verified) {
        return { identityHash: '', verified: false };
      }

      const rawId = data.faydaId || data.nationalId || data.id || token;
      const identityHash = `0x${createHash('sha256').update(rawId).digest('hex')}`;

      this.logger.log(`Fayda verification successful: ${identityHash.substring(0, 16)}...`);

      return {
        identityHash,
        verified: true,
        fullName: data.fullName || data.name,
        faydaId: data.faydaId || data.id,
      };
    } catch (error) {
      this.logger.error(`Fayda verification failed: ${error.message}`);
      throw error;
    }
  }

  /**
   * Mock verification for development/testing.
   * Deterministically hashes the token so the same token always
   * produces the same identity.
   */
  private verifyMock(token: string): FaydaVerificationResult {
    this.logger.warn('[MOCK] Fayda verification — not calling real API');
    const identityHash = `0x${createHash('sha256').update(token).digest('hex')}`;

    return {
      identityHash,
      verified: true,
      fullName: 'Test User',
      faydaId: `mock-${token.substring(0, 8)}`,
    };
  }
}
