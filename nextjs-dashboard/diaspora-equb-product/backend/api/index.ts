import { NestFactory } from '@nestjs/core';
import { ExpressAdapter } from '@nestjs/platform-express';
import express, { Request, Response } from 'express';
import helmet from 'helmet';
import { ValidationPipe } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { AppModule } from '../src/app.module';
import { GlobalExceptionFilter } from '../src/common/filters/http-exception.filter';
import { SanitizePipe } from '../src/common/pipes/sanitize.pipe';

let cachedHandler: ((req: Request, res: Response) => Promise<void>) | null = null;

async function bootstrap() {
  if (cachedHandler) {
    return cachedHandler;
  }

  const server = express();
  const app = await NestFactory.create(AppModule, new ExpressAdapter(server), {
    logger: ['error', 'warn', 'log'],
  });

  const configService = app.get(ConfigService);
  const nodeEnv = configService.get<string>('NODE_ENV', 'development');
  const corsOrigins = configService.get<string>('CORS_ORIGINS', '');

  app.use(helmet());
  app.enableCors({
    origin: nodeEnv === 'production'
      ? (corsOrigins ? corsOrigins.split(',').map((o) => o.trim()) : false)
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

  await app.init();

  cachedHandler = async (req: Request, res: Response) => {
    server(req, res);
  };

  return cachedHandler;
}

export default async function handler(req: Request, res: Response) {
  const h = await bootstrap();
  return h(req, res);
}
