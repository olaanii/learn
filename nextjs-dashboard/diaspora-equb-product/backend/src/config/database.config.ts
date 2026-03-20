import { TypeOrmModuleOptions } from '@nestjs/typeorm';
import { ConfigService } from '@nestjs/config';
import { join } from 'path';

export const getDatabaseConfig = (
  configService: ConfigService,
): TypeOrmModuleOptions => {
  const isProduction =
    configService.get<string>('NODE_ENV') === 'production';
  const databaseUrl = configService.get<string>('DATABASE_URL', '');
  const databaseSsl = configService.get<boolean>('DATABASE_SSL', isProduction);

  const base = {
    autoLoadEntities: true,
    synchronize: !isProduction,
    migrationsRun: isProduction,
    migrations: [join(__dirname, '..', 'migrations', '*{.ts,.js}')],
    ssl: databaseSsl ? { rejectUnauthorized: false } : false,
    logging: !isProduction,
  };

  if (databaseUrl && databaseUrl.startsWith('postgres')) {
    return { ...base, type: 'postgres', url: databaseUrl };
  }

  return {
    ...base,
    type: 'postgres',
    host: configService.get<string>('DATABASE_HOST', 'localhost'),
    port: configService.get<number>('DATABASE_PORT', 5432),
    username: configService.get<string>('DATABASE_USERNAME', 'equb'),
    password: configService.get<string>('DATABASE_PASSWORD', 'change_me'),
    database: configService.get<string>('DATABASE_NAME', 'diaspora_equb'),
  };
};
