import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddReferralTables1740040000000 implements MigrationInterface {
  name = 'AddReferralTables1740040000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "referral_codes" (
        "id" uuid NOT NULL DEFAULT gen_random_uuid(),
        "walletAddress" varchar(42) NOT NULL,
        "code" varchar(12) NOT NULL,
        "createdAt" TIMESTAMP NOT NULL DEFAULT now(),
        CONSTRAINT "PK_referral_codes_id" PRIMARY KEY ("id"),
        CONSTRAINT "UQ_referral_codes_wallet" UNIQUE ("walletAddress"),
        CONSTRAINT "UQ_referral_codes_code" UNIQUE ("code")
      )
    `);

    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "referrals" (
        "id" uuid NOT NULL DEFAULT gen_random_uuid(),
        "referrerWallet" varchar(42) NOT NULL,
        "referredWallet" varchar(42) NOT NULL,
        "totalCommission" decimal(36,18) NOT NULL DEFAULT '0',
        "active" boolean NOT NULL DEFAULT true,
        "joinedAt" TIMESTAMP NOT NULL DEFAULT now(),
        CONSTRAINT "PK_referrals_id" PRIMARY KEY ("id"),
        CONSTRAINT "UQ_referrals_referred" UNIQUE ("referredWallet")
      )
    `);

    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS "IDX_referrals_referrer"
        ON "referrals" ("referrerWallet")
    `);

    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "commissions" (
        "id" uuid NOT NULL DEFAULT gen_random_uuid(),
        "referralId" uuid NOT NULL,
        "poolId" uuid NULL,
        "round" int NULL,
        "amount" decimal(36,18) NOT NULL,
        "txHash" varchar(66) NULL,
        "createdAt" TIMESTAMP NOT NULL DEFAULT now(),
        CONSTRAINT "PK_commissions_id" PRIMARY KEY ("id"),
        CONSTRAINT "FK_commissions_referral" FOREIGN KEY ("referralId")
          REFERENCES "referrals"("id") ON DELETE CASCADE
      )
    `);

    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS "IDX_commissions_referral"
        ON "commissions" ("referralId")
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE IF EXISTS "commissions"`);
    await queryRunner.query(`DROP TABLE IF EXISTS "referrals"`);
    await queryRunner.query(`DROP TABLE IF EXISTS "referral_codes"`);
  }
}
