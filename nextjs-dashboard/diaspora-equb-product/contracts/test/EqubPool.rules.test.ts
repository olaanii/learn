import { expect } from 'chai';
import { ethers } from 'hardhat';
import {
  EqubPool,
  PayoutStream,
  CollateralVault,
  CreditRegistry,
  IdentityRegistry,
  TierRegistry,
} from '../typechain-types';
import { SignerWithAddress } from '@nomicfoundation/hardhat-ethers/signers';

describe('EqubPool – Equb Rules', () => {
  let equbPool: EqubPool;
  let payoutStream: PayoutStream;
  let collateralVault: CollateralVault;
  let creditRegistry: CreditRegistry;
  let identityRegistry: IdentityRegistry;
  let tierRegistry: TierRegistry;

  let owner: SignerWithAddress;
  let user1: SignerWithAddress;
  let user2: SignerWithAddress;
  let user3: SignerWithAddress;
  let treasury: SignerWithAddress;
  let governor: SignerWithAddress;

  const CONTRIBUTION = ethers.parseEther('1');
  const MAX_MEMBERS = 5;
  const TIER = 0;

  const DEFAULT_RULES = {
    equbType: 0,       // Finance
    frequency: 1,      // Weekly
    payoutMethod: 0,   // Lottery
    gracePeriodSeconds: 604800,      // 7 days
    penaltySeverity: 10,
    roundDurationSeconds: 2592000,   // 30 days
    lateFeePercent: 0,
  };

  const CUSTOM_RULES = {
    equbType: 2,       // Car
    frequency: 3,      // Monthly
    payoutMethod: 1,   // Rotation
    gracePeriodSeconds: 259200,      // 3 days
    penaltySeverity: 25,
    roundDurationSeconds: 604800,    // 7 days
    lateFeePercent: 5,
  };

  function rulesStruct(r: typeof DEFAULT_RULES) {
    return [
      r.equbType,
      r.frequency,
      r.payoutMethod,
      r.gracePeriodSeconds,
      r.penaltySeverity,
      r.roundDurationSeconds,
      r.lateFeePercent,
    ] as const;
  }

  function expectRulesEqual(
    actual: Awaited<ReturnType<EqubPool['getRules']>>,
    expected: typeof DEFAULT_RULES,
  ) {
    expect(actual.equbType).to.equal(expected.equbType);
    expect(actual.frequency).to.equal(expected.frequency);
    expect(actual.payoutMethod).to.equal(expected.payoutMethod);
    expect(actual.gracePeriodSeconds).to.equal(expected.gracePeriodSeconds);
    expect(actual.penaltySeverity).to.equal(expected.penaltySeverity);
    expect(actual.roundDurationSeconds).to.equal(expected.roundDurationSeconds);
    expect(actual.lateFeePercent).to.equal(expected.lateFeePercent);
  }

  beforeEach(async () => {
    [owner, user1, user2, user3, treasury, governor] = await ethers.getSigners();

    const PayoutStreamFactory = await ethers.getContractFactory('PayoutStream');
    payoutStream = await PayoutStreamFactory.deploy();

    const CollateralVaultFactory = await ethers.getContractFactory('CollateralVault');
    collateralVault = await CollateralVaultFactory.deploy();

    const CreditRegistryFactory = await ethers.getContractFactory('CreditRegistry');
    creditRegistry = await CreditRegistryFactory.deploy();

    const IdentityRegistryFactory = await ethers.getContractFactory('IdentityRegistry');
    identityRegistry = await IdentityRegistryFactory.deploy();

    const TierRegistryFactory = await ethers.getContractFactory('TierRegistry');
    tierRegistry = await TierRegistryFactory.deploy();

    await tierRegistry.configureTier(TIER, ethers.parseEther('100'), 0, true);

    const EqubPoolFactory = await ethers.getContractFactory('EqubPool');
    equbPool = await EqubPoolFactory.deploy(
      await payoutStream.getAddress(),
      await collateralVault.getAddress(),
      await creditRegistry.getAddress(),
      await identityRegistry.getAddress(),
      await tierRegistry.getAddress(),
    );

    await payoutStream.setEqubPool(await equbPool.getAddress());

    const hash1 = ethers.keccak256(ethers.toUtf8Bytes('user1'));
    const hash2 = ethers.keccak256(ethers.toUtf8Bytes('user2'));
    const hash3 = ethers.keccak256(ethers.toUtf8Bytes('user3'));

    await identityRegistry.bindIdentity(user1.address, hash1);
    await identityRegistry.bindIdentity(user2.address, hash2);
    await identityRegistry.bindIdentity(user3.address, hash3);
  });

  describe('createPool with custom rules', () => {
    it('should create a pool with custom rules and return them via getRules', async () => {
      await equbPool[
        'createPool(uint8,uint256,uint256,address,address,(uint8,uint8,uint8,uint256,uint256,uint256,uint256))'
      ](TIER, CONTRIBUTION, MAX_MEMBERS, treasury.address, ethers.ZeroAddress, rulesStruct(CUSTOM_RULES));

      const poolId = 1;
      expect(await equbPool.poolCount()).to.equal(poolId);

      const rules = await equbPool.getRules(poolId);
      expectRulesEqual(rules, CUSTOM_RULES);
    });
  });

  describe('createPool with default rules (legacy overload)', () => {
    it('should assign default rules when using the legacy createPool overload', async () => {
      await equbPool['createPool(uint8,uint256,uint256,address)'](
        TIER, CONTRIBUTION, MAX_MEMBERS, treasury.address,
      );

      const rules = await equbPool.getRules(1);
      expectRulesEqual(rules, DEFAULT_RULES);
    });

    it('should assign default rules when using the v2 overload without rules', async () => {
      await equbPool['createPool(uint8,uint256,uint256,address,address)'](
        TIER, CONTRIBUTION, MAX_MEMBERS, treasury.address, ethers.ZeroAddress,
      );

      const rules = await equbPool.getRules(1);
      expectRulesEqual(rules, DEFAULT_RULES);
    });
  });

  describe('setGovernor', () => {
    it('should allow the owner to set a governor', async () => {
      await expect(equbPool.connect(owner).setGovernor(governor.address))
        .to.emit(equbPool, 'GovernorSet')
        .withArgs(governor.address);

      expect(await equbPool.equbGovernor()).to.equal(governor.address);
    });

    it('should revert when a non-owner tries to set governor', async () => {
      await expect(
        equbPool.connect(user1).setGovernor(governor.address),
      ).to.be.revertedWith('only owner');
    });
  });

  describe('updateRules', () => {
    let poolId: number;

    beforeEach(async () => {
      await equbPool['createPool(uint8,uint256,uint256,address)'](
        TIER, CONTRIBUTION, MAX_MEMBERS, treasury.address,
      );
      poolId = 1;

      await equbPool.connect(owner).setGovernor(governor.address);
    });

    it('should revert when a non-governor tries to update rules', async () => {
      await expect(
        equbPool.connect(user1).updateRules(poolId, rulesStruct(CUSTOM_RULES)),
      ).to.be.revertedWith('only governor');
    });

    it('should revert when the owner (non-governor) tries to update rules', async () => {
      await expect(
        equbPool.connect(owner).updateRules(poolId, rulesStruct(CUSTOM_RULES)),
      ).to.be.revertedWith('only governor');
    });

    it('should revert when governor is not set', async () => {
      const EqubPoolFactory = await ethers.getContractFactory('EqubPool');
      const freshPool = await EqubPoolFactory.deploy(
        await payoutStream.getAddress(),
        await collateralVault.getAddress(),
        await creditRegistry.getAddress(),
        await identityRegistry.getAddress(),
        await tierRegistry.getAddress(),
      );

      await freshPool['createPool(uint8,uint256,uint256,address)'](
        TIER, CONTRIBUTION, MAX_MEMBERS, treasury.address,
      );

      await expect(
        freshPool.connect(user1).updateRules(1, rulesStruct(CUSTOM_RULES)),
      ).to.be.revertedWith('governor not set');
    });

    it('should allow the governor to update rules and emit RulesUpdated', async () => {
      await expect(
        equbPool.connect(governor).updateRules(poolId, rulesStruct(CUSTOM_RULES)),
      ).to.emit(equbPool, 'RulesUpdated');

      const rules = await equbPool.getRules(poolId);
      expectRulesEqual(rules, CUSTOM_RULES);
    });

    it('should revert when updating rules for a nonexistent pool', async () => {
      await expect(
        equbPool.connect(governor).updateRules(999, rulesStruct(CUSTOM_RULES)),
      ).to.be.revertedWith('pool not found');
    });
  });

  describe('getRules after update', () => {
    it('should return updated values after governor changes rules', async () => {
      await equbPool['createPool(uint8,uint256,uint256,address)'](
        TIER, CONTRIBUTION, MAX_MEMBERS, treasury.address,
      );
      const poolId = 1;

      const rulesBefore = await equbPool.getRules(poolId);
      expectRulesEqual(rulesBefore, DEFAULT_RULES);

      await equbPool.connect(owner).setGovernor(governor.address);

      const UPDATED_RULES = {
        equbType: 4,       // Special
        frequency: 2,      // BiWeekly
        payoutMethod: 2,   // Bid
        gracePeriodSeconds: 86400,       // 1 day
        penaltySeverity: 50,
        roundDurationSeconds: 1209600,   // 14 days
        lateFeePercent: 3,
      };

      await equbPool.connect(governor).updateRules(poolId, rulesStruct(UPDATED_RULES));

      const rulesAfter = await equbPool.getRules(poolId);
      expectRulesEqual(rulesAfter, UPDATED_RULES);
    });
  });
});
