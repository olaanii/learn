import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * Comprehensive "catch-all" migration that ensures every table and column
 * added during the Backend Agent work exists.  Uses IF NOT EXISTS / IF EXISTS
 * throughout so it is safe to run even when the individual per-feature
 * migrations (1740010000000 – 1740050000000) have already been applied.
 *
 * Tables created:
 *   equb_rules, totp_secrets, devices, withdrawal_whitelist,
 *   proposals, referral_codes, referrals, commissions, badges
 *
 * Columns added to existing tables:
 *   pools.equbType, pools.frequency
 */
export class AllNewEntities1740100000000 implements MigrationInterface {
  name = 'AllNewEntities1740100000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    // ── Pool columns (P0-BE-2) ──────────────────────────────────────
    await queryRunner.query(`
      ALTER TABLE "pools"
      ADD COLUMN IF NOT EXISTS "equbType" smallint NULL
    `);
    await queryRunner.query(`
      ALTER TABLE "pools"
      ADD COLUMN IF NOT EXISTS "frequency" smallint NULL
    `);

    // ── equb_rules (P0-BE-2) ────────────────────────────────────────
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "equb_rules" (
        "id"                   uuid        NOT NULL DEFAULT gen_random_uuid(),
        "poolId"               uuid        NOT NULL,
        "equbType"             smallint    NOT NULL DEFAULT 0,
        "frequency"            smallint    NOT NULL DEFAULT 1,
        "payoutMethod"         smallint    NOT NULL DEFAULT 0,
        "gracePeriodSeconds"   int         NOT NULL DEFAULT 604800,
        "penaltySeverity"      int         NOT NULL DEFAULT 10,
        "roundDurationSeconds" int         NOT NULL DEFAULT 2592000,
        "lateFeePercent"       int         NOT NULL DEFAULT 0,
        "createdAt"            TIMESTAMP   NOT NULL DEFAULT now(),
        "updatedAt"            TIMESTAMP   NOT NULL DEFAULT now(),
        CONSTRAINT "PK_equb_rules_id"     PRIMARY KEY ("id"),
        CONSTRAINT "UQ_equb_rules_poolId" UNIQUE ("poolId"),
        CONSTRAINT "FK_equb_rules_pool"   FOREIGN KEY ("poolId")
          REFERENCES "pools"("id") ON DELETE CASCADE
      )
    `);

    // ── totp_secrets (P1-BE-3) ──────────────────────────────────────
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "totp_secrets" (
        "id"              uuid         NOT NULL DEFAULT gen_random_uuid(),
        "walletAddress"   varchar(42)  NOT NULL,
        "encryptedSecret" text         NOT NULL,
        "enabled"         boolean      NOT NULL DEFAULT false,
        "verifiedAt"      TIMESTAMP    NULL,
        "createdAt"       TIMESTAMP    NOT NULL DEFAULT now(),
        "updatedAt"       TIMESTAMP    NOT NULL DEFAULT now(),
        CONSTRAINT "PK_totp_secrets_id"     PRIMARY KEY ("id"),
        CONSTRAINT "UQ_totp_secrets_wallet" UNIQUE ("walletAddress")
      )
    `);

    // ── devices (P1-BE-3) ───────────────────────────────────────────
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "devices" (
        "id"            uuid         NOT NULL DEFAULT gen_random_uuid(),
        "walletAddress" varchar(42)  NOT NULL,
        "fingerprint"   varchar(64)  NOT NULL,
        "userAgent"     varchar      NULL,
        "trusted"       boolean      NOT NULL DEFAULT true,
        "lastSeen"      TIMESTAMP    NOT NULL,
        "createdAt"     TIMESTAMP    NOT NULL DEFAULT now(),
        "updatedAt"     TIMESTAMP    NOT NULL DEFAULT now(),
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

    // ── withdrawal_whitelist (P1-BE-3) ──────────────────────────────
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "withdrawal_whitelist" (
        "id"                  uuid         NOT NULL DEFAULT gen_random_uuid(),
        "walletAddress"       varchar(42)  NOT NULL,
        "whitelistedAddress"  varchar(42)  NOT NULL,
        "label"               varchar      NULL,
        "addedAt"             TIMESTAMP    NOT NULL DEFAULT now(),
        CONSTRAINT "PK_withdrawal_whitelist_id" PRIMARY KEY ("id")
      )
    `);
    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS "IDX_whitelist_wallet"
        ON "withdrawal_whitelist" ("walletAddress")
    `);

    // ── proposals (P1-BE-2) ─────────────────────────────────────────
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "proposals" (
        "id"                 uuid         NOT NULL DEFAULT gen_random_uuid(),
        "onChainProposalId"  int          NOT NULL,
        "poolId"             uuid         NOT NULL,
        "onChainEqubId"      int          NOT NULL,
        "proposer"           varchar(42)  NOT NULL,
        "ruleHash"           varchar(66)  NOT NULL,
        "description"        text         NULL,
        "yesVotes"           int          NOT NULL DEFAULT 0,
        "noVotes"            int          NOT NULL DEFAULT 0,
        "deadline"           TIMESTAMP    NOT NULL,
        "status"             varchar      NOT NULL DEFAULT 'active',
        "proposedRules"      jsonb        NULL,
        "createdAt"          TIMESTAMP    NOT NULL DEFAULT now(),
        "updatedAt"          TIMESTAMP    NOT NULL DEFAULT now(),
        CONSTRAINT "PK_proposals_id" PRIMARY KEY ("id")
      )
    `);

    // ── referral_codes (P2-BE-2) ────────────────────────────────────
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "referral_codes" (
        "id"            uuid         NOT NULL DEFAULT gen_random_uuid(),
        "walletAddress" varchar(42)  NOT NULL,
        "code"          varchar(12)  NOT NULL,
        "createdAt"     TIMESTAMP    NOT NULL DEFAULT now(),
        CONSTRAINT "PK_referral_codes_id"     PRIMARY KEY ("id"),
        CONSTRAINT "UQ_referral_codes_wallet" UNIQUE ("walletAddress"),
        CONSTRAINT "UQ_referral_codes_code"   UNIQUE ("code")
      )
    `);

    // ── referrals (P2-BE-2) ─────────────────────────────────────────
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "referrals" (
        "id"              uuid          NOT NULL DEFAULT gen_random_uuid(),
        "referrerWallet"  varchar(42)   NOT NULL,
        "referredWallet"  varchar(42)   NOT NULL,
        "totalCommission" decimal(36,18) NOT NULL DEFAULT '0',
        "active"          boolean       NOT NULL DEFAULT true,
        "joinedAt"        TIMESTAMP     NOT NULL DEFAULT now(),
        CONSTRAINT "PK_referrals_id"       PRIMARY KEY ("id"),
        CONSTRAINT "UQ_referrals_referred" UNIQUE ("referredWallet")
      )
    `);
    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS "IDX_referrals_referrer"
        ON "referrals" ("referrerWallet")
    `);

    // ── commissions (P2-BE-2) ───────────────────────────────────────
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "commissions" (
        "id"         uuid           NOT NULL DEFAULT gen_random_uuid(),
        "referralId" uuid           NOT NULL,
        "poolId"     uuid           NULL,
        "round"      int            NULL,
        "amount"     decimal(36,18) NOT NULL,
        "txHash"     varchar(66)    NULL,
        "createdAt"  TIMESTAMP      NOT NULL DEFAULT now(),
        CONSTRAINT "PK_commissions_id"       PRIMARY KEY ("id"),
        CONSTRAINT "FK_commissions_referral" FOREIGN KEY ("referralId")
          REFERENCES "referrals"("id") ON DELETE CASCADE
      )
    `);
    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS "IDX_commissions_referral"
        ON "commissions" ("referralId")
    `);

    // ── badges (P2-BE-3) ────────────────────────────────────────────
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "badges" (
        "id"              uuid         NOT NULL DEFAULT gen_random_uuid(),
        "walletAddress"   varchar(42)  NOT NULL,
        "badgeType"       int          NOT NULL,
        "onChainTokenId"  int          NULL,
        "txHash"          varchar(66)  NULL,
        "metadataURI"     varchar      NULL,
        "earnedAt"        TIMESTAMP    NOT NULL DEFAULT now(),
        CONSTRAINT "PK_badges_id"          PRIMARY KEY ("id"),
        CONSTRAINT "UQ_badges_wallet_type" UNIQUE ("walletAddress", "badgeType")
      )
    `);
    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS "IDX_badges_wallet"
        ON "badges" ("walletAddress")
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    // Drop tables in reverse dependency order
    await queryRunner.query(`DROP TABLE IF EXISTS "badges"`);
    await queryRunner.query(`DROP TABLE IF EXISTS "commissions"`);
    await queryRunner.query(`DROP TABLE IF EXISTS "referrals"`);
    await queryRunner.query(`DROP TABLE IF EXISTS "referral_codes"`);
    await queryRunner.query(`DROP TABLE IF EXISTS "proposals"`);
    await queryRunner.query(`DROP TABLE IF EXISTS "withdrawal_whitelist"`);
    await queryRunner.query(`DROP TABLE IF EXISTS "devices"`);
    await queryRunner.query(`DROP TABLE IF EXISTS "totp_secrets"`);
    await queryRunner.query(`DROP TABLE IF EXISTS "equb_rules"`);

    // Drop added columns from pools
    await queryRunner.query(`ALTER TABLE "pools" DROP COLUMN IF EXISTS "frequency"`);
    await queryRunner.query(`ALTER TABLE "pools" DROP COLUMN IF EXISTS "equbType"`);
  }
}
