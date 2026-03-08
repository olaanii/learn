import {
  Injectable,
  Logger,
  ServiceUnavailableException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as admin from 'firebase-admin';

@Injectable()
export class FirebaseAdminService {
  private readonly logger = new Logger(FirebaseAdminService.name);
  private readonly initialized: boolean;

  constructor(private readonly configService: ConfigService) {
    this.initialized = this.initialize();
  }

  get isConfigured(): boolean {
    return this.initialized;
  }

  async verifyIdToken(idToken: string) {
    if (!this.initialized) {
      throw new ServiceUnavailableException(
        'Firebase Auth is not configured on the backend.',
      );
    }

    return admin.auth().verifyIdToken(idToken);
  }

  private initialize(): boolean {
    const projectId = this.configService.get<string>('FIREBASE_PROJECT_ID', '');
    const clientEmail = this.configService.get<string>('FIREBASE_CLIENT_EMAIL', '');
    const privateKey = this.configService
      .get<string>('FIREBASE_PRIVATE_KEY', '')
      .replace(/\\n/g, '\n');

    if (!projectId || !clientEmail || !privateKey) {
      this.logger.warn('Firebase Admin credentials are not configured.');
      return false;
    }

    if (admin.apps.length == 0) {
      admin.initializeApp({
        credential: admin.credential.cert({
          projectId,
          clientEmail,
          privateKey,
        }),
      });
      this.logger.log('Firebase Admin initialized');
    }

    return true;
  }
}