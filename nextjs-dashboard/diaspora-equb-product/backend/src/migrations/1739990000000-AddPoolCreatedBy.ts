import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddPoolCreatedBy1739990000000 implements MigrationInterface {
  name = 'AddPoolCreatedBy1739990000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE "pools"
      ADD COLUMN IF NOT EXISTS "createdBy" varchar(42) NULL
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE "pools"
      DROP COLUMN IF EXISTS "createdBy"
    `);
  }
}
