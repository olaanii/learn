import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddSecurityTables1740020000000 implements MigrationInterface {
  name = 'AddSecurityTables1740020000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "totp_secrets" (
        "id" uuid NOT NULL DEFAULT gen_random_uuid(),
        "walletAddress" varchar(42) NOT NULL,
        "encryptedSecret" text NOT NULL,
        "enabled" boolean NOT NULL DEFAULT false,
        "verifiedAt" TIMESTAMP NULL,
        "createdAt" TIMESTAMP NOT NULL DEFAULT now(),
        "updatedAt" TIMESTAMP NOT NULL DEFAULT now(),
        CONSTRAINT "PK_totp_secrets_id" PRIMARY KEY ("id"),
        CONSTRAINT "UQ_totp_secrets_wallet" UNIQUE ("walletAddress")
      )
    `);

    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "devices" (
        "id" uuid NOT NULL DEFAULT gen_random_uuid(),
        "walletAddress" varchar(42) NOT NULL,
        "fingerprint" varchar(64) NOT NULL,
        "userAgent" varchar NULL,
        "trusted" boolean NOT NULL DEFAULT true,
        "lastSeen" TIMESTAMP NOT NULL,
        "createdAt" TIMESTAMP NOT NULL DEFAULT now(),
        "updatedAt" TIMESTAMP NOT NULL DEFAULT now(),
        CONSTRAINT "PK_devices_id" PRIMARY KEY ("id")
      )
    `);

    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS "IDX_devices_wallet"
        ON "devices" ("walletAddress")
    `);

    await queryRunner.query(`
      CREATE UNIQUE INDEX IF NOT EXISTS "IDX_devices_wallet_fingerprint"
        ON "devices" ("walletAddress", "fingerprint")
    `);

    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "withdrawal_whitelist" (
        "id" uuid NOT NULL DEFAULT gen_random_uuid(),
        "walletAddress" varchar(42) NOT NULL,
        "whitelistedAddress" varchar(42) NOT NULL,
        "label" varchar NULL,
        "addedAt" TIMESTAMP NOT NULL DEFAULT now(),
        CONSTRAINT "PK_withdrawal_whitelist_id" PRIMARY KEY ("id")
      )
    `);

    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS "IDX_whitelist_wallet"
        ON "withdrawal_whitelist" ("walletAddress")
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE IF EXISTS "withdrawal_whitelist"`);
    await queryRunner.query(`DROP TABLE IF EXISTS "devices"`);
    await queryRunner.query(`DROP TABLE IF EXISTS "totp_secrets"`);
  }
}
