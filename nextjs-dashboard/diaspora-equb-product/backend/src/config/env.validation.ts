import * as Joi from 'joi';

const evmAddress = Joi.string()
  .pattern(/^0x[a-fA-F0-9]{40}$/)
  .default('0x0000000000000000000000000000000000000000');

export const envValidationSchema = Joi.object({
  // Database
  DATABASE_HOST: Joi.string().default('localhost'),
  DATABASE_PORT: Joi.number().default(5432),
  DATABASE_USERNAME: Joi.string().default('equb'),
  DATABASE_PASSWORD: Joi.string().required(),
  DATABASE_NAME: Joi.string().default('diaspora_equb'),

  // JWT (SRS NFR-2: 32+ chars in production)
  JWT_SECRET: Joi.string().min(32).required(),
  JWT_EXPIRATION: Joi.string().default('1d'),

  // Fayda (leave empty to use mock mode in development)
  FAYDA_API_URL: Joi.alternatives().try(
    Joi.string().valid(''),
    Joi.string().uri(),
  ).default(''),
  FAYDA_API_KEY: Joi.string().allow('').default(''),

  // Blockchain
  RPC_URL: Joi.string().uri().required(),
  CHAIN_ID: Joi.number().default(102031),

  // Contract Addresses
  IDENTITY_REGISTRY_ADDRESS: evmAddress,
  TIER_REGISTRY_ADDRESS: evmAddress,
  CREDIT_REGISTRY_ADDRESS: evmAddress,
  COLLATERAL_VAULT_ADDRESS: evmAddress,
  PAYOUT_STREAM_ADDRESS: evmAddress,
  EQUB_POOL_ADDRESS: evmAddress,

  // Test Token Addresses
  TEST_USDC_ADDRESS: evmAddress,
  TEST_USDT_ADDRESS: evmAddress,

  // Server
  PORT: Joi.number().default(3001),
  NODE_ENV: Joi.string().valid('development', 'production', 'test').default('development'),

  // CORS (comma-separated origins for production)
  CORS_ORIGINS: Joi.string().allow('').default(''),

  // Sentry (optional)
  SENTRY_DSN: Joi.string().allow('').default(''),
});
