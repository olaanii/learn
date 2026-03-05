/**
 * Vercel serverless entry: creates the Nest app and exports a request handler.
 * All routes are served under /api (global prefix). Use backend/vercel.json to route.
 */
import * as Sentry from '@sentry/node';
import { NestFactory } from '@nestjs/core';
import { ValidationPipe } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import helmet from 'helmet';
import { AppModule } from './app.module';
import { GlobalExceptionFilter } from './common/filters/http-exception.filter';
import { SanitizePipe } from './common/pipes/sanitize.pipe';
let appPromise: ReturnType<typeof createApp> | null = null;

async function createApp(): Promise<(req: any, res: any) => void> {
  const app = await NestFactory.create(AppModule, {
    logger: ['error', 'warn', 'log'],
  });

  const configService = app.get(ConfigService);
  const nodeEnv = configService.get<string>('NODE_ENV', 'development');

  if (configService.get<string>('SENTRY_DSN', '')) {
    Sentry.init({
      dsn: configService.get<string>('SENTRY_DSN'),
      environment: nodeEnv,
      tracesSampleRate: nodeEnv === 'production' ? 0.2 : 1.0,
    });
  }

  app.use(helmet());

  const corsOrigins = configService.get<string>('CORS_ORIGINS', '');
  app.enableCors({
    origin:
      nodeEnv === 'production' && corsOrigins
        ? corsOrigins.split(',').map((o) => o.trim())
        : true,
    credentials: true,
  });

  app.setGlobalPrefix('api');
  app.useGlobalFilters(new GlobalExceptionFilter());
  app.useGlobalPipes(
    new SanitizePipe(),
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
      transformOptions: { enableImplicitConversion: true },
    }),
  );

  if (nodeEnv !== 'production') {
    const config = new DocumentBuilder()
      .setTitle('Diaspora Equb DeFi API')
      .setDescription('Non-custodial backend API for the Diaspora Equb rotating savings protocol')
      .setVersion('0.9.0')
      .addBearerAuth()
      .build();
    const document = SwaggerModule.createDocument(app, config);
    SwaggerModule.setup('api/docs', app, document);
  }

  await app.init();
  const expressApp = app.getHttpAdapter().getInstance();
  return expressApp;
}

/** Default handler for Vercel (req, res). */
export default async function handler(req: any, res: any) {
  if (!appPromise) appPromise = createApp();
  const handle = await appPromise;
  return (handle as (req: any, res: any) => void)(req, res);
}

/** Export for Netlify: returns the Express app so serverless-http can wrap it. */
export { createApp };
