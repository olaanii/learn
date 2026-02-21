import { DataSource } from 'typeorm';
import * as dotenv from 'dotenv';

dotenv.config({ path: '../.env' });

/**
 * TypeORM DataSource for CLI migrations.
 * Usage: npm run migration:generate -- src/migrations/InitialSchema
 *        npm run migration:run
 */
export default new DataSource({
  type: 'postgres',
  host: process.env.DATABASE_HOST || 'localhost',
  port: parseInt(process.env.DATABASE_PORT || '5432', 10),
  username: process.env.DATABASE_USERNAME || 'equb',
  password: process.env.DATABASE_PASSWORD || 'change_me',
  database: process.env.DATABASE_NAME || 'diaspora_equb',
  entities: ['src/entities/**/*.entity.ts'],
  migrations: ['src/migrations/**/*.ts'],
  synchronize: false,
  logging: true,
});
