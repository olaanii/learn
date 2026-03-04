import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddBadgesTable1740050000000 implements MigrationInterface {
  name = 'AddBadgesTable1740050000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "badges" (
        "id" uuid NOT NULL DEFAULT gen_random_uuid(),
        "walletAddress" varchar(42) NOT NULL,
        "badgeType" int NOT NULL,
        "onChainTokenId" int NULL,
        "txHash" varchar(66) NULL,
        "metadataURI" varchar NULL,
        "earnedAt" TIMESTAMP NOT NULL DEFAULT now(),
        CONSTRAINT "PK_badges_id" PRIMARY KEY ("id"),
        CONSTRAINT "UQ_badges_wallet_type" UNIQUE ("walletAddress", "badgeType")
      )
    `);

    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS "IDX_badges_wallet"
        ON "badges" ("walletAddress")
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE IF EXISTS "badges"`);
  }
}
