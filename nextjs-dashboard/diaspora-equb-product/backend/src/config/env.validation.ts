import * as Joi from 'joi';

export const envValidationSchema = Joi.object({
  // Database
  DATABASE_HOST: Joi.string().default('localhost'),
  DATABASE_PORT: Joi.number().default(5432),
  DATABASE_USERNAME: Joi.string().default('equb'),
  DATABASE_PASSWORD: Joi.string().required(),
  DATABASE_NAME: Joi.string().default('diaspora_equb'),

  // JWT
  JWT_SECRET: Joi.string().min(16).required(),
  JWT_EXPIRATION: Joi.string().default('1d'),

  // Fayda
  FAYDA_API_URL: Joi.string().uri().default('https://api.fayda.et/v1'),
  FAYDA_API_KEY: Joi.string().default(''),

  // Blockchain
  RPC_URL: Joi.string().uri().required(),
  CHAIN_ID: Joi.number().default(102031),

  // Contract Addresses
  IDENTITY_REGISTRY_ADDRESS: Joi.string().default('0x0000000000000000000000000000000000000000'),
  TIER_REGISTRY_ADDRESS: Joi.string().default('0x0000000000000000000000000000000000000000'),
  CREDIT_REGISTRY_ADDRESS: Joi.string().default('0x0000000000000000000000000000000000000000'),
  COLLATERAL_VAULT_ADDRESS: Joi.string().default('0x0000000000000000000000000000000000000000'),
  PAYOUT_STREAM_ADDRESS: Joi.string().default('0x0000000000000000000000000000000000000000'),
  EQUB_POOL_ADDRESS: Joi.string().default('0x0000000000000000000000000000000000000000'),

  // Test Token Addresses (deployed on Creditcoin testnet)
  TEST_USDC_ADDRESS: Joi.string().default('0x0000000000000000000000000000000000000000'),
  TEST_USDT_ADDRESS: Joi.string().default('0x0000000000000000000000000000000000000000'),

  // Server
  PORT: Joi.number().default(3001),
  NODE_ENV: Joi.string().valid('development', 'production', 'test').default('development'),
});
