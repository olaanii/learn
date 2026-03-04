import { MigrationInterface, QueryRunner, Table } from 'typeorm';

export class AddProposalsTable1740030000000 implements MigrationInterface {
  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.createTable(
      new Table({
        name: 'proposals',
        columns: [
          {
            name: 'id',
            type: 'uuid',
            isPrimary: true,
            generationStrategy: 'uuid',
            default: 'uuid_generate_v4()',
          },
          {
            name: 'onChainProposalId',
            type: 'int',
          },
          {
            name: 'poolId',
            type: 'uuid',
          },
          {
            name: 'onChainEqubId',
            type: 'int',
          },
          {
            name: 'proposer',
            type: 'varchar',
            length: '42',
          },
          {
            name: 'ruleHash',
            type: 'varchar',
            length: '66',
          },
          {
            name: 'description',
            type: 'text',
            isNullable: true,
          },
          {
            name: 'yesVotes',
            type: 'int',
            default: 0,
          },
          {
            name: 'noVotes',
            type: 'int',
            default: 0,
          },
          {
            name: 'deadline',
            type: 'timestamp',
          },
          {
            name: 'status',
            type: 'varchar',
            default: "'active'",
          },
          {
            name: 'proposedRules',
            type: 'jsonb',
            isNullable: true,
          },
          {
            name: 'createdAt',
            type: 'timestamp',
            default: 'now()',
          },
          {
            name: 'updatedAt',
            type: 'timestamp',
            default: 'now()',
          },
        ],
      }),
      true,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.dropTable('proposals');
  }
}
