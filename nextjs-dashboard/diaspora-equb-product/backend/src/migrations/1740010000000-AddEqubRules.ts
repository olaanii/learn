import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddEqubRules1740010000000 implements MigrationInterface {
  name = 'AddEqubRules1740010000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE "pools"
      ADD COLUMN IF NOT EXISTS "equbType" smallint NULL
    `);
    await queryRunner.query(`
      ALTER TABLE "pools"
      ADD COLUMN IF NOT EXISTS "frequency" smallint NULL
    `);
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "equb_rules" (
        "id" uuid NOT NULL DEFAULT gen_random_uuid(),
        "poolId" uuid NOT NULL,
        "equbType" smallint NOT NULL DEFAULT 0,
        "frequency" smallint NOT NULL DEFAULT 1,
        "payoutMethod" smallint NOT NULL DEFAULT 0,
        "gracePeriodSeconds" int NOT NULL DEFAULT 604800,
        "penaltySeverity" int NOT NULL DEFAULT 10,
        "roundDurationSeconds" int NOT NULL DEFAULT 2592000,
        "lateFeePercent" int NOT NULL DEFAULT 0,
        "createdAt" TIMESTAMP NOT NULL DEFAULT now(),
        "updatedAt" TIMESTAMP NOT NULL DEFAULT now(),
        CONSTRAINT "PK_equb_rules_id" PRIMARY KEY ("id"),
        CONSTRAINT "UQ_equb_rules_poolId" UNIQUE ("poolId"),
        CONSTRAINT "FK_equb_rules_pool" FOREIGN KEY ("poolId") REFERENCES "pools"("id") ON DELETE CASCADE
      )
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE IF EXISTS "equb_rules"`);
    await queryRunner.query(`ALTER TABLE "pools" DROP COLUMN IF EXISTS "equbType"`);
    await queryRunner.query(`ALTER TABLE "pools" DROP COLUMN IF EXISTS "frequency"`);
  }
}
