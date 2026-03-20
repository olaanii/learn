import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddWalletChallengesTable1740110000000
  implements MigrationInterface
{
  name = 'AddWalletChallengesTable1740110000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "wallet_challenges" (
        "id" uuid NOT NULL DEFAULT gen_random_uuid(),
        "challengeKey" varchar(160) NOT NULL,
        "purpose" varchar(16) NOT NULL,
        "walletAddress" varchar(42) NOT NULL,
        "identityHash" varchar(66),
        "nonce" varchar(64) NOT NULL,
        "message" text NOT NULL,
        "expiresAt" TIMESTAMP WITH TIME ZONE NOT NULL,
        "consumedAt" TIMESTAMP WITH TIME ZONE,
        "createdAt" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
        "updatedAt" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
        CONSTRAINT "PK_wallet_challenges_id" PRIMARY KEY ("id")
      )
    `);

    await queryRunner.query(`
      CREATE UNIQUE INDEX IF NOT EXISTS "IDX_wallet_challenges_key"
      ON "wallet_challenges" ("challengeKey")
    `);

    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS "IDX_wallet_challenges_expiresAt"
      ON "wallet_challenges" ("expiresAt")
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `DROP INDEX IF EXISTS "IDX_wallet_challenges_expiresAt"`,
    );
    await queryRunner.query(`DROP INDEX IF EXISTS "IDX_wallet_challenges_key"`);
    await queryRunner.query(`DROP TABLE IF EXISTS "wallet_challenges"`);
  }
}
